# OpenProject - Project Management Platform

> **For overall environment context, see: `/home/administrator/projects/AINotes/SYSTEM-OVERVIEW.md`**  
> **Network details: `/home/administrator/projects/AINotes/network.md`**  
> **Security configuration: `/home/administrator/projects/AINotes/security.md`**

## Current State (2025-09-05)

**Status**: ✅ FULLY OPERATIONAL  
**Access URL**: https://openproject.ai-servicers.com  
**Version**: OpenProject 14 Community Edition  
**Uptime**: 2+ days stable  
**Health Check**: PASSED - Application running  

### Usage Statistics
- **Database Size**: 28MB (largest PostgreSQL database)
- **Work Packages**: 95 items
- **Users**: 4 registered users
- **Projects**: 3 active projects
- **Active Connections**: 14 PostgreSQL connections (most active service)

## Architecture Overview

```
OpenProject Container (Port 80 internal)
         ↓
    Network: traefik-net
         ↓
    Traefik Reverse Proxy → https://openproject.ai-servicers.com
         ↓
    Backend Services:
    ├── PostgreSQL (openproject_production database - 28MB)
    ├── Redis (database 2 for caching/sessions)
    └── Container Storage (assets, logs, tmp files)
```

## Container Configuration

### Docker Deployment
- **Container Name**: openproject
- **Image**: openproject/openproject:14
- **Network**: traefik-net
- **Internal Port**: 80 (not 8080 - common mistake)
- **Environment**: Production mode
- **Worker Processes**: GoodJob background workers

### Resource Usage
- **Database Connections**: 14 active (includes worker processes)
- **Memory**: Monitor with `docker stats openproject`
- **Background Jobs**: GoodJob::Notifier running

## Database Configuration

### PostgreSQL Details
- **Host**: linuxserver.lan (internal) / localhost:5432 (external)
- **Database**: openproject_production
- **User**: administrator (using superuser - should create dedicated user for production)
- **Password**: Pass123qp (stored in secrets/openproject.env)
- **Size**: 28MB - largest database in PostgreSQL instance
- **Tables**: work_packages, users, projects, wikis, time_entries, etc.

### Redis Cache
- **Host**: linuxserver.lan
- **Port**: 6379
- **Database Number**: 2 (dedicated for OpenProject)
- **Purpose**: Session storage, caching, background job queuing

## Authentication & Access Control

### ⚠️ IMPORTANT: No Keycloak SSO
**OpenID Connect (OIDC) is an Enterprise Edition only feature**
- Community Edition does NOT support Keycloak/OIDC integration
- Must use native authentication (username/password)
- Consider OAuth2 proxy at Traefik level as workaround

### Current Authentication
- **Method**: Native authentication only
- **Default Admin**: admin/admin (CHANGE IMMEDIATELY)
- **Self-Registration**: Enabled with automatic activation
- **User Management**: Via admin panel or Rails console

### Admin Management
```bash
# Interactive admin management tool
./manage-admins.sh

# Grant admin to existing user
docker exec openproject bundle exec rails runner "User.find_by(login: 'username').update(admin: true)"

# List all admin users
docker exec openproject bundle exec rails runner "User.where(admin: true).pluck(:login)"

# Create new admin user
docker exec openproject bundle exec rails runner "
  u = User.create!(
    login: 'newadmin',
    firstname: 'First',
    lastname: 'Last',
    mail: 'admin@example.com',
    password: 'SecurePassword123!',
    password_confirmation: 'SecurePassword123!',
    admin: true
  )
  u.activate!
"
```

## Data Persistence

### Volume Mounts
```
/home/administrator/projects/data/openproject/
├── assets/     # Uploaded files and attachments
├── logs/       # Application logs
└── tmp/        # Temporary files and cache
```

### Backup Strategy
```bash
#!/bin/bash
# Backup script location: /home/administrator/projects/openproject/backup.sh

# Database backup
PGPASSWORD='Pass123qp' pg_dump -h localhost -U administrator openproject_production | \
  gzip > backup_$(date +%Y%m%d).sql.gz

# File attachments backup
tar -czf openproject_files_$(date +%Y%m%d).tar.gz \
  /home/administrator/projects/data/openproject/assets
```

## Common Operations

### Container Management
```bash
# View logs
docker logs -f openproject

# Restart container
docker restart openproject

# Check health
docker exec openproject curl -f http://localhost/health_checks/default

# Access Rails console
docker exec -it openproject bundle exec rails c

# Check background jobs
docker exec openproject bundle exec rails runner "GoodJob::Job.count"
```

### Database Operations
```bash
# Connect to database
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U administrator -d openproject_production

# Check database size
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U administrator -d openproject_production -c \
  "SELECT pg_size_pretty(pg_database_size('openproject_production'));"

# List active connections
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U administrator -d postgres -c \
  "SELECT * FROM pg_stat_activity WHERE datname = 'openproject_production';"
```

