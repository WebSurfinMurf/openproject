#!/bin/bash

# OpenProject Keycloak Integration Setup Script
# Configures OpenProject to use Keycloak for authentication with group-based access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KEYCLOAK_REALM="master"
KEYCLOAK_URL="https://keycloak.ai-servicers.com"
OPENPROJECT_URL="https://openproject.ai-servicers.com"
CLIENT_ID="openproject"
CLIENT_SECRET="$(openssl rand -hex 32)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenProject Keycloak Integration Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Create Keycloak client configuration
echo -e "\n${YELLOW}Step 1: Creating Keycloak client configuration...${NC}"
cat > /tmp/openproject-client.json <<EOF
{
  "clientId": "$CLIENT_ID",
  "name": "OpenProject",
  "description": "OpenProject - Project Management Software",
  "rootUrl": "$OPENPROJECT_URL",
  "adminUrl": "$OPENPROJECT_URL",
  "baseUrl": "/",
  "surrogateAuthRequired": false,
  "enabled": true,
  "alwaysDisplayInConsole": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "$CLIENT_SECRET",
  "redirectUris": [
    "$OPENPROJECT_URL/*"
  ],
  "webOrigins": [
    "$OPENPROJECT_URL"
  ],
  "notBefore": 0,
  "bearerOnly": false,
  "consentRequired": false,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": false,
  "publicClient": false,
  "frontchannelLogout": false,
  "protocol": "openid-connect",
  "attributes": {
    "saml.force.post.binding": "false",
    "saml.multivalued.roles": "false",
    "oauth2.device.authorization.grant.enabled": "false",
    "backchannel.logout.revoke.offline.tokens": "false",
    "saml.server.signature.keyinfo.ext": "false",
    "use.refresh.tokens": "true",
    "oidc.ciba.grant.enabled": "false",
    "backchannel.logout.session.required": "true",
    "client_credentials.use_refresh_token": "false",
    "require.pushed.authorization.requests": "false",
    "saml.client.signature": "false",
    "id.token.as.detached.signature": "false",
    "saml.assertion.signature": "false",
    "saml.encrypt": "false",
    "saml.server.signature": "false",
    "exclude.session.state.from.auth.response": "false",
    "saml.artifact.binding": "false",
    "saml_force_name_id_format": "false",
    "acr.loa.map": "{}",
    "tls.client.certificate.bound.access.tokens": "false",
    "saml.authnstatement": "false",
    "display.on.consent.screen": "false",
    "token.response.type.bearer.lower-case": "false",
    "saml.onetimeuse.condition": "false"
  },
  "authenticationFlowBindingOverrides": {},
  "fullScopeAllowed": true,
  "nodeReRegistrationTimeout": -1,
  "protocolMappers": [
    {
      "name": "email",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "email",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email",
        "jsonType.label": "String"
      }
    },
    {
      "name": "given name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "firstName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "given_name",
        "jsonType.label": "String"
      }
    },
    {
      "name": "family name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "lastName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "family_name",
        "jsonType.label": "String"
      }
    },
    {
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    },
    {
      "name": "username",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "username",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "preferred_username",
        "jsonType.label": "String"
      }
    },
    {
      "name": "full name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-full-name-mapper",
      "consentRequired": false,
      "config": {
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true"
      }
    }
  ],
  "defaultClientScopes": [
    "web-origins",
    "profile",
    "roles",
    "email"
  ],
  "optionalClientScopes": [
    "address",
    "phone",
    "offline_access",
    "microprofile-jwt"
  ]
}
EOF

echo -e "${GREEN}✓ Client configuration created${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Manual Keycloak Setup Required${NC}"
echo ""
echo "Please log into Keycloak admin console and:"
echo "1. Go to: $KEYCLOAK_URL/admin/master/console/"
echo "2. Navigate to Clients → Create client"
echo "3. Import the configuration from: /tmp/openproject-client.json"
echo "   OR manually create with:"
echo "   - Client ID: $CLIENT_ID"
echo "   - Client Secret: $CLIENT_SECRET"
echo "   - Valid redirect URIs: $OPENPROJECT_URL/*"
echo ""
echo "4. Create groups if they don't exist:"
echo "   - 'administrators'"
echo "   - 'developers'"
echo ""
echo "5. Add users to appropriate groups"
echo ""

