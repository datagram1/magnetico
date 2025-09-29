#!/bin/bash
# Magnetico Update Script
# Handles updating Magnetico to the latest version

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
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
LATEST_RELEASE_URL="$REPO_URL/releases/latest/download"
INSTALL_DIR="/opt/magnetico"
CONFIG_DIR="/etc/magnetico"
SERVICE_NAME="magnetico"
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

# Function to detect architecture
detect_architecture() {
    case "$(uname -m)" in
        x86_64)     echo "amd64";;
        aarch64)    echo "arm64";;
        arm64)      echo "arm64";;
        *)          echo "amd64";;
    esac
}

# Function to get current version
get_current_version() {
    if [ -f "$INSTALL_DIR/magnetico" ]; then
        "$INSTALL_DIR/magnetico" --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Function to get latest version
get_latest_version() {
    local platform=$1
    local arch=$2
    
    # Try to get version from GitHub API
    if command -v curl &> /dev/null; then
        curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -oE '"tag_name": "v[0-9]+\.[0-9]+\.[0-9]+"' | cut -d'"' -f4
    elif command -v wget &> /dev/null; then
        wget -qO- "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -oE '"tag_name": "v[0-9]+\.[0-9]+\.[0-9]+"' | cut -d'"' -f4
    else
        echo "unknown"
    fi
}

# Function to check if update is needed
check_update_needed() {
    local current_version=$1
    local latest_version=$2
    
    if [ "$current_version" = "not_installed" ]; then
        return 1
    fi
    
    if [ "$current_version" = "unknown" ] || [ "$latest_version" = "unknown" ]; then
        return 1
    fi
    
    # Simple version comparison (assumes semantic versioning)
    if [ "$current_version" != "$latest_version" ]; then
        return 0
    else
        return 1
    fi
}

# Function to backup current installation
backup_current_installation() {
    local version=$1
    local backup_path="$BACKUP_DIR/magnetico-$version-$(date +%Y%m%d-%H%M%S)"
    
    print_step "Creating backup of current installation..."
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup binary
    if [ -f "$INSTALL_DIR/magnetico" ]; then
        cp "$INSTALL_DIR/magnetico" "$backup_path/"
    fi
    
    # Backup configuration
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        cp "$CONFIG_DIR/config.yml" "$backup_path/"
    fi
    
    # Backup static files
    if [ -d "$INSTALL_DIR/static" ]; then
        cp -r "$INSTALL_DIR/static" "$backup_path/"
    fi
    
    print_success "Backup created: $backup_path"
    echo "$backup_path"
}

# Function to download new version
download_new_version() {
    local platform=$1
    local arch=$2
    local version=$3
    local temp_dir="/tmp/magnetico-update"
    
    print_step "Downloading Magnetico $version for $platform-$arch..."
    
    # Create temporary directory
    mkdir -p "$temp_dir"
    
    # Determine binary URL
    local binary_url="$LATEST_RELEASE_URL/magnetico-$platform-$arch"
    if [ "$platform" = "windows" ]; then
        binary_url="${binary_url}.exe"
    fi
    
    # Download binary
    if command -v curl &> /dev/null; then
        curl -fsSL -o "$temp_dir/magnetico" "$binary_url"
    elif command -v wget &> /dev/null; then
        wget -qO "$temp_dir/magnetico" "$binary_url"
    else
        print_error "Neither curl nor wget is available"
        exit 1
    fi
    
    # Make binary executable
    chmod +x "$temp_dir/magnetico"
    
    print_success "Downloaded new version"
    echo "$temp_dir/magnetico"
}

# Function to stop service
stop_service() {
    local platform=$1
    
    print_step "Stopping Magnetico service..."
    
    case $platform in
        "linux")
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                systemctl stop "$SERVICE_NAME"
                print_success "Service stopped"
            else
                print_status "Service was not running"
            fi
            ;;
        "darwin")
            if launchctl list | grep -q "com.magnetico"; then
                launchctl stop com.magnetico
                print_success "Service stopped"
            else
                print_status "Service was not running"
            fi
            ;;
        "windows")
            if sc query "$SERVICE_NAME" | grep -q "RUNNING"; then
                net stop "$SERVICE_NAME"
                print_success "Service stopped"
            else
                print_status "Service was not running"
            fi
            ;;
    esac
}

# Function to start service
start_service() {
    local platform=$1
    
    print_step "Starting Magnetico service..."
    
    case $platform in
        "linux")
            systemctl start "$SERVICE_NAME"
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                print_success "Service started"
            else
                print_error "Failed to start service"
                return 1
            fi
            ;;
        "darwin")
            launchctl start com.magnetico
            if launchctl list | grep -q "com.magnetico"; then
                print_success "Service started"
            else
                print_error "Failed to start service"
                return 1
            fi
            ;;
        "windows")
            net start "$SERVICE_NAME"
            if sc query "$SERVICE_NAME" | grep -q "RUNNING"; then
                print_success "Service started"
            else
                print_error "Failed to start service"
                return 1
            fi
            ;;
    esac
}

