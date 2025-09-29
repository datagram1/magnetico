#!/bin/bash
# macOS Installation Script for Magnetico

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
INSTALL_DIR="/opt/magnetico"
CONFIG_DIR="/etc/magnetico"
LOG_DIR="/var/log/magnetico"
SERVICE_USER="magnetico"
SERVICE_NAME="com.magnetico"
NGINX_CONFIG="/opt/homebrew/etc/nginx/servers/magnetico.conf"

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

# Function to check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is required but not installed"
        print_status "Please install Homebrew first: https://brew.sh/"
        exit 1
    fi
    print_status "Homebrew found"
}

# Function to install system dependencies
install_dependencies() {
    print_step "Installing system dependencies..."
    
    # Update Homebrew
    brew update
    
    # Install dependencies
    brew install nginx postgresql@15
    
    print_success "System dependencies installed"
}

# Function to create system user
create_user() {
    print_step "Creating system user: $SERVICE_USER"
    
    if id "$SERVICE_USER" &>/dev/null; then
        print_status "User $SERVICE_USER already exists"
    else
        # Create system user
        dscl . -create /Users/$SERVICE_USER
        dscl . -create /Users/$SERVICE_USER UserShell /bin/false
        dscl . -create /Users/$SERVICE_USER RealName "Magnetico Service"
        dscl . -create /Users/$SERVICE_USER UniqueID 200
        dscl . -create /Users/$SERVICE_USER PrimaryGroupID 20
        dscl . -create /Users/$SERVICE_USER NFSHomeDirectory "$INSTALL_DIR"
        
        print_success "User $SERVICE_USER created"
    fi
}

# Function to create directories
create_directories() {
    print_step "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    # Set ownership
    chown -R "$SERVICE_USER:staff" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:staff" "$CONFIG_DIR"
    chown -R "$SERVICE_USER:staff" "$LOG_DIR"
    
    print_success "Directories created"
}

# Function to install binary
install_binary() {
    print_step "Installing Magnetico binary..."
    
    # Copy binary to installation directory
    if [ -f "magnetico" ]; then
        cp magnetico "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/magnetico"
        chown "$SERVICE_USER:staff" "$INSTALL_DIR/magnetico"
        print_success "Binary installed"
    else
        print_error "Binary file not found"
        exit 1
    fi
}

# Function to create launchd service
create_launchd_service() {
    print_step "Creating launchd service..."
    
    cat > "/Library/LaunchDaemons/$SERVICE_NAME.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/magnetico</string>
        <string>--config=$CONFIG_DIR/config.yml</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    
    <key>UserName</key>
    <string>$SERVICE_USER</string>
    
    <key>GroupName</key>
    <string>staff</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$LOG_DIR/magnetico.out.log</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/magnetico.err.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF
    
    # Set proper permissions
    chown root:wheel "/Library/LaunchDaemons/$SERVICE_NAME.plist"
    chmod 644 "/Library/LaunchDaemons/$SERVICE_NAME.plist"
    
    # Load the service
    launchctl load "/Library/LaunchDaemons/$SERVICE_NAME.plist"
    
    print_success "Launchd service created and loaded"
}

# Function to configure Nginx
configure_nginx() {
    print_step "Configuring Nginx reverse proxy..."
    
    # Create Nginx configuration directory
    mkdir -p "$(dirname "$NGINX_CONFIG")"
    
    # Create Nginx configuration
    cat > "$NGINX_CONFIG" << EOF
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=magnetico:10m rate=10r/s;
    limit_req zone=magnetico burst=20 nodelay;
    
    # Proxy settings
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Static files
    location /static/ {
        alias $INSTALL_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:8080/health;
    }
}
EOF
    
    # Test Nginx configuration
    if nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration is invalid"
        exit 1
    fi
    
    # Start and enable Nginx
    brew services start nginx
    
    print_success "Nginx configured and started"
}

# Function to configure macOS firewall
configure_firewall() {
    print_step "Configuring macOS firewall..."
    
    # Enable firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    
    # Allow Nginx
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/nginx
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /opt/homebrew/bin/nginx
    
    # Allow Magnetico
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$INSTALL_DIR/magnetico"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock "$INSTALL_DIR/magnetico"
    
    print_success "macOS firewall configured"
}

