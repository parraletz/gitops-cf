#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Limpiando Demo de OpenBao + External Secrets ===${NC}"

# Función para preguntar confirmación
confirm() {
    read -p "¿Estás seguro de que quieres eliminar toda la demo? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
    fi
}

confirm

echo -e "${YELLOW}Eliminando aplicación demo...${NC}"
kubectl delete -f manifests/demo-app/ --ignore-not-found=true

echo -e "${YELLOW}Eliminando External Secrets examples...${NC}"
kubectl delete -f manifests/external-secrets-examples/ --ignore-not-found=true

echo -e "${YELLOW}Eliminando Secret Stores...${NC}"
kubectl delete -f manifests/secret-stores/ --ignore-not-found=true

echo -e "${YELLOW}Eliminando External Secrets Operator...${NC}"
if command -v helm &> /dev/null; then
    helm uninstall external-secrets -n external-secrets-system --ignore-not-found || true
else
    kubectl delete -f manifests/external-secrets/ --ignore-not-found=true
fi

echo -e "${YELLOW}Eliminando OpenBao...${NC}"
kubectl delete -f manifests/openbao/ --ignore-not-found=true

echo -e "${YELLOW}Eliminando RBAC y namespaces...${NC}"
kubectl delete -f manifests/rbac/ --ignore-not-found=true

echo -e "${YELLOW}Eliminando CRDs de External Secrets (opcional)...${NC}"
read -p "¿Eliminar también los CRDs de External Secrets? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete crd externalsecrets.external-secrets.io --ignore-not-found=true
    kubectl delete crd secretstores.external-secrets.io --ignore-not-found=true
    kubectl delete crd clustersecretstores.external-secrets.io --ignore-not-found=true
    kubectl delete crd pushsecrets.external-secrets.io --ignore-not-found=true
    kubectl delete crd acraccesstokens.generators.external-secrets.io --ignore-not-found=true
    kubectl delete crd ecrauthorizationtokens.generators.external-secrets.io --ignore-not-found=true
    kubectl delete crd fakes.generators.external-secrets.io --ignore-not-found=true
    kubectl delete crd gcraccesstokens.generators.external-secrets.io --ignore-not-found=true
    kubectl delete crd passwords.generators.external-secrets.io --ignore-not-found=true
    kubectl delete crd vaultdynamicsecrets.generators.external-secrets.io --ignore-not-found=true
    echo -e "${GREEN}✓ CRDs eliminados${NC}"
fi

# Limpiar port-forwards si están corriendo
echo -e "${YELLOW}Limpiando port-forwards...${NC}"
pkill -f "kubectl port-forward.*openbao" || true
pkill -f "kubectl port-forward.*external-secrets" || true

echo
echo -e "${GREEN}=== Limpieza completada ===${NC}"
echo
echo -e "${YELLOW}Recursos eliminados:${NC}"
echo "• Namespaces: secrets-demo, openbao-system, external-secrets-system"
echo "• Todos los manifiestos de la demo"
echo "• Service accounts y RBAC"
echo
echo -e "${YELLOW}Verificar limpieza:${NC}"
echo "kubectl get ns | grep -E '(secrets-demo|openbao-system|external-secrets-system)'"
echo "kubectl get externalsecrets --all-namespaces"