### Maintenance Tasks
```bash
# Clear cache
docker exec openproject bundle exec rake tmp:cache:clear

# Reindex search
docker exec openproject bundle exec rake search:rebuild

# Database migration (after upgrades)
docker exec openproject bundle exec rake db:migrate RAILS_ENV=production

# Asset precompilation
docker exec openproject bundle exec rake assets:precompile RAILS_ENV=production
```

## Troubleshooting

### Common Issues & Solutions

#### 1. Database Connection Issues
- **Symptom**: "Could not connect to database"
- **Solution**: Check PostgreSQL is running, verify credentials in environment file
- **Test**: `docker exec openproject bundle exec rails db:version`

#### 2. Redis Connection Issues
- **Symptom**: Session/cache errors
- **Solution**: Verify Redis is running on port 6379
- **Test**: `docker exec openproject bundle exec rails runner "Rails.cache.redis.ping"`

#### 3. High Memory Usage
- **Symptom**: Container using excessive RAM
- **Solution**: Adjust worker count in environment variables
- **Monitor**: `docker stats openproject`

#### 4. Authentication Issues
- **Symptom**: Can't log in after installation
- **Solution**: Reset admin password via Rails console
- **Command**: See Admin Management section above

### Log Locations
```bash
# Container logs (includes all Rails logs)
docker logs openproject --tail 100

# Check specific log level
docker logs openproject 2>&1 | grep ERROR

# Background job logs
docker logs openproject 2>&1 | grep GoodJob
```

## API & Integrations

### API Access
- **Base URL**: https://openproject.ai-servicers.com/api/v3
- **Authentication**: API key from user profile
- **Documentation**: https://openproject.ai-servicers.com/api/docs

### Example API Usage
```bash
# Get projects list
curl -H "apikey: YOUR_API_KEY" \
  https://openproject.ai-servicers.com/api/v3/projects

# Create work package
curl -X POST -H "apikey: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Test Task","project":{"href":"/api/v3/projects/1"}}' \
  https://openproject.ai-servicers.com/api/v3/work_packages
```

## Environment Variables

Key configuration in `$HOME/projects/secrets/openproject.env`:
```bash
# Database
DATABASE_URL=postgresql://administrator:Pass123qp@linuxserver.lan/openproject_production

# Redis
REDIS_URL=redis://linuxserver.lan:6379/2

# Rails
RAILS_ENV=production
OPENPROJECT_RAILS_ENV=production

# Features
OPENPROJECT_SELF__REGISTRATION=3  # 0=disabled, 3=auto-activation

# Performance
OPENPROJECT_WEB_WORKERS=4
OPENPROJECT_BACKGROUND_JOBS_WORKERS=2
```

## Migration Notes

### From Installation Attempts (2025-08-30)
1. **Port Confusion**: OpenProject uses port 80 internally, not 8080
2. **Database Password**: Special characters need URL encoding
3. **Network Access**: Use hostname (linuxserver.lan) not Docker gateway IPs
4. **Boolean Values**: Some env vars need integers (0/1/2/3) not true/false
5. **OIDC Limitation**: Community Edition doesn't support Keycloak/OIDC

### Future Considerations
1. **Create Dedicated Database User**: Stop using administrator superuser
2. **Implement Backup Automation**: Daily backups with retention policy
3. **Add Monitoring**: Integrate with observability stack
4. **Consider Alternatives**: If SSO is critical, consider Plane or Taiga

## Alternative Solutions with Free SSO

Since OpenProject Community doesn't support OIDC:

### Recommended Alternatives
1. **Plane** - Modern Jira alternative with free OIDC
2. **Taiga** - Agile management with SSO plugins
3. **Vikunja** - Task management with OIDC support
4. **Leantime** - Simple PM with OIDC

### Workarounds for OpenProject
1. **OAuth2 Proxy** - Add auth at Traefik level
2. **LDAP Bridge** - Use LDAP server synced with Keycloak
3. **API Sync** - Script to sync users from Keycloak

## Important Files & Scripts

- **Deploy Script**: `/home/administrator/projects/openproject/deploy.sh`
- **Admin Manager**: `/home/administrator/projects/openproject/manage-admins.sh`
- **Environment File**: `$HOME/projects/secrets/openproject.env`
- **Data Directory**: `/home/administrator/projects/data/openproject/`
- **This Documentation**: `/home/administrator/projects/openproject/CLAUDE.md`

## Security Notes

1. **Change Default Admin Password** immediately after installation
2. **Database User**: Create dedicated user instead of using superuser
3. **Network Isolation**: Only exposed through Traefik reverse proxy
4. **Regular Updates**: `docker pull openproject/openproject:14`
5. **Backup Data**: Implement automated backup strategy

---
*Last Updated: 2025-09-05 by Claude*
*Next Review: When implementing backup automation or considering SSO alternatives*