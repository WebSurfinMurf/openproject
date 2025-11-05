-- OpenProject Database Setup Script
-- Run this as the PostgreSQL superuser (admin)

-- Create OpenProject database user
CREATE USER openproject WITH PASSWORD 'OpenProject#Secure2025!';

-- Create the database
CREATE DATABASE openproject_production OWNER openproject;

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE openproject_production TO openproject;

-- Connect to the new database to set up extensions
\c openproject_production

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Grant schema permissions
GRANT CREATE ON SCHEMA public TO openproject;
GRANT ALL ON ALL TABLES IN SCHEMA public TO openproject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO openproject;

-- Show confirmation
\du openproject
\l openproject_production