#!/bin/bash
# Database Setup Script for Magnetico
# Handles PostgreSQL installation, configuration, and database creation

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
SERVICE_USER="magnetico"
POSTGRESQL_VERSION="15"

# Function to print colored output
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

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to install PostgreSQL on Ubuntu/Debian
install_postgresql_ubuntu() {
    print_step "Installing PostgreSQL on Ubuntu/Debian..."
    
    # Update package list
    apt-get update
    
    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib postgresql-client
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    print_success "PostgreSQL installed and started"
}

# Function to install PostgreSQL on CentOS/RHEL
install_postgresql_centos() {
    print_step "Installing PostgreSQL on CentOS/RHEL..."
    
    # Install PostgreSQL repository
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    # Install PostgreSQL
    dnf install -y postgresql15-server postgresql15-contrib postgresql15
    
    # Initialize database
    /usr/pgsql-15/bin/postgresql-15-setup initdb
    
    # Start and enable PostgreSQL
    systemctl start postgresql-15
    systemctl enable postgresql-15
    
    print_success "PostgreSQL installed and started"
}

# Function to install PostgreSQL on macOS
install_postgresql_macos() {
    print_step "Installing PostgreSQL on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is required but not installed"
        print_status "Please install Homebrew first: https://brew.sh/"
        exit 1
    fi
    
    # Install PostgreSQL
    brew install postgresql@15
    
    # Start PostgreSQL service
    brew services start postgresql@15
    
    print_success "PostgreSQL installed and started"
}

# Function to install PostgreSQL
install_postgresql() {
    local platform=$1
    
    print_step "Installing PostgreSQL..."
    
    case $platform in
        "linux")
            local distro=$(detect_distro)
            case $distro in
                "ubuntu"|"debian")
                    install_postgresql_ubuntu
                    ;;
                "centos"|"rhel"|"fedora")
                    install_postgresql_centos
                    ;;
                *)
                    print_error "Unsupported Linux distribution: $distro"
                    exit 1
                    ;;
            esac
            ;;
        "darwin")
            install_postgresql_macos
            ;;
        *)
            print_error "Unsupported platform: $platform"
            exit 1
            ;;
    esac
}

# Function to create PostgreSQL database and user
create_postgresql_database() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    
    print_step "Creating PostgreSQL database and user..."
    
    # Create database user
    sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_password';" 2>/dev/null || true
    
    # Create database
    sudo -u postgres psql -c "CREATE DATABASE $db_name OWNER $db_user;" 2>/dev/null || true
    
    # Grant privileges
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;" 2>/dev/null || true
    
    # Install pg_trgm extension
    sudo -u postgres psql -d "$db_name" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" 2>/dev/null || true
    
    print_success "Database and user created successfully"
}

# Function to test PostgreSQL connection
test_postgresql_connection() {
    local host="$1"
    local port="$2"
    local database="$3"
    local user="$4"
    local password="$5"
    
    print_step "Testing PostgreSQL connection..."
    
    # Test connection
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" &> /dev/null; then
        print_success "PostgreSQL connection successful"
        return 0
    else
        print_error "PostgreSQL connection failed"
        return 1
    fi
}

# Function to configure PostgreSQL for remote connections
configure_postgresql_remote() {
    local platform=$1
    
    print_step "Configuring PostgreSQL for remote connections..."
    
    case $platform in
        "linux")
            # Configure postgresql.conf
            local pg_config="/etc/postgresql/15/main/postgresql.conf"
            if [ ! -f "$pg_config" ]; then
                pg_config="/var/lib/pgsql/15/data/postgresql.conf"
            fi
            
            if [ -f "$pg_config" ]; then
                # Enable listening on all addresses
                sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$pg_config"
                
                # Restart PostgreSQL
                systemctl restart postgresql
                print_success "PostgreSQL configured for remote connections"
            else
                print_warning "PostgreSQL configuration file not found"
            fi
            ;;
        "darwin")
            # macOS PostgreSQL configuration
            local pg_config="/opt/homebrew/var/postgresql@15/postgresql.conf"
            if [ -f "$pg_config" ]; then
                sed -i '' "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$pg_config"
                brew services restart postgresql@15
                print_success "PostgreSQL configured for remote connections"
            else
                print_warning "PostgreSQL configuration file not found"
            fi
            ;;
    esac
}

