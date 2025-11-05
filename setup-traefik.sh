#!/bin/bash

# OpenProject Traefik Configuration Script

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DOMAIN="openproject.ai-servicers.com"
CONTAINER_NAME="openproject-web"
NETWORK="traefik-proxy"

echo -e "${YELLOW}Configuring Traefik for OpenProject...${NC}"

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK"; then
    echo "Creating Docker network: $NETWORK"
    docker network create $NETWORK
fi

# Create systemd drop-in directory
sudo mkdir -p /etc/systemd/system/openproject-web.service.d

# Create Docker labels configuration for systemd service
sudo tee /etc/systemd/system/openproject-web.service.d/docker-labels.conf > /dev/null <<EOF
[Service]
# Add Docker container with Traefik labels
ExecStartPost=/bin/bash -c 'sleep 5 && docker run -d \
  --name $CONTAINER_NAME \
  --network $NETWORK \
  --network-alias openproject \
  -p 127.0.0.1:6000:6000 \
  -v /var/db/openproject:/var/db/openproject \
  -v /etc/openproject:/etc/openproject \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=$NETWORK" \
  --label "traefik.http.routers.openproject.rule=Host(\\\`$DOMAIN\\\`)" \
  --label "traefik.http.routers.openproject.entrypoints=websecure" \
  --label "traefik.http.routers.openproject.tls=true" \
  --label "traefik.http.routers.openproject.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.openproject.loadbalancer.server.port=6000" \
  --label "traefik.http.services.openproject.loadbalancer.server.scheme=http" \
  --label "traefik.http.routers.openproject.middlewares=openproject-headers" \
  --label "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Proto=https" \
  --label "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Host=$DOMAIN" \
  --restart unless-stopped \
  openproject/openproject:14'

ExecStop=/usr/bin/docker stop $CONTAINER_NAME || true
ExecStopPost=/usr/bin/docker rm $CONTAINER_NAME || true
EOF

# Alternative: Create a Docker Compose file for better management
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  openproject:
    image: openproject/openproject:14
    container_name: openproject
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://openproject:OpenProject#Secure2025!@host.docker.internal:5432/openproject_production
      - REDIS_URL=redis://:rvSqetVQklW4AjSpxk4vX5vvc@host.docker.internal:6379/2
      - OPENPROJECT_HOST=$DOMAIN
      - OPENPROJECT_PROTOCOL=https
      - OPENPROJECT_HSTS=true
      - RAILS_ENV=production
      - OPENPROJECT_CACHE_STORE=redis
      - OPENPROJECT_SESSION_STORE=redis
      - OPENPROJECT_WEB_WORKERS=4
      - OPENPROJECT_BACKGROUND_JOBS_WORKERS=2
    volumes:
      - /var/db/openproject:/var/db/openproject
      - openproject-assets:/opt/openproject/public/assets
      - openproject-logs:/var/log/openproject
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-proxy"
      - "traefik.http.routers.openproject.rule=Host(\\\`$DOMAIN\\\`)"
      - "traefik.http.routers.openproject.entrypoints=websecure"
      - "traefik.http.routers.openproject.tls=true"
      - "traefik.http.routers.openproject.tls.certresolver=letsencrypt"
      - "traefik.http.services.openproject.loadbalancer.server.port=8080"
      - "traefik.http.routers.openproject.middlewares=openproject-headers"
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Host=$DOMAIN"
    extra_hosts:
      - "host.docker.internal:host-gateway"

networks:
  traefik-proxy:
    external: true

volumes:
  openproject-assets:
  openproject-logs:
EOF

echo -e "${GREEN}✓ Traefik configuration created${NC}"
echo ""
echo "Two options available:"
echo "1. Use systemd integration (automatic with system service)"
echo "2. Use Docker Compose (recommended for flexibility)"
echo ""
echo "To use Docker Compose:"
echo "  docker-compose up -d"
echo ""
echo "To use systemd integration:"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl restart openproject-web"