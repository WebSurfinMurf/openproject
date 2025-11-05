#!/bin/bash

# OpenProject Deployment Script
# Deploys OpenProject container with Traefik integration

set -e

# Configuration
PROJECT_NAME="openproject"
CONTAINER_NAME="openproject"
IMAGE="openproject/openproject:14"
NETWORK="traefik-net"
DOMAIN="openproject.ai-servicers.com"
SECRETS_FILE="$HOME/projects/secrets/openproject.env"
DATA_DIR="/home/administrator/projects/data/openproject"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if secrets file exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${RED}Error: Secrets file not found at $SECRETS_FILE${NC}"
    exit 1
fi

# Create data directories
echo -e "\n${YELLOW}Creating data directories...${NC}"
mkdir -p $DATA_DIR/{assets,logs,tmp}
chmod 755 $DATA_DIR

# Stop and remove existing container if it exists
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo -e "\n${YELLOW}Stopping existing container...${NC}"
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

# Pull latest image
echo -e "\n${YELLOW}Pulling latest image...${NC}"
docker pull $IMAGE

# Deploy container
echo -e "\n${YELLOW}Deploying OpenProject container...${NC}"
docker run -d \
  --name $CONTAINER_NAME \
  --network $NETWORK \
  --env-file $SECRETS_FILE \
  -v $DATA_DIR/assets:/var/openproject/assets \
  -v $DATA_DIR/logs:/var/log/openproject \
  -v $DATA_DIR/tmp:/opt/openproject/tmp \
  --label "traefik.enable=true" \
  --label "traefik.docker.network=$NETWORK" \
  --label "traefik.http.routers.$PROJECT_NAME.rule=Host(\`$DOMAIN\`)" \
  --label "traefik.http.routers.$PROJECT_NAME.entrypoints=websecure" \
  --label "traefik.http.routers.$PROJECT_NAME.tls=true" \
  --label "traefik.http.routers.$PROJECT_NAME.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.$PROJECT_NAME.loadbalancer.server.port=80" \
  --label "traefik.http.routers.$PROJECT_NAME.middlewares=$PROJECT_NAME-headers" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.customrequestheaders.X-Forwarded-Proto=https" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.customrequestheaders.X-Forwarded-Host=$DOMAIN" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.customrequestheaders.X-Forwarded-Port=443" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.customrequestheaders.X-Forwarded-Ssl=on" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsSeconds=31536000" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsIncludeSubdomains=true" \
  --label "traefik.http.middlewares.$PROJECT_NAME-headers.headers.stsPreload=true" \
  --add-host host.docker.internal:host-gateway \
  --restart unless-stopped \
  $IMAGE

# Wait for container to start
echo -e "\n${YELLOW}Waiting for container to start...${NC}"
sleep 10

# Check if container is running
if docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container failed to start${NC}"
    echo "Checking logs..."
    docker logs $CONTAINER_NAME --tail 50
    exit 1
fi

# Run database migrations
echo -e "\n${YELLOW}Running database migrations...${NC}"
docker exec $CONTAINER_NAME bundle exec rake db:migrate RAILS_ENV=production

# Check if database needs seeding (first run)
echo -e "\n${YELLOW}Checking if database needs seeding...${NC}"
if ! docker exec $CONTAINER_NAME bundle exec rails runner "puts User.where(admin: true).exists?" 2>/dev/null | grep -q "true"; then
    echo "Seeding database with initial data..."
    docker exec $CONTAINER_NAME bundle exec rake db:seed RAILS_ENV=production
    echo -e "${GREEN}✓ Database seeded${NC}"
else
    echo -e "${GREEN}✓ Database already initialized${NC}"
fi

# Health check
echo -e "\n${YELLOW}Performing health check...${NC}"
sleep 10
if docker exec $CONTAINER_NAME curl -f http://localhost:8080/health_checks/default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OpenProject is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Health check failed, but service may still be starting...${NC}"
fi

# Display status
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Container Status:"
docker ps --filter name=$CONTAINER_NAME --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo -e "Access OpenProject at: ${YELLOW}https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Default Credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${RED}⚠ IMPORTANT: Change the admin password immediately!${NC}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  docker logs -f $CONTAINER_NAME                    # View logs"
echo "  docker exec $CONTAINER_NAME bundle exec rails c   # Rails console"
echo "  docker restart $CONTAINER_NAME                    # Restart container"
echo "  docker exec $CONTAINER_NAME rake -T               # List available rake tasks"