# Function to setup local PostgreSQL
setup_local_postgresql() {
    local platform="$1"
    local db_name="$2"
    local db_user="$3"
    local db_password="$4"
    
    print_step "Setting up local PostgreSQL..."
    
    # Install PostgreSQL if not already installed
    if ! command -v psql &> /dev/null; then
        install_postgresql "$platform"
    else
        print_status "PostgreSQL already installed"
    fi
    
    # Create database and user
    create_postgresql_database "$db_name" "$db_user" "$db_password"
    
    # Test connection
    test_postgresql_connection "localhost" "5432" "$db_name" "$db_user" "$db_password"
    
    print_success "Local PostgreSQL setup completed"
}

# Function to setup remote PostgreSQL
setup_remote_postgresql() {
    local host="$1"
    local port="$2"
    local database="$3"
    local user="$4"
    local password="$5"
    
    print_step "Setting up remote PostgreSQL connection..."
    
    # Test connection
    if test_postgresql_connection "$host" "$port" "$database" "$user" "$password"; then
        print_success "Remote PostgreSQL connection successful"
    else
        print_error "Failed to connect to remote PostgreSQL"
        exit 1
    fi
    
    # Check if pg_trgm extension is available
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm';" | grep -q "1"; then
        print_status "pg_trgm extension is available"
    else
        print_warning "pg_trgm extension not found. Installing..."
        PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" || print_warning "Failed to install pg_trgm extension"
    fi
}

# Function to setup SQLite
setup_sqlite() {
    local db_path="$1"
    
    print_step "Setting up SQLite database..."
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$db_path")"
    
    # Create database file
    touch "$db_path"
    
    # Set proper permissions
    chown "$SERVICE_USER:$SERVICE_USER" "$db_path"
    chmod 600 "$db_path"
    
    print_success "SQLite database created: $db_path"
}

# Function to show help
show_help() {
    echo "Magnetico Database Setup Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  --platform PLATFORM     Target platform (linux, darwin, windows)"
    echo "  --db-type TYPE          Database type (postgresql, sqlite)"
    echo "  --db-host HOST          Database host (for remote PostgreSQL)"
    echo "  --db-port PORT          Database port (default: 5432)"
    echo "  --db-name NAME          Database name (default: magnetico)"
    echo "  --db-user USER          Database user (default: magnetico)"
    echo "  --db-password PASS      Database password"
    echo "  --db-path PATH          Database path (for SQLite)"
    echo ""
    echo "Examples:"
    echo "  $0 --platform linux --db-type postgresql"
    echo "  $0 --platform darwin --db-type sqlite --db-path /var/lib/magnetico/magnetico.db"
    echo "  $0 --platform linux --db-type postgresql --db-host remote.example.com --db-user myuser"
}

# Main function
main() {
    local platform=""
    local db_type=""
    local db_host="localhost"
    local db_port="5432"
    local db_name="magnetico"
    local db_user="magnetico"
    local db_password=""
    local db_path=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            --db-type)
                db_type="$2"
                shift 2
                ;;
            --db-host)
                db_host="$2"
                shift 2
                ;;
            --db-port)
                db_port="$2"
                shift 2
                ;;
            --db-name)
                db_name="$2"
                shift 2
                ;;
            --db-user)
                db_user="$2"
                shift 2
                ;;
            --db-password)
                db_password="$2"
                shift 2
                ;;
            --db-path)
                db_path="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$platform" ]; then
        print_error "Platform is required"
        show_help
        exit 1
    fi
    
    if [ -z "$db_type" ]; then
        print_error "Database type is required"
        show_help
        exit 1
    fi
    
    # Generate password if not provided
    if [ -z "$db_password" ] && [ "$db_type" = "postgresql" ]; then
        db_password=$(openssl rand -base64 32)
        print_status "Generated random password for database user"
    fi
    
    # Setup database based on type
    case $db_type in
        "postgresql")
            if [ "$db_host" = "localhost" ]; then
                setup_local_postgresql "$platform" "$db_name" "$db_user" "$db_password"
            else
                setup_remote_postgresql "$db_host" "$db_port" "$db_name" "$db_user" "$db_password"
            fi
            ;;
        "sqlite")
            if [ -z "$db_path" ]; then
                print_error "Database path is required for SQLite"
                exit 1
            fi
            setup_sqlite "$db_path"
            ;;
        *)
            print_error "Unsupported database type: $db_type"
            exit 1
            ;;
    esac
    
    print_success "Database setup completed successfully!"
}

# Run main function
main "$@"
