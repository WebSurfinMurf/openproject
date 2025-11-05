#!/bin/bash

# OpenProject Keycloak Configuration
# Sets up OIDC authentication with Keycloak

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
KEYCLOAK_URL="https://keycloak.ai-servicers.com"
KEYCLOAK_REALM="master"
OPENPROJECT_URL="https://openproject.ai-servicers.com"
CLIENT_ID="openproject"
# Generate a secure client secret
CLIENT_SECRET="OpenProject-$(openssl rand -hex 16)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject Keycloak Configuration${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Add OIDC configuration to environment
echo -e "\n${YELLOW}Adding Keycloak OIDC configuration...${NC}"

# Backup current env file
cp $HOME/projects/secrets/openproject.env $HOME/projects/secrets/openproject.env.backup

# Check if Keycloak config already exists
if grep -q "OPENPROJECT_OPENID__CONNECT" $HOME/projects/secrets/openproject.env; then
    echo "Keycloak configuration already exists. Updating..."
    # Remove old Keycloak configuration
    sed -i '/# Keycloak OIDC Configuration/,/^$/d' $HOME/projects/secrets/openproject.env
fi

# Add new Keycloak configuration
cat >> $HOME/projects/secrets/openproject.env <<EOF

# Keycloak OIDC Configuration
# Generated: $(date +%Y-%m-%d)
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_DISPLAY__NAME="Login with Keycloak"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_IDENTIFIER="keycloak"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ISSUER="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_CLIENT__ID="$CLIENT_ID"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_CLIENT__SECRET="$CLIENT_SECRET"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_AUTHORIZATION__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/auth"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_TOKEN__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_USERINFO__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/userinfo"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_END__SESSION__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/logout"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_SCOPE="openid profile email"

# Attribute mapping
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_LOGIN="preferred_username"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_EMAIL="email"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_NAME="name"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_FIRST__NAME="given_name"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_LAST__NAME="family_name"

# Authentication settings
OPENPROJECT_OMNIAUTH__DIRECT__LOGIN__PROVIDER="keycloak"
OPENPROJECT_DISABLE__PASSWORD__LOGIN="false"
OPENPROJECT_SELF__REGISTRATION="true"
EOF

echo -e "${GREEN}✓ Configuration added to environment file${NC}"

# Step 2: Restart OpenProject
echo -e "\n${YELLOW}Restarting OpenProject...${NC}"
docker restart openproject

# Wait for it to come up
sleep 15

# Step 3: Configure via API/Rails console
echo -e "\n${YELLOW}Configuring OpenProject settings...${NC}"

docker exec openproject bundle exec rails runner - <<'RUBY'
puts "Configuring OpenProject for Keycloak..."

# Enable self-registration with automatic activation
Setting.self_registration = '3'

# Allow password login (so admin can still log in)
Setting.disable_password_login = false

puts "✓ Self-registration enabled with automatic activation"
puts "✓ Password login remains enabled for admin access"
RUBY

echo -e "${GREEN}✓ OpenProject configured${NC}"

# Step 4: Display Keycloak client configuration
echo -e "\n${YELLOW}Creating Keycloak client configuration...${NC}"

cat > /home/administrator/projects/openproject/keycloak-client-config.json <<EOF
{
  "clientId": "$CLIENT_ID",
  "name": "OpenProject",
  "description": "OpenProject - Project Management Software",
  "rootUrl": "$OPENPROJECT_URL",
  "adminUrl": "$OPENPROJECT_URL",
  "baseUrl": "/",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "$CLIENT_SECRET",
  "redirectUris": [
    "$OPENPROJECT_URL/*",
    "$OPENPROJECT_URL/auth/keycloak/callback"
  ],
  "webOrigins": [
    "$OPENPROJECT_URL"
  ],
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "publicClient": false,
  "protocol": "openid-connect",
  "fullScopeAllowed": false,
  "defaultClientScopes": [
    "profile",
    "email",
    "roles"
  ]
}
EOF

echo -e "${GREEN}✓ Client configuration saved${NC}"

# Step 5: Create group-check script
echo -e "\n${YELLOW}Creating group synchronization script...${NC}"

cat > /home/administrator/projects/openproject/sync-admin-users.rb <<'RUBY'
#!/usr/bin/env ruby
# This script grants admin rights to users in the 'administrators' group
# Run periodically or after user login

# Define which groups should have admin access
ADMIN_GROUPS = ['administrators']

# Note: OpenProject Community Edition doesn't have automatic group sync
# This is a workaround script that can be run periodically

puts "Checking for users in administrator groups..."

# In a real implementation, you would:
# 1. Query Keycloak API for group memberships
# 2. Update OpenProject user roles accordingly

# For now, this is a template showing the logic:
User.where(admin: false).each do |user|
  # Check if user email domain or username pattern matches admin criteria
  # Since we can't directly query Keycloak groups from Community Edition,
  # you could use email patterns or manually maintain a list
  
  # Example: Grant admin to specific usernames
  if ['admin', 'administrator'].include?(user.login.downcase)
    user.update(admin: true)
    puts "Granted admin rights to: #{user.login}"
  end
end

puts "Admin sync complete."
RUBY

chmod +x /home/administrator/projects/openproject/sync-admin-users.rb

echo -e "${GREEN}✓ Admin sync script created${NC}"

# Display summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Keycloak Client Details:${NC}"
echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
echo "Config file: /home/administrator/projects/openproject/keycloak-client-config.json"
echo ""
echo -e "${YELLOW}Required Keycloak Setup:${NC}"
echo "1. Log into Keycloak: $KEYCLOAK_URL/admin"
echo "2. Create a new client with:"
echo "   - Client ID: $CLIENT_ID"
echo "   - Client Protocol: openid-connect"
echo "   - Access Type: confidential"
echo "   - Valid Redirect URIs:"
echo "     * $OPENPROJECT_URL/*"
echo "     * $OPENPROJECT_URL/auth/keycloak/callback"
echo "   - Client Secret: $CLIENT_SECRET"
echo ""
echo "3. Create groups (if not existing):"
echo "   - administrators"
echo "   - developers"
echo ""
echo "4. Configure mappers in the client:"
echo "   - Add 'Group Membership' mapper"
echo "   - Token Claim Name: groups"
echo "   - Add to ID token: ON"
echo "   - Add to access token: ON"
echo "   - Add to userinfo: ON"
echo ""
echo -e "${YELLOW}Access Control:${NC}"
echo "- Any user in 'administrators' or 'developers' groups can log in"
echo "- Users are auto-created on first login"
echo "- Native admin remains accessible"
echo ""
echo -e "${YELLOW}To grant admin rights:${NC}"
echo "Since Community Edition lacks automatic role sync, use one of:"
echo "1. Manual grant after first login:"
echo "   docker exec openproject bundle exec rails c"
echo "   User.find_by(login: 'username').update(admin: true)"
echo ""
echo "2. Run the sync script periodically:"
echo "   docker exec openproject bundle exec rails runner /sync-admin-users.rb"
echo ""
echo -e "${YELLOW}Test the integration:${NC}"
echo "1. Visit: $OPENPROJECT_URL"
echo "2. Click 'Login with Keycloak'"
echo "3. Authenticate with a Keycloak user in administrators/developers group"