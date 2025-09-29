#!/bin/bash
# Magnetico Uninstall Script
# Completely removes Magnetico and all its components

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
BACKUP_DIR="/opt/magnetico/backups"

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

# Function to detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "darwin";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unsupported";;
    esac
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

# Function to stop and disable service
stop_and_disable_service() {
    local platform=$1
    
    print_step "Stopping and disabling Magnetico service..."
    
    case $platform in
        "linux")
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                systemctl stop "$SERVICE_NAME"
                print_status "Service stopped"
            fi
            
            if systemctl is-enabled --quiet "$SERVICE_NAME"; then
                systemctl disable "$SERVICE_NAME"
                print_status "Service disabled"
            fi
            ;;
        "darwin")
            if launchctl list | grep -q "com.magnetico"; then
                launchctl stop com.magnetico
                launchctl unload "/Library/LaunchDaemons/com.magnetico.plist"
                print_status "Service stopped and unloaded"
            fi
            ;;
        "windows")
            if sc query "$SERVICE_NAME" | grep -q "RUNNING"; then
                net stop "$SERVICE_NAME"
                print_status "Service stopped"
            fi
            
            if sc query "$SERVICE_NAME" | grep -q "SERVICE_NAME"; then
                sc delete "$SERVICE_NAME"
                print_status "Service deleted"
            fi
            ;;
    esac
}

# Function to remove service files
remove_service_files() {
    local platform=$1
    
    print_step "Removing service files..."
    
    case $platform in
        "linux")
            if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
                rm -f "/etc/systemd/system/$SERVICE_NAME.service"
                systemctl daemon-reload
                print_status "Systemd service file removed"
            fi
            ;;
        "darwin")
            if [ -f "/Library/LaunchDaemons/com.magnetico.plist" ]; then
                rm -f "/Library/LaunchDaemons/com.magnetico.plist"
                print_status "Launchd service file removed"
            fi
            ;;
        "windows")
            # Windows service files are removed by sc delete
            print_status "Windows service removed"
            ;;
    esac
}

# Function to remove Nginx configuration
remove_nginx_config() {
    local platform=$1
    
    print_step "Removing Nginx configuration..."
    
    case $platform in
        "linux")
            if [ -f "$NGINX_CONFIG" ]; then
                rm -f "$NGINX_CONFIG"
                print_status "Nginx configuration removed"
            fi
            
            if [ -L "$NGINX_ENABLED" ]; then
                rm -f "$NGINX_ENABLED"
                print_status "Nginx site disabled"
            fi
            
            # Test and reload Nginx
            if command -v nginx &> /dev/null; then
                if nginx -t; then
                    systemctl reload nginx
                    print_status "Nginx reloaded"
                else
                    print_warning "Nginx configuration test failed"
                fi
            fi
            ;;
        "darwin")
            local nginx_config="/opt/homebrew/etc/nginx/servers/magnetico.conf"
            if [ -f "$nginx_config" ]; then
                rm -f "$nginx_config"
                print_status "Nginx configuration removed"
            fi
            
            # Reload Nginx
            if command -v nginx &> /dev/null; then
                if nginx -t; then
                    brew services restart nginx
                    print_status "Nginx restarted"
                else
                    print_warning "Nginx configuration test failed"
                fi
            fi
            ;;
        "windows")
            # Windows Nginx configuration removal
            local nginx_dir=""
            for /f "tokens=*" %%i in ('where nginx') do set nginx_dir=%%i
            set nginx_dir=!nginx_dir:~0,-10!
            
            if exist "!nginx_dir!\conf\magnetico.conf" (
                del "!nginx_dir!\conf\magnetico.conf"
                echo Nginx configuration removed
            )
            ;;
    esac
}