# Function to install new binary
install_new_binary() {
    local new_binary_path=$1
    local backup_path=$2
    
    print_step "Installing new binary..."
    
    # Stop service
    local platform=$(detect_platform)
    stop_service "$platform"
    
    # Create backup
    local current_version=$(get_current_version)
    if [ "$current_version" != "not_installed" ] && [ "$current_version" != "unknown" ]; then
        backup_current_installation "$current_version"
    fi
    
    # Install new binary
    cp "$new_binary_path" "$INSTALL_DIR/magnetico"
    chmod +x "$INSTALL_DIR/magnetico"
    
    # Start service
    if start_service "$platform"; then
        print_success "Update completed successfully"
    else
        print_error "Update completed but failed to start service"
        print_warning "You may need to start the service manually"
    fi
    
    # Cleanup
    rm -rf "$(dirname "$new_binary_path")"
}

# Function to rollback
rollback() {
    local backup_path=$1
    
    print_step "Rolling back to previous version..."
    
    # Stop service
    local platform=$(detect_platform)
    stop_service "$platform"
    
    # Restore binary
    if [ -f "$backup_path/magnetico" ]; then
        cp "$backup_path/magnetico" "$INSTALL_DIR/magnetico"
        chmod +x "$INSTALL_DIR/magnetico"
    fi
    
    # Restore configuration
    if [ -f "$backup_path/config.yml" ]; then
        cp "$backup_path/config.yml" "$CONFIG_DIR/config.yml"
    fi
    
    # Start service
    if start_service "$platform"; then
        print_success "Rollback completed successfully"
    else
        print_error "Rollback completed but failed to start service"
    fi
}

# Function to show help
show_help() {
    echo "Magnetico Update Script"
    echo "======================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --check        Check for updates without installing"
    echo "  --force        Force update even if already up to date"
    echo "  --rollback     Rollback to previous version"
    echo "  --version      Show current and latest versions"
    echo ""
    echo "Examples:"
    echo "  $0                    # Check and install updates"
    echo "  $0 --check           # Check for updates only"
    echo "  $0 --force           # Force update"
    echo "  $0 --rollback        # Rollback to previous version"
}

# Function to show version information
show_version_info() {
    local current_version=$(get_current_version)
    local platform=$(detect_platform)
    local arch=$(detect_architecture)
    local latest_version=$(get_latest_version "$platform" "$arch")
    
    echo "Version Information"
    echo "=================="
    echo "Current version: $current_version"
    echo "Latest version:  $latest_version"
    echo "Platform:        $platform-$arch"
    echo ""
    
    if check_update_needed "$current_version" "$latest_version"; then
        echo "Update available: Yes"
    else
        echo "Update available: No"
    fi
}

# Main update function
main() {
    local check_only=false
    local force_update=false
    local rollback_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --check)
                check_only=true
                shift
                ;;
            --force)
                force_update=true
                shift
                ;;
            --rollback)
                rollback_mode=true
                shift
                ;;
            --version)
                show_version_info
                exit 0
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
        print_error "Magnetico is not installed at $INSTALL_DIR"
        print_status "Please install Magnetico first using the installation script"
        exit 1
    fi
    
    # Detect platform and architecture
    local platform=$(detect_platform)
    local arch=$(detect_architecture)
    
    if [ "$platform" = "unsupported" ]; then
        print_error "Unsupported platform: $(uname -s)"
        exit 1
    fi
    
    # Get version information
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version "$platform" "$arch")
    
    print_status "Current version: $current_version"
    print_status "Latest version:  $latest_version"
    print_status "Platform:        $platform-$arch"
    echo ""
    
    # Handle rollback mode
    if [ "$rollback_mode" = true ]; then
        # Find latest backup
        local latest_backup=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -n1)
        if [ -z "$latest_backup" ]; then
            print_error "No backup found for rollback"
            exit 1
        fi
        
        print_warning "Rolling back to: $latest_backup"
        read -p "Continue with rollback? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            rollback "$BACKUP_DIR/$latest_backup"
        else
            print_status "Rollback cancelled"
        fi
        exit 0
    fi
    
    # Check if update is needed
    if [ "$force_update" = false ] && ! check_update_needed "$current_version" "$latest_version"; then
        print_success "Magnetico is already up to date"
        exit 0
    fi
    
    # Check only mode
    if [ "$check_only" = true ]; then
        if check_update_needed "$current_version" "$latest_version"; then
            print_warning "Update available: $current_version -> $latest_version"
            exit 1
        else
            print_success "No updates available"
            exit 0
        fi
    fi
    
    # Confirm update
    print_warning "Update available: $current_version -> $latest_version"
    read -p "Continue with update? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Update cancelled"
        exit 0
    fi
    
    # Download and install new version
    local new_binary_path=$(download_new_version "$platform" "$arch" "$latest_version")
    install_new_binary "$new_binary_path"
    
    print_success "Magnetico updated successfully!"
    print_status "Current version: $(get_current_version)"
}

# Run main function
main "$@"

