#!/bin/bash
# Magnetico Universal Installer
# Main entry point for cross-platform installation

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
REPO_OWNER="datagram1"
REPO_NAME="magnetico"
INSTALL_DIR="/opt/magnetico"
CONFIG_DIR="/etc/magnetico"
LOG_DIR="/var/log/magnetico"
SERVICE_USER="magnetico"

# Function to print colored output
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    Magnetico DHT Search Engine${NC}"
    echo -e "${PURPLE}    Universal Installer v1.0.0${NC}"
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

# Function to detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "darwin";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unsupported";;
    esac
}

# Function to detect architecture
detect_architecture() {
    case "$(uname -m)" in
        x86_64)     echo "amd64";;
        aarch64)    echo "arm64";;
        arm64)      echo "arm64";;
        *)          echo "amd64";;
    esac
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check system requirements
check_requirements() {
    print_step "Checking system requirements..."
    
    # Check available disk space (need at least 2GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then  # 2GB in KB
        print_warning "Low disk space. At least 2GB recommended."
    fi
    
    # Check available memory
    if command -v free &> /dev/null; then
        AVAILABLE_MEM=$(free -m | awk 'NR==2{print $7}')
        if [ "$AVAILABLE_MEM" -lt 1024 ]; then  # 1GB
            print_warning "Low available memory. At least 1GB recommended."
        fi
    fi
    
    print_success "System requirements check completed"
}

# Function to download and install binary
install_binary() {
    local platform=$1
    local arch=$2
    
    print_step "Downloading Magnetico binary for $platform-$arch..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Download binary from GitHub releases
    local binary_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/magnetico-$platform-$arch"
    if [ "$platform" = "windows" ]; then
        binary_url="${binary_url}.exe"
    fi
    
    print_status "Downloading from: $binary_url"
    
    if curl -fsSL -o "$INSTALL_DIR/magnetico" "$binary_url"; then
        chmod +x "$INSTALL_DIR/magnetico"
        print_success "Binary downloaded and installed"
    else
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Verify binary works
    if "$INSTALL_DIR/magnetico" --version &> /dev/null; then
        print_success "Binary verification successful"
    else
        print_warning "Binary verification failed, but continuing..."
    fi
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
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR" 2>/dev/null || true
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR" 2>/dev/null || true
}

# Function to create directories
create_directories() {
    print_step "Creating directories..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$INSTALL_DIR"
    
    print_success "Directories created"
}

# Function to run platform-specific installer
run_platform_installer() {
    local platform=$1
    local arch=$2
    
    print_step "Running platform-specific installer for $platform-$arch..."
    
    # Look for platform-specific installer script
    local installer_script=""
    case $platform in
        "linux")
            installer_script="releases/linux-amd64/install.sh"
            ;;
        "darwin")
            installer_script="releases/darwin-amd64/install.sh"
            ;;
        "windows")
            installer_script="releases/windows-amd64/install.bat"
            ;;
    esac
    
    if [ -f "$installer_script" ]; then
        print_status "Running $installer_script"
        if [ "$platform" = "windows" ]; then
            cmd //c "$installer_script"
        else
            bash "$installer_script"
        fi
    else
        print_warning "Platform-specific installer not found, using generic installation"
        # Fallback to generic installation
        install_binary "$platform" "$arch"
        create_directories
        create_user
    fi
}

# Function to run configuration wizard
run_config_wizard() {
    print_step "Running configuration wizard..."
    
    if [ -f "scripts/config-wizard.sh" ]; then
        bash "scripts/config-wizard.sh"
    else
        print_warning "Configuration wizard not found, using default configuration"
        # Create basic config
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
  port: 80
  host: "0.0.0.0"

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
    fi
}

# Function to install service
install_service() {
    local platform=$1
    
    print_step "Installing system service..."
    
    case $platform in
        "linux")
            install_linux_service
            ;;
        "darwin")
            install_macos_service
            ;;
        "windows")
            install_windows_service
            ;;
    esac
}

# Function to install Linux systemd service
install_linux_service() {
    if [ -f "templates/linux-systemd.service" ]; then
        cp "templates/linux-systemd.service" "/etc/systemd/system/magnetico.service"
        systemctl daemon-reload
        systemctl enable magnetico
        print_success "Systemd service installed and enabled"
    else
        print_warning "Systemd service template not found"
    fi
}

