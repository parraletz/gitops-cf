# OpenBao + External Secrets Operator Demo

Esta demo completa muestra la integración entre OpenBao (un fork open-source de HashiCorp Vault) y External Secrets Operator para la gestión segura de secrets en Kubernetes.

## 🎯 Objetivos de la Demo

- Desplegar OpenBao en Kubernetes
- Configurar External Secrets Operator
- Demostrar diferentes patrones de sincronización de secrets
- Mostrar rotación automática de secrets
- Implementar autenticación segura con Kubernetes Service Accounts

## 📁 Estructura del Proyecto

```
.
├── manifests/
│   ├── rbac/                    # Namespaces, ServiceAccounts, RBAC
│   ├── openbao/                 # Deployment de OpenBao
│   ├── external-secrets/        # Deployment de External Secrets Operator
│   ├── secret-stores/           # SecretStores y ClusterSecretStores
│   ├── external-secrets-examples/ # Ejemplos de ExternalSecret
│   └── demo-app/                # Aplicación demo
├── scripts/
│   ├── 00-setup-demo.sh         # Setup completo automatizado
│   ├── 01-init-openbao.sh       # Inicialización de OpenBao
│   ├── 02-populate-secrets.sh   # Poblar secrets de ejemplo
│   └── 99-cleanup-demo.sh       # Limpieza completa
└── README.md                    # Esta documentación
```

## 🚀 Inicio Rápido

### Prerequisitos

- Kubernetes cluster (minikube, kind, k3s, etc.)
- `kubectl` configurado
- `jq` instalado
- `curl` instalado
- `helm` (opcional, recomendado)

### Instalación Automática

```bash
# Hacer ejecutables los scripts
chmod +x scripts/*.sh

# Ejecutar setup completo
./scripts/00-setup-demo.sh
```

### Instalación Manual

1. **Aplicar manifiestos básicos:**
```bash
kubectl apply -f manifests/rbac/
kubectl apply -f manifests/openbao/
```

2. **Esperar que OpenBao esté listo:**
```bash
kubectl wait --for=condition=available deployment/openbao -n openbao-system --timeout=300s
```

3. **Inicializar OpenBao:**
```bash
./scripts/01-init-openbao.sh
```

4. **Instalar External Secrets Operator:**
```bash
# Con Helm (recomendado)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace --set installCRDs=true

# O manualmente
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
kubectl apply -f manifests/external-secrets/
```

5. **Configurar Secret Stores y poblar datos:**
```bash
kubectl apply -f manifests/secret-stores/
./scripts/02-populate-secrets.sh
```

6. **Crear External Secrets y aplicación demo:**
```bash
kubectl apply -f manifests/external-secrets-examples/
kubectl apply -f manifests/demo-app/
```

## 🔧 Componentes de la Demo

### OpenBao
- Configuración no-HA para demo (storage in-memory)
- UI habilitada en NodePort 30820
- Configurado con Kubernetes authentication method
- Políticas de seguridad por service account

### External Secrets Operator
- Controller y webhook deployments
- Support para múltiples tipos de secrets
- Refresh automático configurable
- Templates para transformación de datos

### Secret Stores
- **SecretStore**: Para namespace específico
- **ClusterSecretStore**: Para uso cross-namespace
- Dos métodos de autenticación:
  - Token-based (simplificado para demo)
  - Kubernetes auth (recomendado para producción)

### Ejemplos de External Secrets

1. **Basic Secret** (`01-basic-secret.yaml`)
   - Sincronización simple de credenciales de BD
   - Mapeo individual de propiedades

2. **DataFrom Secret** (`02-dataFrom-secret.yaml`)
   - Sincronización completa de secrets
   - Reglas de rewrite para transformación de keys

3. **Template Secret** (`03-template-secret.yaml`)
   - Uso de templates para crear connection strings
   - Generación de archivos de configuración complejos

