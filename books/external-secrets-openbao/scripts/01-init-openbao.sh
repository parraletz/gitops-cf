#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Inicializando OpenBao ===${NC}"

# Verificar que OpenBao esté corriendo
if ! kubectl get pod -n openbao-system -l app.kubernetes.io/name=openbao | grep -q Running; then
    echo -e "${RED}Error: OpenBao no está corriendo${NC}"
    exit 1
fi

# Port forward para acceder a OpenBao
echo -e "${YELLOW}Creando port-forward a OpenBao...${NC}"
kubectl port-forward -n openbao-system svc/openbao 8200:8200 &
PF_PID=$!

# Esperar que el port-forward esté activo
sleep 5

# Función de limpieza
cleanup() {
    if [ ! -z "$PF_PID" ]; then
        kill $PF_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

export BAO_ADDR=http://localhost:8200

echo -e "${YELLOW}Verificando estado de OpenBao...${NC}"
if ! curl -s ${BAO_ADDR}/v1/sys/health > /dev/null; then
    echo -e "${RED}Error: No se puede conectar a OpenBao${NC}"
    exit 1
fi

# Verificar si OpenBao ya está inicializado
SEAL_STATUS=$(curl -s ${BAO_ADDR}/v1/sys/seal-status | jq -r '.initialized')
if [ "$SEAL_STATUS" = "true" ]; then
    echo -e "${GREEN}OpenBao ya está inicializado${NC}"
    
    # Verificar si tenemos el root token
    if kubectl get secret openbao-root-token -n openbao-system &>/dev/null; then
        ROOT_TOKEN=$(kubectl get secret openbao-root-token -n openbao-system -o jsonpath='{.data.root-token}' | base64 -d)
        echo -e "${GREEN}Token root encontrado en Kubernetes secret${NC}"
    else
        echo -e "${RED}OpenBao inicializado pero no se encuentra el token root${NC}"
        echo "Por favor, proporciona el token root manualmente"
        exit 1
    fi
else
    echo -e "${YELLOW}Inicializando OpenBao...${NC}"
    
    # Inicializar OpenBao
    INIT_RESPONSE=$(curl -s -X POST \
        -d '{"secret_shares": 1, "secret_threshold": 1}' \
        ${BAO_ADDR}/v1/sys/init)
    
    # Extraer keys y root token
    UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r '.keys[0]')
    ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r '.root_token')
    
    echo -e "${GREEN}OpenBao inicializado exitosamente${NC}"
    
    # Guardar en secrets de Kubernetes
    kubectl create secret generic openbao-root-token \
        -n openbao-system \
        --from-literal=root-token="$ROOT_TOKEN" \
        --from-literal=unseal-key="$UNSEAL_KEY"
    
    echo -e "${YELLOW}Desbloqueando OpenBao...${NC}"
    curl -s -X POST \
        -d "{\"key\": \"$UNSEAL_KEY\"}" \
        ${BAO_ADDR}/v1/sys/unseal
    
    echo -e "${GREEN}OpenBao desbloqueado${NC}"
fi

# Configurar OpenBao
export BAO_TOKEN=$ROOT_TOKEN

echo -e "${YELLOW}Configurando OpenBao...${NC}"

# Habilitar secrets engine v2
echo -e "${YELLOW}Habilitando KV secrets engine v2...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{"type": "kv", "options": {"version": "2"}}' \
    ${BAO_ADDR}/v1/sys/mounts/secret || true

# Configurar Kubernetes auth method
echo -e "${YELLOW}Habilitando Kubernetes auth method...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{"type": "kubernetes"}' \
    ${BAO_ADDR}/v1/sys/auth/kubernetes || true

# Obtener información del cluster
K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
K8S_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)

# Configurar Kubernetes auth
echo -e "${YELLOW}Configurando Kubernetes auth...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d "{
        \"kubernetes_host\": \"$K8S_HOST\",
        \"kubernetes_ca_cert\": \"$K8S_CA_CERT\"
    }" \
    ${BAO_ADDR}/v1/auth/kubernetes/config

# Crear políticas
echo -e "${YELLOW}Creando políticas...${NC}"

# Política para External Secrets Operator
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "policy": "path \"secret/data/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/metadata/*\" {\n  capabilities = [\"list\"]\n}"
    }' \
    ${BAO_ADDR}/v1/sys/policies/acl/external-secrets-policy

# Política para la demo app
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "policy": "path \"secret/data/myapp/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/metadata/myapp/*\" {\n  capabilities = [\"list\"]\n}"
    }' \
    ${BAO_ADDR}/v1/sys/policies/acl/demo-app-policy

# Crear roles de Kubernetes auth
echo -e "${YELLOW}Creando roles de Kubernetes...${NC}"

# Role para External Secrets Operator
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "bound_service_account_names": ["external-secrets"],
        "bound_service_account_namespaces": ["external-secrets-system"],
        "policies": ["external-secrets-policy"],
        "ttl": "1h"
    }' \
    ${BAO_ADDR}/v1/auth/kubernetes/role/external-secrets-role

# Role para demo app
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "bound_service_account_names": ["demo-app"],
        "bound_service_account_namespaces": ["secrets-demo"],
        "policies": ["demo-app-policy"],
        "ttl": "1h"
    }' \
    ${BAO_ADDR}/v1/auth/kubernetes/role/demo-role

# Actualizar tokens en los secrets de Kubernetes
echo -e "${YELLOW}Actualizando tokens en Kubernetes secrets...${NC}"
kubectl patch secret openbao-token -n secrets-demo -p "{\"data\":{\"token\":\"$(echo -n $ROOT_TOKEN | base64)\"}}"
kubectl patch secret openbao-token -n external-secrets-system -p "{\"data\":{\"token\":\"$(echo -n $ROOT_TOKEN | base64)\"}}"

echo -e "${GREEN}=== OpenBao inicialización completada ===${NC}"
echo
echo -e "${YELLOW}Información importante:${NC}"
echo "• Root Token guardado en: openbao-root-token secret (namespace: openbao-system)"
echo "• OpenBao UI accesible en: http://localhost:30820"
echo "• Usar el root token para acceder a la UI"
echo
echo -e "${YELLOW}Políticas creadas:${NC}"
echo "• external-secrets-policy: acceso de lectura a secret/*"
echo "• demo-app-policy: acceso de lectura a secret/myapp/*"
echo
echo -e "${YELLOW}Roles de Kubernetes creados:${NC}"
echo "• external-secrets-role: para external-secrets service account"
echo "• demo-role: para demo-app service account"