# Function to install macOS launchd service
install_macos_service() {
    if [ -f "templates/macos-launchd.plist" ]; then
        cp "templates/macos-launchd.plist" "/Library/LaunchDaemons/com.magnetico.plist"
        launchctl load "/Library/LaunchDaemons/com.magnetico.plist"
        print_success "Launchd service installed and loaded"
    else
        print_warning "Launchd service template not found"
    fi
}

# Function to install Windows service
install_windows_service() {
    print_warning "Windows service installation not implemented yet"
    # TODO: Implement Windows service installation
}

# Function to start service
start_service() {
    local platform=$1
    
    print_step "Starting Magnetico service..."
    
    case $platform in
        "linux")
            systemctl start magnetico
            systemctl status magnetico --no-pager
            ;;
        "darwin")
            launchctl start com.magnetico
            ;;
        "windows")
            print_warning "Windows service start not implemented yet"
            ;;
    esac
    
    print_success "Service started"
}

# Function to show installation summary
show_summary() {
    local platform=$1
    
    print_header
    print_success "Magnetico installation completed successfully!"
    echo ""
    print_status "Installation Summary:"
    echo "  - Platform: $platform"
    echo "  - Installation directory: $INSTALL_DIR"
    echo "  - Configuration directory: $CONFIG_DIR"
    echo "  - Log directory: $LOG_DIR"
    echo "  - Service user: $SERVICE_USER"
    echo ""
    print_status "Next Steps:"
    echo "  1. Configure your database connection in $CONFIG_DIR/config.yml"
    echo "  2. Start the service: systemctl start magnetico"
    echo "  3. Access the web interface at http://localhost"
    echo ""
    print_status "Useful Commands:"
    echo "  - Check service status: systemctl status magnetico"
    echo "  - View logs: journalctl -u magnetico -f"
    echo "  - Restart service: systemctl restart magnetico"
    echo ""
    print_success "Thank you for installing Magnetico!"
}

# Function to show help
show_help() {
    echo "Magnetico Universal Installer"
    echo "============================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --force        Force installation even if already installed"
    echo "  --no-service   Skip service installation"
    echo "  --config-only  Only run configuration wizard"
    echo ""
    echo "Environment Variables:"
    echo "  INSTALL_DIR    Installation directory (default: /opt/magnetico)"
    echo "  CONFIG_DIR     Configuration directory (default: /etc/magnetico)"
    echo "  LOG_DIR        Log directory (default: /var/log/magnetico)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard installation"
    echo "  $0 --force           # Force reinstallation"
    echo "  $0 --config-only     # Only configure"
}

# Main installation function
main() {
    local force_install=false
    local no_service=false
    local config_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --force)
                force_install=true
                shift
                ;;
            --no-service)
                no_service=true
                shift
                ;;
            --config-only)
                config_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show header
    print_header
    
    # Check if running as root
    check_root
    
    # Detect platform and architecture
    PLATFORM=$(detect_platform)
    ARCH=$(detect_architecture)
    
    print_status "Detected platform: $PLATFORM"
    print_status "Detected architecture: $ARCH"
    
    if [ "$PLATFORM" = "unsupported" ]; then
        print_error "Unsupported platform: $(uname -s)"
        exit 1
    fi
    
    # Check if already installed
    if [ -f "$INSTALL_DIR/magnetico" ] && [ "$force_install" = false ]; then
        print_warning "Magnetico appears to be already installed at $INSTALL_DIR"
        read -p "Continue with installation? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Check system requirements
    check_requirements
    
    if [ "$config_only" = true ]; then
        run_config_wizard
        exit 0
    fi
    
    # Run platform-specific installer
    run_platform_installer "$PLATFORM" "$ARCH"
    
    # Run configuration wizard
    run_config_wizard
    
    # Install service (unless disabled)
    if [ "$no_service" = false ]; then
        install_service "$PLATFORM"
        start_service "$PLATFORM"
    fi
    
    # Show installation summary
    show_summary "$PLATFORM"
}

# Run main function
main "$@"
