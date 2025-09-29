#!/bin/bash
# Linux/Ubuntu Installation Script for Magnetico

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
SERVICE_NAME="magnetico"
NGINX_CONFIG="/etc/nginx/sites-available/magnetico"
NGINX_ENABLED="/etc/nginx/sites-enabled/magnetico"

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

# Function to install system dependencies
install_dependencies() {
    local distro=$(detect_distro)
    
    print_step "Installing system dependencies..."
    
    case $distro in
        "ubuntu"|"debian")
            # Update package list
            apt-get update
            
            # Install dependencies
            apt-get install -y \
                curl \
                wget \
                nginx \
                postgresql-client \
                ufw \
                logrotate \
                systemd \
                sudo
            ;;
        "centos"|"rhel"|"fedora")
            # Install dependencies
            dnf install -y \
                curl \
                wget \
                nginx \
                postgresql \
                firewalld \
                logrotate \
                systemd \
                sudo
            ;;
        *)
            print_error "Unsupported Linux distribution: $distro"
            exit 1
            ;;
    esac
    
    print_success "System dependencies installed"
}

# Function to create system user
create_user() {
    print_step "Creating system user: $SERVICE_USER"
    
    if id "$SERVICE_USER" &>/dev/null; then
        print_status "User $SERVICE_USER already exists"
    else
        useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" --create-home "$SERVICE_USER"
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
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    
    print_success "Directories created"
}

# Function to download and install binary
install_binary() {
    print_step "Installing Magnetico binary..."
    
    # Copy binary to installation directory
    if [ -f "magnetico" ]; then
        cp magnetico "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/magnetico"
        chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/magnetico"
        print_success "Binary installed"
    else
        print_error "Binary file not found"
        exit 1
    fi
}

# Function to create systemd service
create_systemd_service() {
    print_step "Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Magnetico DHT Search Engine
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/magnetico --config=$CONFIG_DIR/config.yml
User=$SERVICE_USER
Group=$SERVICE_USER
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=magnetico

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    print_success "Systemd service created and enabled"
}

# Function to configure Nginx
configure_nginx() {
    print_step "Configuring Nginx reverse proxy..."
    
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
    
    # Enable site
    ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"
    
    # Test Nginx configuration
    if nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration is invalid"
        exit 1
    fi
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    print_success "Nginx configured and started"
}

# Function to configure firewall
configure_firewall() {
    local distro=$(detect_distro)
    
    print_step "Configuring firewall..."
    
    case $distro in
        "ubuntu"|"debian")
            # Configure UFW
            ufw --force enable
            ufw allow ssh
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw allow 6881/udp  # DHT port
            print_success "UFW firewall configured"
            ;;
        "centos"|"rhel"|"fedora")
            # Configure firewalld
            systemctl start firewalld
            systemctl enable firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=6881/udp
            firewall-cmd --reload
            print_success "Firewalld configured"
            ;;
    esac
}

# Function to setup log rotation
setup_log_rotation() {
    print_step "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/$SERVICE_NAME" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
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
        
        chown "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/config.yml"
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
    systemctl start "$SERVICE_NAME"
    
    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Magnetico service started successfully"
    else
        print_error "Failed to start Magnetico service"
        systemctl status "$SERVICE_NAME" --no-pager
        exit 1
    fi
}

# Function to show installation summary
show_summary() {
    print_step "Installation Summary"
    echo ""
    echo "Magnetico has been successfully installed on your Linux system!"
    echo ""
    echo "Installation Details:"
    echo "  - Installation directory: $INSTALL_DIR"
    echo "  - Configuration directory: $CONFIG_DIR"
    echo "  - Log directory: $LOG_DIR"
    echo "  - Service user: $SERVICE_USER"
    echo "  - Service name: $SERVICE_NAME"
    echo ""
    echo "Service Management:"
    echo "  - Start service: systemctl start $SERVICE_NAME"
    echo "  - Stop service: systemctl stop $SERVICE_NAME"
    echo "  - Restart service: systemctl restart $SERVICE_NAME"
    echo "  - Check status: systemctl status $SERVICE_NAME"
    echo "  - View logs: journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "Web Interface:"
    echo "  - URL: http://localhost"
    echo "  - Nginx configuration: $NGINX_CONFIG"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure your database connection in $CONFIG_DIR/config.yml"
    echo "  2. Restart the service: systemctl restart $SERVICE_NAME"
    echo "  3. Access the web interface at http://localhost"
    echo ""
    echo "For support, visit: https://github.com/datagram1/magnetico"
}

# Function to show help
show_help() {
    echo "Magnetico Linux Installation Script"
    echo "==================================="
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
    
    print_step "Starting Magnetico installation for Linux..."
    
    # Install dependencies
    install_dependencies
    
    # Create user and directories
    create_user
    create_directories
    
    # Install binary
    install_binary
    
    # Create basic configuration
    create_basic_config
    
    # Create systemd service
    if [ "$no_service" = false ]; then
        create_systemd_service
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