# Function to remove firewall rules
remove_firewall_rules() {
    local platform=$1
    
    print_step "Removing firewall rules..."
    
    case $platform in
        "linux")
            local distro=$(detect_distro)
            case $distro in
                "ubuntu"|"debian")
                    # Remove UFW rules
                    if command -v ufw &> /dev/null; then
                        ufw --force delete allow 80/tcp 2>/dev/null || true
                        ufw --force delete allow 443/tcp 2>/dev/null || true
                        ufw --force delete allow 6881/udp 2>/dev/null || true
                        print_status "UFW rules removed"
                    fi
                    ;;
                "centos"|"rhel"|"fedora")
                    # Remove firewalld rules
                    if command -v firewall-cmd &> /dev/null; then
                        firewall-cmd --permanent --remove-service=http 2>/dev/null || true
                        firewall-cmd --permanent --remove-service=https 2>/dev/null || true
                        firewall-cmd --permanent --remove-port=6881/udp 2>/dev/null || true
                        firewall-cmd --reload 2>/dev/null || true
                        print_status "Firewalld rules removed"
                    fi
                    ;;
            esac
            ;;
        "darwin")
            # Remove macOS firewall rules
            if [ -f "$INSTALL_DIR/magnetico" ]; then
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --remove "$INSTALL_DIR/magnetico" 2>/dev/null || true
                print_status "macOS firewall rules removed"
            fi
            ;;
        "windows")
            # Remove Windows Firewall rules
            netsh advfirewall firewall delete rule name="Magnetico HTTP" 2>nul || true
            netsh advfirewall firewall delete rule name="Magnetico HTTPS" 2>nul || true
            netsh advfirewall firewall delete rule name="Magnetico DHT" 2>nul || true
            echo Windows Firewall rules removed
            ;;
    esac
}

# Function to remove log rotation
remove_log_rotation() {
    local platform=$1
    
    print_step "Removing log rotation configuration..."
    
    case $platform in
        "linux")
            if [ -f "/etc/logrotate.d/$SERVICE_NAME" ]; then
                rm -f "/etc/logrotate.d/$SERVICE_NAME"
                print_status "Log rotation configuration removed"
            fi
            ;;
        "darwin")
            if [ -f "/etc/newsyslog.d/magnetico.conf" ]; then
                rm -f "/etc/newsyslog.d/magnetico.conf"
                print_status "Log rotation configuration removed"
            fi
            ;;
        "windows")
            # Windows log rotation is handled by the service
            print_status "Windows log rotation removed"
            ;;
    esac
}

# Function to remove system user
remove_system_user() {
    local platform=$1
    
    print_step "Removing system user: $SERVICE_USER"
    
    case $platform in
        "linux")
            if id "$SERVICE_USER" &>/dev/null; then
                userdel "$SERVICE_USER" 2>/dev/null || true
                print_status "System user removed"
            else
                print_status "System user does not exist"
            fi
            ;;
        "darwin")
            if id "$SERVICE_USER" &>/dev/null; then
                dscl . -delete /Users/$SERVICE_USER 2>/dev/null || true
                print_status "System user removed"
            else
                print_status "System user does not exist"
            fi
            ;;
        "windows")
            # Windows service user is handled by the service
            print_status "Windows service user removed"
            ;;
    esac
}

# Function to remove directories and files
remove_directories_and_files() {
    local platform=$1
    local keep_backups=$2
    
    print_step "Removing directories and files..."
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        if [ "$keep_backups" = true ] && [ -d "$BACKUP_DIR" ]; then
            # Keep backups but remove everything else
            find "$INSTALL_DIR" -type f ! -path "$BACKUP_DIR/*" -delete 2>/dev/null || true
            find "$INSTALL_DIR" -type d ! -path "$BACKUP_DIR" ! -path "$INSTALL_DIR" -empty -delete 2>/dev/null || true
            print_status "Installation directory cleaned (backups preserved)"
        else
            rm -rf "$INSTALL_DIR"
            print_status "Installation directory removed"
        fi
    fi
    
    # Remove configuration directory
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        print_status "Configuration directory removed"
    fi
    
    # Remove log directory
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        print_status "Log directory removed"
    fi
}

