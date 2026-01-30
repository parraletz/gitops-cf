# Demo de RBAC en Kubernetes

Este conjunto de manifiestos y scripts está diseñado para demostrar cómo funciona RBAC (Role-Based Access Control) en Kubernetes de manera práctica.

## Estructura de la Demo

### 1. ServiceAccounts (`01-serviceaccount.yaml`)
- `pod-reader-sa`: ServiceAccount con permisos para leer pods
- `restricted-sa`: ServiceAccount sin permisos para mostrar la diferencia

### 2. Roles y ClusterRoles (`02-roles.yaml`)
- `pod-reader`: Role que permite `get` y `list` en pods
- `pod-admin`: Role con más permisos (create, delete, update, etc.)
- `cluster-pod-reader`: ClusterRole para mostrar diferencias con Role

### 3. RoleBindings (`03-rolebindings.yaml`)
- Conecta los ServiceAccounts con los Roles correspondientes
- Ejemplos de RoleBinding y ClusterRoleBinding

### 4. Pods de Prueba (`04-test-pods.yaml`)
- `curl-with-permissions`: Pod que puede acceder a la API de Kubernetes
- `curl-without-permissions`: Pod que NO puede acceder a la API
- `httpbin-demo`: Pod adicional para tener contenido que listar

## Ejecución de la Demo

### Opción 1: Script Automático
```bash
chmod +x 05-demo-commands.sh
./05-demo-commands.sh
```

### Opción 2: Paso a Paso

1. **Aplicar manifiestos:**
```bash
kubectl apply -f 01-serviceaccount.yaml
kubectl apply -f 02-roles.yaml
kubectl apply -f 03-rolebindings.yaml
kubectl apply -f 04-test-pods.yaml
```

2. **Esperar a que los pods estén listos:**
```bash
kubectl wait --for=condition=Ready pod/curl-with-permissions --timeout=60s
kubectl wait --for=condition=Ready pod/curl-without-permissions --timeout=60s
```

3. **Probar acceso CON permisos:**
```bash
kubectl exec curl-with-permissions -- /bin/sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods
'
```

4. **Probar acceso SIN permisos:**
```bash
kubectl exec curl-without-permissions -- /bin/sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" \
     -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces/default/pods
'
```

## Conceptos Demostrados

### 1. ServiceAccounts
- Identidades para pods y procesos en Kubernetes
- Automáticamente montan tokens en `/var/run/secrets/kubernetes.io/serviceaccount/`

### 2. Roles vs ClusterRoles
- **Role**: Permisos limitados a un namespace específico
- **ClusterRole**: Permisos a nivel de cluster (todos los namespaces)

### 3. RoleBindings vs ClusterRoleBindings
- **RoleBinding**: Conecta subjects con Roles en un namespace
- **ClusterRoleBinding**: Conecta subjects con ClusterRoles globalmente

### 4. Verificación de Permisos
```bash
# Verificar si un ServiceAccount puede realizar una acción
kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader-sa

# Ver todos los permisos de un ServiceAccount
kubectl auth can-i --list --as=system:serviceaccount:default:pod-reader-sa
```

## Comandos Útiles para la Charla

### Debugging RBAC
```bash
# Ver recursos RBAC disponibles
kubectl api-resources | grep rbac

# Describir un RoleBinding
kubectl describe rolebinding read-pods-binding

# Debug con verbosidad
kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader-sa -v=6
```

### Limpieza
```bash
kubectl delete -f 04-test-pods.yaml
kubectl delete -f 03-rolebindings.yaml
kubectl delete -f 02-roles.yaml
kubectl delete -f 01-serviceaccount.yaml
```

## Tips para la Charla

1. **Mostrar el token**: Explica cómo Kubernetes monta automáticamente el token del ServiceAccount
2. **Demostrar la diferencia**: Ejecuta los mismos comandos curl desde ambos pods
3. **Usar kubectl auth can-i**: Herramienta muy útil para verificar permisos
4. **Explicar el principio de menor privilegio**: Por qué es importante dar solo los permisos necesarios
5. **Mostrar logs de audit**: Si tienes habilitado audit logging, muestra las entradas de acceso denegado

## Extensiones Posibles

- Agregar ejemplos con Groups
- Mostrar agregación de ClusterRoles
- Demostrar RBAC con webhooks de admisión
- Ejemplos con diferentes verbos (watch, patch, etc.)