4. **TLS Secret** (`04-tls-secret.yaml`)
   - Creación de secrets tipo `kubernetes.io/tls`
   - Certificados y llaves privadas

5. **Push Secret** (`05-push-secret.yaml`)
   - Sincronización inversa: K8s → OpenBao
   - Útil para backup de secrets locales

### Demo App
- Aplicación busybox que demuestra el uso de secrets
- Monta secrets como volúmenes y variables de entorno
- Monitorea cambios en secrets para mostrar rotación
- Logs detallados para troubleshooting

## 🔍 Casos de Uso Demostrados

### 1. Gestión Centralizada de Secrets
```bash
# Ver secrets sincronizados
kubectl get externalsecrets -n secrets-demo
kubectl get secrets -n secrets-demo
```

### 2. Rotación Automática
```bash
# Cambiar un secret en OpenBao
kubectl port-forward -n openbao-system svc/openbao 8200:8200 &
curl -X POST -H "X-Vault-Token: $ROOT_TOKEN" \
  -d '{"data": {"password": "new-rotated-password"}}' \
  http://localhost:8200/v1/secret/data/myapp/database

# Observar la rotación en la app
kubectl logs -n secrets-demo -l app.kubernetes.io/name=demo-app -f
```

### 3. Autenticación con Service Accounts
```bash
# Ver configuración de Kubernetes auth
kubectl port-forward -n openbao-system svc/openbao 8200:8200 &
curl -H "X-Vault-Token: $ROOT_TOKEN" \
  http://localhost:8200/v1/auth/kubernetes/role/demo-role
```

### 4. Templates y Transformaciones
```bash
# Ver secret generado con template
kubectl get secret app-connection-secret -n secrets-demo -o yaml
kubectl get secret app-connection-secret -n secrets-demo -o jsonpath='{.data.connection_string}' | base64 -d
```

## 📊 Monitoreo y Troubleshooting

### Logs Importantes
```bash
# OpenBao logs
kubectl logs -n openbao-system -l app.kubernetes.io/name=openbao -f

# External Secrets Controller logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets -f

# Demo App logs
kubectl logs -n secrets-demo -l app.kubernetes.io/name=demo-app -f
```

### Health Checks
```bash
# Estado de OpenBao
kubectl get pods -n openbao-system
curl http://localhost:30820/v1/sys/health

# Estado de External Secrets
kubectl get externalsecrets -n secrets-demo
kubectl describe externalsecret app-database-credentials -n secrets-demo
```

### Acceso a UIs
- **OpenBao UI**: http://localhost:30820
- **Demo App**: http://localhost:30808 (logs en consola)

## 🔒 Consideraciones de Seguridad

### Para Demo
- Se usa storage in-memory (datos se pierden al reiniciar)
- Se usa root token para simplicidad
- TLS deshabilitado
- Políticas permisivas

### Para Producción
- Usar storage persistente (Consul, etcd, cloud storage)
- Implementar auto-unseal con cloud KMS
- Habilitar TLS end-to-end
- Usar tokens con TTL limitado
- Implementar políticas granulares
- Configurar audit logging
- Usar Kubernetes auth method exclusivamente

## 🧹 Limpieza

```bash
# Limpieza completa
./scripts/99-cleanup-demo.sh

# O manual
kubectl delete -f manifests/demo-app/
kubectl delete -f manifests/external-secrets-examples/
kubectl delete -f manifests/secret-stores/
helm uninstall external-secrets -n external-secrets-system
kubectl delete -f manifests/openbao/
kubectl delete -f manifests/rbac/
```

## 📚 Recursos Adicionales

- [OpenBao Documentation](https://openbao.org/docs/)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Secrets Management Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)

## 🤝 Contribución

Este proyecto es para fines educativos y de demostración. Para mejoras o sugerencias, por favor crea un issue o pull request.

## 📄 Licencia

Este proyecto está bajo licencia MIT. Ver archivo LICENSE para más detalles.