# Function to remove dependencies
remove_dependencies() {
    local platform=$1
    local remove_all=$2
    
    if [ "$remove_all" = false ]; then
        print_status "Skipping dependency removal (use --remove-deps to remove)"
        return
    fi
    
    print_step "Removing dependencies..."
    
    case $platform in
        "linux")
            local distro=$(detect_distro)
            case $distro in
                "ubuntu"|"debian")
                    # Remove packages
                    apt-get remove -y nginx postgresql-client 2>/dev/null || true
                    print_status "Dependencies removed"
                    ;;
                "centos"|"rhel"|"fedora")
                    # Remove packages
                    dnf remove -y nginx postgresql 2>/dev/null || true
                    print_status "Dependencies removed"
                    ;;
            esac
            ;;
        "darwin")
            # Remove Homebrew packages
            if command -v brew &> /dev/null; then
                brew uninstall nginx postgresql@15 2>/dev/null || true
                print_status "Dependencies removed"
            fi
            ;;
        "windows")
            # Remove Chocolatey packages
            if command -v choco &> /dev/null; then
                choco uninstall -y nginx postgresql 2>/dev/null || true
                echo Dependencies removed
            fi
            ;;
    esac
}

# Function to show help
show_help() {
    echo "Magnetico Uninstall Script"
    echo "========================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  --keep-backups     Keep backup files"
    echo "  --remove-deps      Remove installed dependencies"
    echo "  --force            Force uninstall without confirmation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard uninstall"
    echo "  $0 --keep-backups     # Keep backup files"
    echo "  $0 --remove-deps      # Remove dependencies too"
    echo "  $0 --force            # Force uninstall"
}

# Main uninstall function
main() {
    local keep_backups=false
    local remove_deps=false
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --keep-backups)
                keep_backups=true
                shift
                ;;
            --remove-deps)
                remove_deps=true
                shift
                ;;
            --force)
                force=true
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
    
    # Check if Magnetico is installed
    if [ ! -f "$INSTALL_DIR/magnetico" ]; then
        print_warning "Magnetico does not appear to be installed at $INSTALL_DIR"
        print_status "Nothing to uninstall"
        exit 0
    fi
    
    # Detect platform
    local platform=$(detect_platform)
    if [ "$platform" = "unsupported" ]; then
        print_error "Unsupported platform: $(uname -s)"
        exit 1
    fi
    
    # Show uninstall summary
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    Magnetico Uninstaller${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
    print_status "Platform: $platform"
    print_status "Installation directory: $INSTALL_DIR"
    print_status "Configuration directory: $CONFIG_DIR"
    print_status "Log directory: $LOG_DIR"
    print_status "Keep backups: $keep_backups"
    print_status "Remove dependencies: $remove_deps"
    echo ""
    
    # Confirm uninstall
    if [ "$force" = false ]; then
        print_warning "This will completely remove Magnetico and all its components."
        if [ "$remove_deps" = true ]; then
            print_warning "Dependencies will also be removed."
        fi
        if [ "$keep_backups" = false ]; then
            print_warning "Backup files will be removed."
        fi
        echo ""
        read -p "Continue with uninstall? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            print_status "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Stop and disable service
    stop_and_disable_service "$platform"
    
    # Remove service files
    remove_service_files "$platform"
    
    # Remove Nginx configuration
    remove_nginx_config "$platform"
    
    # Remove firewall rules
    remove_firewall_rules "$platform"
    
    # Remove log rotation
    remove_log_rotation "$platform"
    
    # Remove system user
    remove_system_user "$platform"
    
    # Remove directories and files
    remove_directories_and_files "$platform" "$keep_backups"
    
    # Remove dependencies
    remove_dependencies "$platform" "$remove_deps"
    
    print_success "Magnetico has been completely uninstalled!"
    
    if [ "$keep_backups" = true ]; then
        print_status "Backup files preserved at: $BACKUP_DIR"
    fi
    
    print_status "Thank you for using Magnetico!"
}

# Run main function
main "$@"