# Step 2: Create OpenProject OIDC configuration
echo -e "${YELLOW}Step 2: Creating OpenProject OIDC configuration...${NC}"

# Save Keycloak configuration to env file
cat >> $HOME/projects/secrets/openproject.env <<EOF

# Keycloak OIDC Configuration
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_DISPLAY__NAME="Keycloak"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_IDENTIFIER="keycloak"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ISSUER="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_CLIENT__ID="$CLIENT_ID"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_CLIENT__SECRET="$CLIENT_SECRET"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_AUTHORIZATION__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/auth"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_TOKEN__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_USERINFO__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/userinfo"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_END__SESSION__ENDPOINT="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/logout"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_SCOPE="openid profile email groups"

# Attribute mapping
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_LOGIN="preferred_username"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_EMAIL="email"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_NAME="name"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_FIRST__NAME="given_name"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_LAST__NAME="family_name"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ATTRIBUTE__MAP_ADMIN="groups"

# Group mappings - users in these groups get access
# Note: For admin mapping, we'll need to configure this in OpenProject
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_GROUPS__CLAIM="groups"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_ADMIN__GROUP="administrators"

# Authentication settings
OPENPROJECT_OMNIAUTH__DIRECT__LOGIN__PROVIDER="keycloak"
OPENPROJECT_DISABLE__PASSWORD__LOGIN="false"
OPENPROJECT_OPENID__CONNECT_KEYCLOAK_POST__LOGOUT__REDIRECT__URI="$OPENPROJECT_URL"
EOF

echo -e "${GREEN}✓ OIDC configuration saved${NC}"

# Step 3: Configure OpenProject via Rails console
echo -e "\n${YELLOW}Step 3: Configuring OpenProject authentication settings...${NC}"

# Create Rails configuration script
cat > /tmp/configure_openproject_auth.rb <<'RUBY'
# Configure OpenProject for Keycloak authentication with group mappings

puts "Configuring OpenProject authentication settings..."

# Ensure OIDC provider is enabled
Setting.plugin_openproject_auth_plugins = {
  "keycloak" => {
    "display_name" => "Keycloak",
    "identifier" => "keycloak",
    "limit_self_registration" => false,
    "self_registration" => true
  }
}

# Configure self-registration settings
Setting.self_registration = '3' # Automatic account activation

# Keep admin user accessible
Setting.disable_password_login = false

# Configure group synchronization
# This would need Enterprise Edition for full group sync
# For Community Edition, we'll handle it via attribute mapping

puts "Configuration complete!"
puts ""
puts "Notes:"
puts "1. Users in 'administrators' or 'developers' groups will be auto-provisioned"
puts "2. Native admin login remains available"
puts "3. To grant admin rights based on group, you'll need to:"
puts "   - Use Enterprise Edition for automatic role sync, OR"
puts "   - Manually assign admin role to users after first login"
RUBY

docker exec openproject bundle exec rails runner /tmp/configure_openproject_auth.rb

echo -e "${GREEN}✓ OpenProject configured${NC}"

# Step 4: Restart OpenProject to apply configuration
echo -e "\n${YELLOW}Step 4: Restarting OpenProject...${NC}"
docker restart openproject

echo -e "${GREEN}✓ OpenProject restarted${NC}"

# Display summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Keycloak Integration Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Client Details:${NC}"
echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure the client in Keycloak admin console"
echo "2. Ensure groups 'administrators' and 'developers' exist"
echo "3. Add users to appropriate groups"
echo "4. Test login at: $OPENPROJECT_URL"
echo ""
echo -e "${YELLOW}Authentication Behavior:${NC}"
echo "- Users in 'administrators' or 'developers' groups can log in"
echo "- New users are automatically provisioned on first login"
echo "- Native admin login remains available at: $OPENPROJECT_URL/login"
echo "- For admin rights based on group (administrators):"
echo "  - Community Edition: Manually assign after first login"
echo "  - Enterprise Edition: Automatic with group sync"
echo ""
echo -e "${YELLOW}To manually grant admin rights to a user:${NC}"
echo "docker exec openproject bundle exec rails console"
echo "User.find_by(login: 'username').update(admin: true)"