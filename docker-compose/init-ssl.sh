#!/bin/bash
set -e

# Usage: ./init-ssl.sh <domain> <email>
# Example: ./init-ssl.sh testnet.kalyscan.io admin@kalyscan.io

DOMAIN=${1:?Usage: ./init-ssl.sh <domain> <email>}
EMAIL=${2:?Usage: ./init-ssl.sh <domain> <email>}
COMPOSE_FILE="docker-compose-prod.yml"

BACK_PROXY_PASS="${BACK_PROXY_PASS:-http://backend:4000}"
FRONT_PROXY_PASS="${FRONT_PROXY_PASS:-http://frontend:3000}"

echo "==> Generating nginx config for ${DOMAIN}"
export DOMAIN BACK_PROXY_PASS FRONT_PROXY_PASS
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
envsubst '${DOMAIN} ${BACK_PROXY_PASS} ${FRONT_PROXY_PASS}' < "${SCRIPT_DIR}/proxy/ssl.conf.template" > "${SCRIPT_DIR}/proxy/ssl.conf"
echo "    Written to proxy/ssl.conf"

echo ""
echo "==> Obtaining initial SSL certificate for ${DOMAIN}"
echo "    Make sure port 80 is free and DNS points to this server."
echo ""

# Stop any running containers that might hold port 80
docker compose -f ${COMPOSE_FILE} down 2>/dev/null || true

# Create the named volumes so they exist for the standalone certbot
docker volume create docker-compose_certbot-etc 2>/dev/null || true
docker volume create docker-compose_certbot-var 2>/dev/null || true

# Get the initial certificate using standalone mode (certbot runs its own webserver)
docker run --rm \
  -p 80:80 \
  -v "docker-compose_certbot-etc:/etc/letsencrypt" \
  -v "docker-compose_certbot-var:/var/lib/letsencrypt" \
  certbot/certbot certonly \
    --standalone \
    --preferred-challenges http \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --keep-until-expiring \
    -d "${DOMAIN}"

if [ $? -eq 0 ]; then
  echo ""
  echo "==> Certificate obtained successfully!"
  echo "==> Starting the full stack..."
  docker compose -f ${COMPOSE_FILE} up -d
  echo ""
  echo "==> Done! Blockscout should be available at https://${DOMAIN}"
  echo "    Certbot will auto-renew the certificate."
  echo "    Nginx reloads certs every 6 hours."
else
  echo ""
  echo "==> ERROR: Failed to obtain certificate."
  echo "    Check that:"
  echo "    1. DNS for ${DOMAIN} points to this server's IP"
  echo "    2. Port 80 is not blocked by a firewall"
  echo "    3. No other service is using port 80"
  exit 1
fi
