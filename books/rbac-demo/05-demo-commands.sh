#!/bin/bash

# Script de comandos para la demostración de RBAC en Kubernetes
echo "=== Demostración de RBAC en Kubernetes ==="
echo

# 1. Aplicar todos los manifiestos
echo "1. Aplicando manifiestos de RBAC..."
kubectl apply -f 01-serviceaccount.yaml
kubectl apply -f 02-roles.yaml
kubectl apply -f 03-rolebindings.yaml
kubectl apply -f 04-test-pods.yaml

echo "Esperando a que los pods estén listos..."
kubectl wait --for=condition=Ready pod/curl-with-permissions --timeout=60s
kubectl wait --for=condition=Ready pod/curl-without-permissions --timeout=60s
kubectl wait --for=condition=Ready pod/httpbin-demo --timeout=60s

echo
echo "2. Verificando recursos creados:"
echo "--- ServiceAccounts ---"
kubectl get serviceaccounts -l app=rbac-demo

echo
echo "--- Roles ---"
kubectl get roles -l app=rbac-demo

echo
echo "--- RoleBindings ---"
kubectl get rolebindings -l app=rbac-demo

echo
echo "--- Pods ---"
kubectl get pods -l app=rbac-demo

echo
echo "=== DEMO: Pod CON permisos ==="
echo "Ejecutando desde el pod 'curl-with-permissions' que tiene permisos para listar pods:"

# Comando para mostrar en la charla
echo "kubectl exec curl-with-permissions -- /bin/sh -c 'TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) && curl -H \"Authorization: Bearer \$TOKEN\" -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods'"

kubectl exec curl-with-permissions -- /bin/sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
echo "Token obtenido, realizando petición a la API..."
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods | jq -r ".items[].metadata.name" 2>/dev/null || echo "Pods encontrados (sin jq):"
'

echo
echo "=== DEMO: Pod SIN permisos ==="
echo "Ejecutando desde el pod 'curl-without-permissions' que NO tiene permisos:"

# Comando para mostrar en la charla
echo "kubectl exec curl-without-permissions -- /bin/sh -c 'TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) && curl -H \"Authorization: Bearer \$TOKEN\" -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods'"

kubectl exec curl-without-permissions -- /bin/sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
echo "Token obtenido, realizando petición a la API..."
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods 2>&1 | head -20
'

echo
echo "=== DEMO: Verificando permisos con kubectl auth can-i ==="
echo "Verificando qué puede hacer cada ServiceAccount:"

echo
echo "pod-reader-sa puede listar pods:"
kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader-sa

echo "pod-reader-sa puede crear pods:"
kubectl auth can-i create pods --as=system:serviceaccount:default:pod-reader-sa

echo "restricted-sa puede listar pods:"
kubectl auth can-i list pods --as=system:serviceaccount:default:restricted-sa

echo
echo "=== DEMO: Describiendo RoleBinding ==="
kubectl describe rolebinding read-pods-binding

echo
echo "=== DEMO: Ver diferencias entre Role y ClusterRole ==="
echo "Role (namespace-scoped):"
kubectl describe role pod-reader

echo
echo "ClusterRole (cluster-scoped):"
kubectl describe clusterrole cluster-pod-reader

echo
echo "=== Comandos adicionales para la charla ==="
echo
echo "# Ver todos los recursos RBAC:"
echo "kubectl api-resources | grep rbac"
echo
echo "# Ver permisos efectivos de un usuario/SA:"
echo "kubectl auth can-i --list --as=system:serviceaccount:default:pod-reader-sa"
echo
echo "# Debuggear problemas de permisos:"
echo "kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader-sa -v=6"
echo
echo "# Limpiar recursos de la demo:"
echo "kubectl delete -f 04-test-pods.yaml"
echo "kubectl delete -f 03-rolebindings.yaml"
echo "kubectl delete -f 02-roles.yaml"
echo "kubectl delete -f 01-serviceaccount.yaml"