# Function to setup log rotation
setup_log_rotation() {
    print_step "Setting up log rotation..."
    
    cat > "/etc/newsyslog.d/magnetico.conf" << EOF
# Magnetico log rotation
$LOG_DIR/*.log $SERVICE_USER:staff 644 7 30 * J
EOF
    
    print_success "Log rotation configured"
}

# Function to create basic configuration
create_basic_config() {
    print_step "Creating basic configuration..."
    
    if [ ! -f "$CONFIG_DIR/config.yml" ]; then
        cat > "$CONFIG_DIR/config.yml" << EOF
# Magnetico Configuration
database:
  driver: postgresql
  host: localhost
  port: 5432
  name: magnetico
  user: magnetico
  password: ""

web:
  port: 8080
  host: "127.0.0.1"

dht:
  port: 6881
  bootstrap_nodes:
    - "router.bittorrent.com:6881"
    - "dht.transmissionbt.com:6881"

logging:
  level: info
  file: "$LOG_DIR/magnetico.log"
EOF
        
        chown "$SERVICE_USER:staff" "$CONFIG_DIR/config.yml"
        chmod 600 "$CONFIG_DIR/config.yml"
        
        print_success "Basic configuration created"
    else
        print_status "Configuration file already exists"
    fi
}

# Function to start services
start_services() {
    print_step "Starting services..."
    
    # Start Magnetico service
    launchctl start "$SERVICE_NAME"
    
    # Check service status
    if launchctl list | grep -q "$SERVICE_NAME"; then
        print_success "Magnetico service started successfully"
    else
        print_error "Failed to start Magnetico service"
        exit 1
    fi
}

# Function to show installation summary
show_summary() {
    print_step "Installation Summary"
    echo ""
    echo "Magnetico has been successfully installed on your macOS system!"
    echo ""
    echo "Installation Details:"
    echo "  - Installation directory: $INSTALL_DIR"
    echo "  - Configuration directory: $CONFIG_DIR"
    echo "  - Log directory: $LOG_DIR"
    echo "  - Service user: $SERVICE_USER"
    echo "  - Service name: $SERVICE_NAME"
    echo ""
    echo "Service Management:"
    echo "  - Start service: launchctl start $SERVICE_NAME"
    echo "  - Stop service: launchctl stop $SERVICE_NAME"
    echo "  - Check status: launchctl list | grep $SERVICE_NAME"
    echo "  - View logs: tail -f $LOG_DIR/magnetico.out.log"
    echo ""
    echo "Web Interface:"
    echo "  - URL: http://localhost"
    echo "  - Nginx configuration: $NGINX_CONFIG"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure your database connection in $CONFIG_DIR/config.yml"
    echo "  2. Restart the service: launchctl stop $SERVICE_NAME && launchctl start $SERVICE_NAME"
    echo "  3. Access the web interface at http://localhost"
    echo ""
    echo "For support, visit: https://github.com/datagram1/magnetico"
}

# Function to show help
show_help() {
    echo "Magnetico macOS Installation Script"
    echo "===================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --no-nginx     Skip Nginx configuration"
    echo "  --no-firewall  Skip firewall configuration"
    echo "  --no-service   Skip service creation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard installation"
    echo "  $0 --no-nginx        # Skip Nginx setup"
    echo "  $0 --no-firewall     # Skip firewall setup"
}

# Main installation function
main() {
    local no_nginx=false
    local no_firewall=false
    local no_service=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --no-nginx)
                no_nginx=true
                shift
                ;;
            --no-firewall)
                no_firewall=true
                shift
                ;;
            --no-service)
                no_service=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check Homebrew
    check_homebrew
    
    print_step "Starting Magnetico installation for macOS..."
    
    # Install dependencies
    install_dependencies
    
    # Create user and directories
    create_user
    create_directories
    
    # Install binary
    install_binary
    
    # Create basic configuration
    create_basic_config
    
    # Create launchd service
    if [ "$no_service" = false ]; then
        create_launchd_service
    fi
    
    # Configure Nginx
    if [ "$no_nginx" = false ]; then
        configure_nginx
    fi
    
    # Configure firewall
    if [ "$no_firewall" = false ]; then
        configure_firewall
    fi
    
    # Setup log rotation
    setup_log_rotation
    
    # Start services
    if [ "$no_service" = false ]; then
        start_services
    fi
    
    # Show summary
    show_summary
}

# Run main function
main "$@"
