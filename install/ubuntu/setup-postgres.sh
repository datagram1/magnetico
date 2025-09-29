#!/bin/bash

# PostgreSQL Setup Script for Magnetico
# This script sets up the PostgreSQL database for Magnetico

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-magnetico}"
POSTGRES_USER="${POSTGRES_USER:-magnetico}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

echo -e "${GREEN}PostgreSQL Setup for Magnetico${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo -e "${YELLOW}PostgreSQL client not found. Installing...${NC}"
    apt update
    apt install -y postgresql-client
fi

# Function to test PostgreSQL connection
test_connection() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local database=$5
    
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Test connection to PostgreSQL server
echo -e "${YELLOW}Testing PostgreSQL connection...${NC}"
if test_connection "$POSTGRES_HOST" "$POSTGRES_PORT" "postgres" "" "postgres"; then
    echo -e "${GREEN}Connected to PostgreSQL server as postgres user${NC}"
    ADMIN_USER="postgres"
    ADMIN_PASSWORD=""
elif test_connection "$POSTGRES_HOST" "$POSTGRES_PORT" "$POSTGRES_USER" "$POSTGRES_PASSWORD" "postgres"; then
    echo -e "${GREEN}Connected to PostgreSQL server as $POSTGRES_USER user${NC}"
    ADMIN_USER="$POSTGRES_USER"
    ADMIN_PASSWORD="$POSTGRES_PASSWORD"
else
    echo -e "${RED}Failed to connect to PostgreSQL server${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo "  1. PostgreSQL server is running on $POSTGRES_HOST:$POSTGRES_PORT"
    echo "  2. Network connectivity"
    echo "  3. Authentication credentials"
    exit 1
fi

# Create database user if it doesn't exist
echo -e "${YELLOW}Creating database user...${NC}"
PGPASSWORD="$ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_USER" -d postgres << EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$POSTGRES_USER') THEN
        CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
    END IF;
END
\$\$;
EOF

# Create database if it doesn't exist
echo -e "${YELLOW}Creating database...${NC}"
PGPASSWORD="$ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_USER" -d postgres << EOF
SELECT 'CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB')\gexec
EOF

# Grant privileges
echo -e "${YELLOW}Granting privileges...${NC}"
PGPASSWORD="$ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_USER" -d postgres << EOF
GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
EOF

# Create pg_trgm extension
echo -e "${YELLOW}Creating pg_trgm extension...${NC}"
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" << EOF
CREATE EXTENSION IF NOT EXISTS pg_trgm;
EOF

# Test final connection
echo -e "${YELLOW}Testing final connection...${NC}"
if test_connection "$POSTGRES_HOST" "$POSTGRES_PORT" "$POSTGRES_USER" "$POSTGRES_PASSWORD" "$POSTGRES_DB"; then
    echo -e "${GREEN}Database setup completed successfully!${NC}"
else
    echo -e "${RED}Failed to connect to the created database${NC}"
    exit 1
fi

# Display connection information
echo ""
echo -e "${GREEN}Database Configuration:${NC}"
echo "=================================="
echo "Host: $POSTGRES_HOST"
echo "Port: $POSTGRES_PORT"
echo "Database: $POSTGRES_DB"
echo "User: $POSTGRES_USER"
echo "Password: $POSTGRES_PASSWORD"
echo ""
echo -e "${GREEN}Connection URL:${NC}"
echo "postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"
echo ""
echo -e "${YELLOW}You can now use this configuration in your Magnetico setup.${NC}"
