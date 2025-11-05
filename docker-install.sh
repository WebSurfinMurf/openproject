#!/bin/bash

# OpenProject Docker Installation Script
# Deploys OpenProject using Docker with existing PostgreSQL, Redis, and Traefik

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_HOST="172.17.0.1"  # Docker host IP
POSTGRES_PORT="5432"
POSTGRES_DB="openproject_production"
POSTGRES_USER="openproject"
POSTGRES_PASSWORD="OpenProject#Secure2025!"
REDIS_HOST="172.17.0.1"     # Docker host IP
REDIS_PORT="6379"
REDIS_PASSWORD="rvSqetVQklW4AjSpxk4vX5vvc"
DOMAIN="openproject.ai-servicers.com"

echo -e "${GREEN}OpenProject Docker Installation Script${NC}"
echo -e "${GREEN}======================================${NC}"

# Step 1: Database Setup
echo -e "\n${YELLOW}Step 1: Setting up PostgreSQL database...${NC}"
echo "Creating database and user for OpenProject..."

PGPASSWORD=Pass123qp psql -h localhost -p $POSTGRES_PORT -U admin -d postgres <<EOF
-- Create OpenProject database user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'openproject') THEN
        CREATE USER openproject WITH PASSWORD '$POSTGRES_PASSWORD';
    END IF;
END\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE openproject_production OWNER openproject'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'openproject_production')\\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE openproject_production TO openproject;

-- Connect to the database and create extensions
\\c openproject_production
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Grant schema permissions
GRANT CREATE ON SCHEMA public TO openproject;
GRANT ALL ON ALL TABLES IN SCHEMA public TO openproject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO openproject;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database setup complete${NC}"
else
    echo -e "${RED}✗ Database setup failed${NC}"
    exit 1
fi

# Step 2: Create Docker network if needed
echo -e "\n${YELLOW}Step 2: Setting up Docker network...${NC}"
if ! docker network ls | grep -q "traefik-proxy"; then
    docker network create traefik-proxy
    echo -e "${GREEN}✓ Created traefik-proxy network${NC}"
else
    echo -e "${GREEN}✓ traefik-proxy network already exists${NC}"
fi

# Step 3: Create directories
echo -e "\n${YELLOW}Step 3: Creating data directories...${NC}"
mkdir -p /home/administrator/projects/data/openproject/{pgdata,assets,logs}
chmod 755 /home/administrator/projects/data/openproject

echo -e "${GREEN}✓ Directories created${NC}"

# Step 4: Create environment file
echo -e "\n${YELLOW}Step 4: Creating environment configuration...${NC}"
cat > /home/administrator/projects/openproject/.env <<EOF
# Database Configuration
DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB

# Redis Configuration
REDIS_URL=redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2
OPENPROJECT_CACHE_STORE=redis
OPENPROJECT_CACHE_REDIS_URL=redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2
OPENPROJECT_SESSION_STORE=redis
OPENPROJECT_SESSION_REDIS_URL=redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2

# Application Configuration
OPENPROJECT_HOST=$DOMAIN
OPENPROJECT_PROTOCOL=https
OPENPROJECT_HSTS=true
RAILS_ENV=production

# Performance Settings
OPENPROJECT_WEB_WORKERS=4
OPENPROJECT_WEB_THREADS=5
OPENPROJECT_WEB_MAX_THREADS=10
OPENPROJECT_BACKGROUND_JOBS_WORKERS=2

# File Storage
OPENPROJECT_ATTACHMENTS_STORAGE_PATH=/var/openproject/assets

# Admin Email (for initial setup)
OPENPROJECT_ADMIN_EMAIL=websurfinmurf@gmail.com

# Secret Key Base (generate a new one for production)
SECRET_KEY_BASE=$(openssl rand -hex 64)
EOF

echo -e "${GREEN}✓ Environment file created${NC}"

# Step 5: Create Docker Compose file
echo -e "\n${YELLOW}Step 5: Creating Docker Compose configuration...${NC}"
cat > /home/administrator/projects/openproject/docker-compose.yml <<'EOF'
version: '3.8'

services:
  openproject:
    image: openproject/openproject:14
    container_name: openproject
    restart: unless-stopped
    env_file: .env
    volumes:
      - /home/administrator/projects/data/openproject/assets:/var/openproject/assets
      - /home/administrator/projects/data/openproject/logs:/var/log/openproject
      - openproject-tmp:/opt/openproject/tmp
    networks:
      - traefik-proxy
      - openproject-internal
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik-proxy"
      
      # HTTP Router
      - "traefik.http.routers.openproject.rule=Host(\`openproject.ai-servicers.com\`)"
      - "traefik.http.routers.openproject.entrypoints=websecure"
      - "traefik.http.routers.openproject.tls=true"
      - "traefik.http.routers.openproject.tls.certresolver=letsencrypt"
      - "traefik.http.routers.openproject.service=openproject"
      - "traefik.http.routers.openproject.middlewares=openproject-headers"
      
      # Service
      - "traefik.http.services.openproject.loadbalancer.server.port=8080"
      
      # Headers Middleware
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Host=openproject.ai-servicers.com"
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Port=443"
      - "traefik.http.middlewares.openproject-headers.headers.customrequestheaders.X-Forwarded-Ssl=on"
      
      # Security Headers
      - "traefik.http.middlewares.openproject-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.openproject-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.openproject-headers.headers.stsPreload=true"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health_checks/default"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s

networks:
  traefik-proxy:
    external: true
  openproject-internal:
    driver: bridge

volumes:
  openproject-tmp:
EOF

echo -e "${GREEN}✓ Docker Compose file created${NC}"

# Step 6: Create deployment script
echo -e "\n${YELLOW}Step 6: Creating deployment script...${NC}"
cat > /home/administrator/projects/openproject/deploy.sh <<'EOF'
#!/bin/bash

# OpenProject Deployment Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Deploying OpenProject...${NC}"

# Pull latest image
echo "Pulling latest OpenProject image..."
docker-compose pull

# Start services
echo "Starting OpenProject..."
docker-compose up -d

# Wait for service to be ready
echo "Waiting for OpenProject to be ready..."
sleep 30

# Check health
if docker exec openproject curl -f http://localhost:8080/health_checks/default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OpenProject is healthy${NC}"
else
    echo -e "${RED}✗ OpenProject health check failed${NC}"
    echo "Checking logs..."
    docker-compose logs --tail=50
fi

# Run database migrations
echo "Running database migrations..."
docker-compose exec openproject bundle exec rake db:migrate

# Seed database (only on first run)
if ! docker-compose exec openproject bundle exec rails runner "puts User.where(admin: true).exists?" | grep -q "true"; then
    echo "Seeding database..."
    docker-compose exec openproject bundle exec rake db:seed
fi

echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""
echo "Access OpenProject at: https://openproject.ai-servicers.com"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${RED}Remember to change the admin password immediately!${NC}"
EOF

chmod +x /home/administrator/projects/openproject/deploy.sh

echo -e "${GREEN}✓ Deployment script created${NC}"

# Step 7: Deploy OpenProject
echo -e "\n${YELLOW}Step 7: Deploying OpenProject...${NC}"
cd /home/administrator/projects/openproject
./deploy.sh

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject Docker Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Useful commands:"
echo "  cd /home/administrator/projects/openproject"
echo "  docker-compose logs -f          # View logs"
echo "  docker-compose restart          # Restart service"
echo "  docker-compose exec openproject bundle exec rails console  # Rails console"
echo "  docker-compose down             # Stop service"