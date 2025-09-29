-- Initialize PostgreSQL database for Magnetico
-- This script runs when the PostgreSQL container starts for the first time

-- Create the pg_trgm extension for full-text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create indexes for better performance
-- These will be created by Magnetico automatically, but we can pre-create them

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE magnetico TO magnetico;
