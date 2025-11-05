#!/bin/bash

# OpenProject Admin Management Script
# Helper script to manage admin rights for users

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}OpenProject Admin Management${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1) List all users"
    echo "2) List admin users"
    echo "3) Grant admin rights to a user"
    echo "4) Revoke admin rights from a user"
    echo "5) Grant admin to all 'administrators' group members"
    echo "6) Show user details"
    echo "7) Exit"
    echo ""
    echo -n "Choose an option: "
}

list_users() {
    echo -e "\n${YELLOW}All users:${NC}"
    docker exec openproject bundle exec rails runner "User.all.each { |u| puts \"#{u.login.ljust(20)} | Admin: #{u.admin? ? 'Yes' : 'No'.ljust(3)} | Email: #{u.mail}\" }"
}

list_admins() {
    echo -e "\n${YELLOW}Admin users:${NC}"
    docker exec openproject bundle exec rails runner "User.where(admin: true).each { |u| puts \"#{u.login.ljust(20)} | Email: #{u.mail}\" }"
}

grant_admin() {
    echo -n "Enter username to grant admin rights: "
    read username
    docker exec openproject bundle exec rails runner "
        user = User.find_by(login: '$username')
        if user
            user.update(admin: true)
            puts 'Admin rights granted to $username'
        else
            puts 'User $username not found'
        end
    "
}

revoke_admin() {
    echo -n "Enter username to revoke admin rights: "
    read username
    docker exec openproject bundle exec rails runner "
        user = User.find_by(login: '$username')
        if user
            if user.login == 'admin'
                puts 'Cannot revoke admin rights from default admin user'
            else
                user.update(admin: false)
                puts 'Admin rights revoked from $username'
            end
        else
            puts 'User $username not found'
        end
    "
}

grant_admin_to_group() {
    echo -e "\n${YELLOW}Granting admin rights to users matching 'administrator' pattern...${NC}"
    docker exec openproject bundle exec rails runner "
        count = 0
        # Check for users with 'admin' in their username
        User.where('login LIKE ? OR login LIKE ?', '%admin%', '%administrator%').each do |user|
            unless user.admin?
                user.update(admin: true)
                puts \"Granted admin rights to: #{user.login}\"
                count += 1
            end
        end
        
        # Also check for specific usernames
        ['administrator', 'admin'].each do |username|
            user = User.find_by(login: username)
            if user && !user.admin?
                user.update(admin: true)
                puts \"Granted admin rights to: #{user.login}\"
                count += 1
            end
        end
        
        if count == 0
            puts 'No users found to update'
        else
            puts \"Updated #{count} user(s)\"
        end
    "
}

show_user() {
    echo -n "Enter username to view details: "
    read username
    docker exec openproject bundle exec rails runner "
        user = User.find_by(login: '$username')
        if user
            puts '='*40
            puts \"Username: #{user.login}\"
            puts \"Email: #{user.mail}\"
            puts \"Name: #{user.firstname} #{user.lastname}\"
            puts \"Admin: #{user.admin? ? 'Yes' : 'No'}\"
            puts \"Created: #{user.created_at}\"
            puts \"Last login: #{user.last_login_on || 'Never'}\"
            puts \"Status: #{user.status == 1 ? 'Active' : 'Inactive'}\"
            puts '='*40
        else
            puts 'User $username not found'
        end
    "
}

# Main menu loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            list_users
            ;;
        2)
            list_admins
            ;;
        3)
            grant_admin
            ;;
        4)
            revoke_admin
            ;;
        5)
            grant_admin_to_group
            ;;
        6)
            show_user
            ;;
        7)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    echo "Press Enter to continue..."
    read
done