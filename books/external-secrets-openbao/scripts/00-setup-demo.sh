#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OpenBao + External Secrets Demo Setup ===${NC}"
echo

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

# Verificar helm (opcional)
if command -v helm &> /dev/null; then
    HELM_AVAILABLE=true
    echo -e "${GREEN}✓ Helm disponible${NC}"
else
    HELM_AVAILABLE=false
    echo -e "${YELLOW}⚠ Helm no disponible - usando manifiestos manuales${NC}"
fi

# Función para esperar que un deployment esté listo
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}Esperando que ${deployment} en namespace ${namespace} esté listo...${NC}"
    kubectl wait --for=condition=available deployment/${deployment} -n ${namespace} --timeout=${timeout}s
    echo -e "${GREEN}✓ ${deployment} está listo${NC}"
}

# Función para esperar que un pod esté running
wait_for_pod() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}Esperando pod con label ${label} en namespace ${namespace}...${NC}"
    kubectl wait --for=condition=ready pod -l ${label} -n ${namespace} --timeout=${timeout}s
    echo -e "${GREEN}✓ Pod está listo${NC}"
}

echo -e "${BLUE}Paso 1: Aplicando namespaces y RBAC...${NC}"
kubectl apply -f manifests/rbac/

echo -e "${BLUE}Paso 2: Desplegando OpenBao...${NC}"
kubectl apply -f manifests/openbao/

echo -e "${BLUE}Paso 3: Esperando que OpenBao esté listo...${NC}"
wait_for_deployment "openbao-system" "openbao"

echo -e "${BLUE}Paso 4: Inicializando OpenBao...${NC}"
./scripts/01-init-openbao.sh

echo -e "${BLUE}Paso 5: Configurando External Secrets Operator...${NC}"
if [ "$HELM_AVAILABLE" = true ]; then
    echo -e "${YELLOW}Instalando External Secrets Operator con Helm...${NC}"
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    helm upgrade --install external-secrets external-secrets/external-secrets \
        -n external-secrets-system \
        --create-namespace \
        --set installCRDs=true \
        --wait
else
    echo -e "${YELLOW}Aplicando manifiestos de External Secrets Operator...${NC}"
    echo -e "${RED}NOTA: Necesitas instalar los CRDs manualmente:${NC}"
    echo "kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml"
    echo
    kubectl apply -f manifests/external-secrets/
fi

echo -e "${BLUE}Paso 6: Configurando Secret Stores...${NC}"
kubectl apply -f manifests/secret-stores/

echo -e "${BLUE}Paso 7: Populando secrets en OpenBao...${NC}"
./scripts/02-populate-secrets.sh

echo -e "${BLUE}Paso 8: Creando External Secrets...${NC}"
kubectl apply -f manifests/external-secrets-examples/

echo -e "${BLUE}Paso 9: Desplegando aplicación demo...${NC}"
kubectl apply -f manifests/demo-app/

echo -e "${BLUE}Paso 10: Esperando que la demo app esté lista...${NC}"
wait_for_deployment "secrets-demo" "demo-app"

echo
echo -e "${GREEN}=== Demo Setup Completado ===${NC}"
echo
echo -e "${YELLOW}Acceso a servicios:${NC}"
echo "• OpenBao UI: http://localhost:30820"
echo "• Demo App: http://localhost:30808"
echo
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "• Ver logs de OpenBao: kubectl logs -n openbao-system -l app.kubernetes.io/name=openbao -f"
echo "• Ver logs de External Secrets: kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets -f"
echo "• Ver logs de Demo App: kubectl logs -n secrets-demo -l app.kubernetes.io/name=demo-app -f"
echo "• Ver External Secrets: kubectl get externalsecrets -n secrets-demo"
echo "• Ver secrets sincronizados: kubectl get secrets -n secrets-demo"
echo
echo -e "${BLUE}Para limpiar la demo, ejecuta:${NC}"
echo "./scripts/99-cleanup-demo.sh"