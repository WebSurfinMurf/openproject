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
