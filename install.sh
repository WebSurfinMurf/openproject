#!/bin/bash

# OpenProject Installation Script
# Uses existing PostgreSQL, Redis, and Traefik infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_DB="openproject_production"
POSTGRES_USER="openproject"
POSTGRES_PASSWORD="OpenProject#Secure2025!"
REDIS_HOST="localhost"
REDIS_PORT="6379"
REDIS_PASSWORD="rvSqetVQklW4AjSpxk4vX5vvc"
DOMAIN="openproject.ai-servicers.com"

echo -e "${GREEN}OpenProject Installation Script${NC}"
echo -e "${GREEN}================================${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root directly.${NC}"
   echo "It will use sudo when needed."
   exit 1
fi

# Step 1: Database Setup
echo -e "\n${YELLOW}Step 1: Setting up PostgreSQL database...${NC}"
echo "Please enter the PostgreSQL admin password when prompted:"
PGPASSWORD=Pass123qp psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U admin -f setup-database.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database setup complete${NC}"
else
    echo -e "${RED}✗ Database setup failed${NC}"
    exit 1
fi

# Step 2: Add OpenProject Repository
echo -e "\n${YELLOW}Step 2: Adding OpenProject repository...${NC}"

# Import GPG key
wget -qO- https://dl.packager.io/srv/opf/openproject/key | sudo apt-key add -

# Add repository
sudo wget -O /etc/apt/sources.list.d/openproject.list \
  https://dl.packager.io/srv/opf/openproject/stable/14/installer/ubuntu/$(lsb_release -cs).repo

# Update package list
sudo apt-get update

echo -e "${GREEN}✓ Repository added${NC}"

# Step 3: Install OpenProject
echo -e "\n${YELLOW}Step 3: Installing OpenProject package...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openproject

echo -e "${GREEN}✓ OpenProject installed${NC}"

# Step 4: Create configuration file
echo -e "\n${YELLOW}Step 4: Creating OpenProject configuration...${NC}"

sudo mkdir -p /etc/openproject/conf.d

# Create database configuration
sudo tee /etc/openproject/conf.d/database.yml > /dev/null <<EOF
production:
  adapter: postgresql
  encoding: unicode
  database: $POSTGRES_DB
  pool: 20
  username: $POSTGRES_USER
  password: $POSTGRES_PASSWORD
  host: $POSTGRES_HOST
  port: $POSTGRES_PORT
EOF

# Create environment configuration
sudo tee /etc/openproject/conf.d/environment.conf > /dev/null <<EOF
# Database URL
export DATABASE_URL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"

# Redis configuration
export REDIS_URL="redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2"
export OPENPROJECT_CACHE_STORE="redis"
export OPENPROJECT_CACHE_REDIS_URL="redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2"
export OPENPROJECT_SESSION_STORE="redis"
export OPENPROJECT_SESSION_REDIS_URL="redis://:$REDIS_PASSWORD@$REDIS_HOST:$REDIS_PORT/2"

# Rails environment
export RAILS_ENV="production"
export OPENPROJECT_RAILS_ENV="production"

# Web server configuration
export OPENPROJECT_WEB_WORKERS="4"
export OPENPROJECT_WEB_THREADS="5"
export OPENPROJECT_WEB_MAX_THREADS="10"
export OPENPROJECT_BACKGROUND_JOBS_WORKERS="2"

# Application settings
export OPENPROJECT_HOST="$DOMAIN"
export OPENPROJECT_PROTOCOL="https"
export OPENPROJECT_HSTS="true"

# File storage
export OPENPROJECT_ATTACHMENTS_STORAGE_PATH="/var/db/openproject/files"

# Logging
export OPENPROJECT_RAILS_LOG_TO_STDOUT="false"
export OPENPROJECT_LOG_LEVEL="info"
EOF

echo -e "${GREEN}✓ Configuration created${NC}"

# Step 5: Configure OpenProject
echo -e "\n${YELLOW}Step 5: Running OpenProject configuration...${NC}"

# Create installer configuration
sudo tee /tmp/openproject-installer.dat > /dev/null <<EOF
postgres/autoinstall skip
postgres/db_host $POSTGRES_HOST
postgres/db_port $POSTGRES_PORT
postgres/db_name $POSTGRES_DB
postgres/db_username $POSTGRES_USER
postgres/db_password $POSTGRES_PASSWORD
server/autoinstall skip
server/hostname $DOMAIN
server/ssl no
repositories/svn-install skip
repositories/git-install skip
smtp/autoinstall skip
memcached/autoinstall skip
EOF

# Run configuration with the preset answers
sudo openproject configure < /tmp/openproject-installer.dat

echo -e "${GREEN}✓ OpenProject configured${NC}"

# Step 6: Initialize database
echo -e "\n${YELLOW}Step 6: Initializing database...${NC}"
sudo openproject run rake db:migrate
sudo openproject run rake db:seed

echo -e "${GREEN}✓ Database initialized${NC}"

# Step 7: Precompile assets
echo -e "\n${YELLOW}Step 7: Precompiling assets...${NC}"
sudo openproject run rake assets:precompile

echo -e "${GREEN}✓ Assets precompiled${NC}"

# Step 8: Enable and start services
echo -e "\n${YELLOW}Step 8: Starting OpenProject services...${NC}"
sudo systemctl enable openproject
sudo systemctl enable openproject-web
sudo systemctl enable openproject-worker
sudo systemctl start openproject
sudo systemctl start openproject-web
sudo systemctl start openproject-worker

echo -e "${GREEN}✓ Services started${NC}"

# Step 9: Create Traefik configuration
echo -e "\n${YELLOW}Step 9: Creating Traefik configuration...${NC}"
./setup-traefik.sh

echo -e "${GREEN}✓ Traefik configured${NC}"

# Final status check
echo -e "\n${YELLOW}Checking service status...${NC}"
sudo systemctl status openproject-web --no-pager | head -10
sudo systemctl status openproject-worker --no-pager | head -10

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Access OpenProject at: ${YELLOW}https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Default admin credentials:${NC}"
echo "Username: admin"
echo "Password: admin"
echo ""
echo -e "${RED}IMPORTANT: Change the admin password immediately!${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "Check logs: sudo journalctl -u openproject-web -f"
echo "Rails console: sudo openproject run console"
echo "Restart services: sudo systemctl restart openproject-web openproject-worker"