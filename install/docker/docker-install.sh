#!/bin/bash

# Magnetico Docker Installer
# This script installs Magnetico using Docker and Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/datagram1/magnetico"
DOCKER_COMPOSE_URL="$REPO_URL/raw/main/docker/docker-compose.yml"
ENV_TEMPLATE_URL="$REPO_URL/raw/main/docker/.env.template"

echo -e "${GREEN}Magnetico Docker Installer${NC}"
echo "=========================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker installation
check_docker() {
    if ! command_exists docker; then
        echo -e "${RED}Error: Docker is not installed.${NC}"
        echo "Please install Docker first:"
        echo "  - Linux: https://docs.docker.com/engine/install/"
        echo "  - macOS: https://docs.docker.com/desktop/mac/install/"
        echo "  - Windows: https://docs.docker.com/desktop/windows/install/"
        exit 1
    fi
    
    if ! command_exists docker-compose; then
        echo -e "${RED}Error: Docker Compose is not installed.${NC}"
        echo "Please install Docker Compose first:"
        echo "  - https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"
}

# Function to get user input
get_user_input() {
    echo -e "${YELLOW}Configuration Wizard${NC}"
    echo "=================="
    echo ""
    
    # Database configuration
    echo "Database Configuration:"
    echo "1) Use included PostgreSQL container (recommended)"
    echo "2) Connect to external PostgreSQL server"
    read -p "Choose option (1-2): " DB_OPTION
    
    case $DB_OPTION in
        1)
            DB_TYPE="internal"
            ;;
        2)
            DB_TYPE="external"
            read -p "PostgreSQL host: " POSTGRES_HOST
            read -p "PostgreSQL port (default: 5432): " POSTGRES_PORT
            POSTGRES_PORT=${POSTGRES_PORT:-5432}
            read -p "Database name: " POSTGRES_DB
            read -p "Username: " POSTGRES_USER
            read -s -p "Password: " POSTGRES_PASSWORD
            echo ""
            ;;
        *)
            echo -e "${RED}Invalid option. Using internal PostgreSQL.${NC}"
            DB_TYPE="internal"
            ;;
    esac
    
    # Web interface configuration
    read -p "Web interface port (default: 80): " WEB_PORT
    WEB_PORT=${WEB_PORT:-80}
    
    # DHT crawler configuration
    read -p "DHT crawler port (default: 6881): " DHT_PORT
    DHT_PORT=${DHT_PORT:-6881}
    
    # SSL configuration
    read -p "Enable SSL/HTTPS? (y/N): " ENABLE_SSL
    ENABLE_SSL=${ENABLE_SSL:-n}
    
    if [[ $ENABLE_SSL =~ ^[Yy]$ ]]; then
        read -p "SSL certificate path: " SSL_CERT_PATH
        read -p "SSL private key path: " SSL_KEY_PATH
    fi
}

# Function to create directory structure
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    
    mkdir -p magnetico-docker/{data,config,logs,ssl}
    cd magnetico-docker
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Function to download Docker Compose file
download_docker_compose() {
    echo -e "${YELLOW}Downloading Docker Compose configuration...${NC}"
    
    if command_exists curl; then
        curl -fsSL "$DOCKER_COMPOSE_URL" -o docker-compose.yml
    elif command_exists wget; then
        wget -q "$DOCKER_COMPOSE_URL" -O docker-compose.yml
    else
        echo -e "${RED}Error: Neither curl nor wget is available.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker Compose file downloaded${NC}"
}

# Function to create environment file
create_env_file() {
    echo -e "${YELLOW}Creating environment configuration...${NC}"
    
    cat > .env << EOF
# Magnetico Configuration
MAGNETICO_ADDR=0.0.0.0:8080
MAGNETICO_MAX_RPS=500
MAGNETICO_LEECH_MAX_N=1000

# Web Interface
WEB_PORT=$WEB_PORT
DHT_PORT=$DHT_PORT

# Database Configuration
EOF
    
    if [ "$DB_TYPE" = "internal" ]; then
        cat >> .env << EOF
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=magnetico
POSTGRES_USER=magnetico
POSTGRES_PASSWORD=$(openssl rand -base64 32)
EOF
    else
        cat >> .env << EOF
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=$POSTGRES_PORT
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF
    fi
    
    echo -e "${GREEN}✓ Environment file created${NC}"
}

# Function to start services
start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    # Pull images
    docker-compose pull
    
    # Start services
    docker-compose up -d
    
    echo -e "${GREEN}✓ Services started${NC}"
}

# Function to wait for services
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    
    # Wait for Magnetico to be ready
    for i in {1..30}; do
        if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Magnetico is ready${NC}"
            break
        fi
        echo "Waiting for Magnetico... ($i/30)"
        sleep 2
    done
    
    # Wait for web interface
    for i in {1..30}; do
        if curl -f -s http://localhost:$WEB_PORT > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Web interface is ready${NC}"
            break
        fi
        echo "Waiting for web interface... ($i/30)"
        sleep 2
    done
}

# Function to show status
show_status() {
    echo ""
    echo -e "${GREEN}Installation Complete!${NC}"
    echo "======================"
    echo ""
    echo -e "${BLUE}Service Management:${NC}"
    echo "  Start:   docker-compose up -d"
    echo "  Stop:    docker-compose down"
    echo "  Restart: docker-compose restart"
    echo "  Logs:    docker-compose logs -f"
    echo "  Status:  docker-compose ps"
    echo ""
    echo -e "${BLUE}Web Interface:${NC}"
    echo "  Local:   http://localhost:$WEB_PORT"
    echo "  Network: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
    echo ""
    echo -e "${BLUE}Database:${NC}"
    if [ "$DB_TYPE" = "internal" ]; then
        echo "  Type: PostgreSQL (Docker container)"
        echo "  Host: localhost:5432"
        echo "  Database: magnetico"
        echo "  User: magnetico"
        echo "  Password: Check .env file"
    else
        echo "  Type: External PostgreSQL"
        echo "  Host: $POSTGRES_HOST:$POSTGRES_PORT"
        echo "  Database: $POSTGRES_DB"
        echo "  User: $POSTGRES_USER"
    fi
    echo ""
    echo -e "${YELLOW}The DHT crawler will start automatically and begin discovering torrents.${NC}"
    echo -e "${YELLOW}The web interface is available immediately for searching.${NC}"
}

# Main installation logic
main() {
    # Check Docker installation
    check_docker
    
    # Get user configuration
    get_user_input
    
    # Create directory structure
    create_directories
    
    # Download Docker Compose file
    download_docker_compose
    
    # Create environment file
    create_env_file
    
    # Start services
    start_services
    
    # Wait for services
    wait_for_services
    
    # Show status
    show_status
}

# Run main function
main "$@"
