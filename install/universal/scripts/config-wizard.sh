#!/bin/bash
# Magnetico Configuration Wizard
# Interactive configuration system for database and service setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONFIG_DIR="/etc/magnetico"
CONFIG_FILE="$CONFIG_DIR/config.yml"
TEMP_CONFIG="/tmp/magnetico-config.yml"

# Function to print colored output
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    Magnetico Configuration Wizard${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Function to validate input
validate_input() {
    local prompt="$1"
    local default="$2"
    local validation_func="$3"
    
    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " input
            input=${input:-$default}
        else
            read -p "$prompt: " input
        fi
        
        if [ -n "$validation_func" ]; then
            if $validation_func "$input"; then
                echo "$input"
                return
            else
                print_error "Invalid input. Please try again."
            fi
        else
            echo "$input"
            return
        fi
    done
}

# Validation functions
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

validate_host() {
    local host="$1"
    if [[ "$host" =~ ^[a-zA-Z0-9.-]+$ ]] || [[ "$host" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_database_name() {
    local db_name="$1"
    if [[ "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test PostgreSQL connection
test_postgresql_connection() {
    local host="$1"
    local port="$2"
    local database="$3"
    local user="$4"
    local password="$5"
    
    print_status "Testing PostgreSQL connection..."
    
    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        print_warning "psql not found, skipping connection test"
        return 0
    fi
    
    # Test connection
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" &> /dev/null; then
        print_success "PostgreSQL connection successful"
        return 0
    else
        print_error "PostgreSQL connection failed"
        return 1
    fi
}

# Function to configure database
configure_database() {
    print_step "Database Configuration"
    echo ""
    
    # Database setup type
    echo "Database Setup Options:"
    echo "1) Install PostgreSQL locally"
    echo "2) Connect to existing PostgreSQL server"
    echo "3) Use SQLite (development only)"
    
    while true; do
        read -p "Choose option (1-3): " db_option
        case $db_option in
            1)
                configure_local_postgresql
                break
                ;;
            2)
                configure_remote_postgresql
                break
                ;;
            3)
                configure_sqlite
                break
                ;;
            *)
                print_error "Invalid option. Please choose 1, 2, or 3."
                ;;
        esac
    done
}

# Function to configure local PostgreSQL
configure_local_postgresql() {
    print_step "Local PostgreSQL Configuration"
    
    # Check if PostgreSQL is installed
    if ! command -v psql &> /dev/null; then
        print_status "PostgreSQL not found. Will install during setup."
        INSTALL_POSTGRESQL=true
    else
        print_status "PostgreSQL found. Using existing installation."
        INSTALL_POSTGRESQL=false
    fi
    
    # Database configuration
    DB_HOST="localhost"
    DB_PORT=$(validate_input "PostgreSQL port" "5432" validate_port)
    DB_NAME=$(validate_input "Database name" "magnetico" validate_database_name)
    DB_USER=$(validate_input "Database user" "magnetico" validate_database_name)
    
    # Generate random password
    DB_PASSWORD=$(openssl rand -base64 32)
    print_status "Generated random password for database user"
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
database:
  driver: postgresql
  host: $DB_HOST
  port: $DB_PORT
  name: $DB_NAME
  user: $DB_USER
  password: "$DB_PASSWORD"
EOF
    
    # Store installation flags
    echo "INSTALL_POSTGRESQL=$INSTALL_POSTGRESQL" >> "$TEMP_CONFIG"
    echo "DB_HOST=$DB_HOST" >> "$TEMP_CONFIG"
    echo "DB_PORT=$DB_PORT" >> "$TEMP_CONFIG"
    echo "DB_NAME=$DB_NAME" >> "$TEMP_CONFIG"
    echo "DB_USER=$DB_USER" >> "$TEMP_CONFIG"
    echo "DB_PASSWORD=$DB_PASSWORD" >> "$TEMP_CONFIG"
}

# Function to configure remote PostgreSQL
configure_remote_postgresql() {
    print_step "Remote PostgreSQL Configuration"
    
    DB_HOST=$(validate_input "PostgreSQL host" "localhost" validate_host)
    DB_PORT=$(validate_input "PostgreSQL port" "5432" validate_port)
    DB_NAME=$(validate_input "Database name" "magnetico" validate_database_name)
    DB_USER=$(validate_input "Database user" "magnetico" validate_database_name)
    
    while true; do
        read -s -p "Database password: " DB_PASSWORD
        echo
        if [ -n "$DB_PASSWORD" ]; then
            break
        else
            print_error "Password cannot be empty"
        fi
    done
    
    # Test connection
    if test_postgresql_connection "$DB_HOST" "$DB_PORT" "$DB_NAME" "$DB_USER" "$DB_PASSWORD"; then
        print_success "Connection test successful"
    else
        print_warning "Connection test failed, but continuing..."
    fi
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
database:
  driver: postgresql
  host: $DB_HOST
  port: $DB_PORT
  name: $DB_NAME
  user: $DB_USER
  password: "$DB_PASSWORD"
EOF
}

# Function to configure SQLite
configure_sqlite() {
    print_step "SQLite Configuration"
    
    DB_PATH="/var/lib/magnetico/magnetico.db"
    
    print_warning "SQLite is recommended for development only"
    print_warning "For production use, please use PostgreSQL"
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
database:
  driver: sqlite3
  path: $DB_PATH
EOF
}

# Function to configure web interface
configure_web() {
    print_step "Web Interface Configuration"
    echo ""
    
    WEB_HOST=$(validate_input "Web interface host" "0.0.0.0" validate_host)
    WEB_PORT=$(validate_input "Web interface port" "80" validate_port)
    
    # Check if port is available
    if netstat -tuln | grep -q ":$WEB_PORT "; then
        print_warning "Port $WEB_PORT is already in use"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            configure_web
            return
        fi
    fi
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
web:
  host: "$WEB_HOST"
  port: $WEB_PORT
EOF
}

# Function to configure DHT crawler
configure_dht() {
    print_step "DHT Crawler Configuration"
    echo ""
    
    DHT_PORT=$(validate_input "DHT crawler port" "6881" validate_port)
    
    # Check if port is available
    if netstat -tuln | grep -q ":$DHT_PORT "; then
        print_warning "Port $DHT_PORT is already in use"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            configure_dht
            return
        fi
    fi
    
    # Bootstrap nodes
    echo "DHT Bootstrap Nodes (comma-separated):"
    echo "Default: router.bittorrent.com:6881,dht.transmissionbt.com:6881"
    read -p "Bootstrap nodes: " bootstrap_nodes
    bootstrap_nodes=${bootstrap_nodes:-"router.bittorrent.com:6881,dht.transmissionbt.com:6881"}
    
    # Convert to YAML array
    IFS=',' read -ra NODES <<< "$bootstrap_nodes"
    bootstrap_yaml=""
    for node in "${NODES[@]}"; do
        bootstrap_yaml="$bootstrap_yaml    - \"$node\""
    done
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
dht:
  port: $DHT_PORT
  bootstrap_nodes:
$bootstrap_yaml
EOF
}

# Function to configure logging
configure_logging() {
    print_step "Logging Configuration"
    echo ""
    
    echo "Log Levels: debug, info, warn, error"
    LOG_LEVEL=$(validate_input "Log level" "info" "")
    
    LOG_FILE="/var/log/magnetico/magnetico.log"
    
    # Store configuration
    cat >> "$TEMP_CONFIG" << EOF
logging:
  level: $LOG_LEVEL
  file: "$LOG_FILE"
EOF
}

# Function to configure security
configure_security() {
    print_step "Security Configuration"
    echo ""
    
    # Rate limiting
    read -p "Enable rate limiting? (Y/n): " enable_rate_limit
    enable_rate_limit=${enable_rate_limit:-Y}
    
    if [[ $enable_rate_limit =~ ^[Yy]$ ]]; then
        RATE_LIMIT_REQUESTS=$(validate_input "Rate limit requests per minute" "100" "")
        RATE_LIMIT_BURST=$(validate_input "Rate limit burst size" "20" "")
        
        cat >> "$TEMP_CONFIG" << EOF
security:
  rate_limit:
    enabled: true
    requests_per_minute: $RATE_LIMIT_REQUESTS
    burst_size: $RATE_LIMIT_BURST
EOF
    else
        cat >> "$TEMP_CONFIG" << EOF
security:
  rate_limit:
    enabled: false
EOF
    fi
}

# Function to generate final configuration
generate_config() {
    print_step "Generating Configuration File"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Generate final YAML config
    cat > "$CONFIG_FILE" << EOF
# Magnetico Configuration
# Generated by configuration wizard on $(date)

EOF
    
    # Append database config
    grep -A 10 "database:" "$TEMP_CONFIG" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # Append web config
    grep -A 5 "web:" "$TEMP_CONFIG" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # Append DHT config
    grep -A 10 "dht:" "$TEMP_CONFIG" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # Append logging config
    grep -A 5 "logging:" "$TEMP_CONFIG" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # Append security config
    grep -A 10 "security:" "$TEMP_CONFIG" >> "$CONFIG_FILE"
    
    # Set proper permissions
    chmod 600 "$CONFIG_FILE"
    chown magnetico:magnetico "$CONFIG_FILE" 2>/dev/null || true
    
    print_success "Configuration file generated: $CONFIG_FILE"
}

# Function to show configuration summary
show_summary() {
    print_step "Configuration Summary"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration file: $CONFIG_FILE"
        echo ""
        echo "Contents:"
        cat "$CONFIG_FILE"
        echo ""
    else
        print_error "Configuration file not found"
    fi
}

# Function to show help
show_help() {
    echo "Magnetico Configuration Wizard"
    echo "=============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --config-file  Specify custom config file path"
    echo "  --database-only Configure database only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full configuration wizard"
    echo "  $0 --database-only    # Configure database only"
}

# Main configuration function
main() {
    local database_only=false
    local custom_config=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --config-file)
                custom_config="$2"
                shift 2
                ;;
            --database-only)
                database_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set custom config file if specified
    if [ -n "$custom_config" ]; then
        CONFIG_FILE="$custom_config"
        CONFIG_DIR=$(dirname "$CONFIG_FILE")
    fi
    
    # Show header
    print_header
    
    # Initialize temp config
    > "$TEMP_CONFIG"
    
    # Configure database
    configure_database
    
    if [ "$database_only" = false ]; then
        # Configure web interface
        configure_web
        
        # Configure DHT crawler
        configure_dht
        
        # Configure logging
        configure_logging
        
        # Configure security
        configure_security
    fi
    
    # Generate final configuration
    generate_config
    
    # Show summary
    show_summary
    
    # Cleanup
    rm -f "$TEMP_CONFIG"
    
    print_success "Configuration wizard completed!"
}

# Run main function
main "$@"
