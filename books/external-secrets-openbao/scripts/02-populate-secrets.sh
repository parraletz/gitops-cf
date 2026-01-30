#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Poblando Secrets en OpenBao ===${NC}"

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

# Obtener root token
ROOT_TOKEN=$(kubectl get secret openbao-root-token -n openbao-system -o jsonpath='{.data.root-token}' | base64 -d)
export BAO_TOKEN=$ROOT_TOKEN

echo -e "${YELLOW}Creando secrets de ejemplo...${NC}"

# Secret 1: Database credentials
echo -e "${YELLOW}Creando myapp/database...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "host": "postgres.example.com",
            "port": "5432",
            "name": "myapp_production",
            "username": "myapp_user",
            "password": "super-secure-password-123",
            "url": "postgresql://myapp_user:super-secure-password-123@postgres.example.com:5432/myapp_production"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/database

echo -e "${GREEN}✓ Database credentials creadas${NC}"

# Secret 2: Application configuration
echo -e "${YELLOW}Creando myapp/config...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "api_key": "ak_1234567890abcdef",
            "jwt_secret": "jwt-super-secret-key-for-tokens",
            "encryption_key": "aes-256-encryption-key-32-chars!",
            "debug_mode": "false",
            "log_level": "info",
            "max_connections": "100"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/config

echo -e "${GREEN}✓ Application config creada${NC}"

# Secret 3: Environment specific settings
echo -e "${YELLOW}Creando myapp/environment...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "ENV_STAGE": "production",
            "ENV_REGION": "us-west-2",
            "ENV_CDN_URL": "https://cdn.myapp.com",
            "ENV_REDIS_URL": "redis://redis.example.com:6379",
            "ENV_SMTP_HOST": "smtp.example.com",
            "ENV_SMTP_PORT": "587"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/environment

echo -e "${GREEN}✓ Environment config creada${NC}"

# Secret 4: TLS certificates (simulados)
echo -e "${YELLOW}Creando myapp/tls...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "certificate": "-----BEGIN CERTIFICATE-----\nMIICujCCAaICCQC3H8w0t4w8WjANBgkqhkiG9w0BAQsFADAfMR0wGwYDVQQDDBRt\neWFwcC5leGFtcGxlLmNvbS5jb20wHhcNMjMwMTAxMDAwMDAwWhcNMjQwMTAxMDAw\nMDAwWjAfMR0wGwYDVQQDDBRteWFwcC5leGFtcGxlLmNvbS5jb20wggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7... (truncated for demo)\n-----END CERTIFICATE-----",
            "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7... (truncated for demo)\n-----END PRIVATE KEY-----",
            "ca_certificate": "-----BEGIN CERTIFICATE-----\nMIICzTCCAbWgAwIBAgIJAK... (truncated for demo)\n-----END CERTIFICATE-----"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/tls

echo -e "${GREEN}✓ TLS certificates creadas${NC}"

# Secret 5: Third-party integrations
echo -e "${YELLOW}Creando myapp/integrations...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "stripe_secret_key": "sk_live_51234567890abcdef",
            "stripe_webhook_secret": "whsec_1234567890abcdef",
            "github_token": "ghp_1234567890abcdef",
            "slack_webhook": "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX",
            "sendgrid_api_key": "SG.1234567890abcdef",
            "aws_access_key": "AKIA1234567890ABCDEF",
            "aws_secret_key": "1234567890abcdef1234567890abcdef12345678"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/integrations

echo -e "${GREEN}✓ Integrations config creada${NC}"

# Secret 6: Monitoring and observability
echo -e "${YELLOW}Creando myapp/monitoring...${NC}"
curl -s -X POST \
    -H "X-Vault-Token: $BAO_TOKEN" \
    -d '{
        "data": {
            "datadog_api_key": "dd_1234567890abcdef",
            "newrelic_license_key": "nr_1234567890abcdef",
            "prometheus_bearer_token": "prom_1234567890abcdef",
            "grafana_api_key": "eyJrIjoiVGVzdCIsIm4iOiJUZXN0IiwiaWQiOjF9"
        }
    }' \
    ${BAO_ADDR}/v1/secret/data/myapp/monitoring

echo -e "${GREEN}✓ Monitoring config creada${NC}"

echo
echo -e "${GREEN}=== Secrets poblados exitosamente ===${NC}"
echo
echo -e "${YELLOW}Secrets creados en OpenBao:${NC}"
echo "• myapp/database - Credenciales de base de datos"
echo "• myapp/config - Configuración de aplicación"
echo "• myapp/environment - Variables de entorno"
echo "• myapp/tls - Certificados TLS"
echo "• myapp/integrations - Integraciones de terceros"
echo "• myapp/monitoring - Herramientas de monitoreo"
echo
echo -e "${YELLOW}Verificar en OpenBao UI:${NC}"
echo "• URL: http://localhost:30820"
echo "• Token: $ROOT_TOKEN"
echo "• Navegar a: secret/myapp/"