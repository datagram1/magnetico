#!/bin/bash
# Magnetico Universal Installer
# Main entry point for cross-platform installation
# Usage: curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | bash

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download and execute installer
download_and_run_installer() {
    local platform=$1
    local arch=$2
    
    print_step "Downloading platform-specific installer for $platform-$arch..."
    
    # Determine installer URL based on platform
    local installer_url=""
    case $platform in
        "linux"|"darwin")
            installer_url="$LATEST_RELEASE_URL/install-${platform}-${arch}.sh"
            ;;
        "windows")
            installer_url="$LATEST_RELEASE_URL/install-${platform}-${arch}.bat"
            ;;
    esac
    
    print_status "Downloading from: $installer_url"
    
    # Download and execute the installer
    if command_exists curl; then
        if [ "$platform" = "windows" ]; then
            print_warning "Windows installation detected."
            print_status "Please run the following command in PowerShell or Command Prompt:"
            echo ""
            echo -e "${BLUE}powershell -Command \"Invoke-WebRequest -Uri '$installer_url' -OutFile 'install.bat'; .\\install.bat\"${NC}"
            echo ""
            print_status "Or download and run the installer manually from:"
            echo -e "${BLUE}$installer_url${NC}"
        else
            curl -fsSL "$installer_url" | bash
        fi
    elif command_exists wget; then
        if [ "$platform" = "windows" ]; then
            print_warning "Windows installation detected."
            print_status "Please run the following command in PowerShell or Command Prompt:"
            echo ""
            echo -e "${BLUE}powershell -Command \"Invoke-WebRequest -Uri '$installer_url' -OutFile 'install.bat'; .\\install.bat\"${NC}"
            echo ""
            print_status "Or download and run the installer manually from:"
            echo -e "${BLUE}$installer_url${NC}"
        else
            wget -qO- "$installer_url" | bash
        fi
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
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
    echo "  --version      Show version information"
    echo ""
    echo "Installation:"
    echo "  curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/install.sh | bash"
    echo ""
    echo "Supported Platforms:"
    echo "  - Linux (AMD64, ARM64)"
    echo "  - macOS (AMD64, ARM64)"
    echo "  - Windows (AMD64)"
    echo ""
    echo "For more information, visit: $REPO_URL"
}

# Function to show version
show_version() {
    echo "Magnetico Universal Installer v1.0.0"
    echo "Repository: $REPO_URL"
    echo "Latest Release: $LATEST_RELEASE_URL"
}

# Main installation logic
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
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
    
    # Detect platform and architecture
    PLATFORM=$(detect_platform)
    ARCH=$(detect_architecture)
    
    print_status "Detected platform: $PLATFORM"
    print_status "Detected architecture: $ARCH"
    echo ""
    
    # Check if platform is supported
    if [ "$PLATFORM" = "unsupported" ]; then
        print_error "Unsupported platform: $(uname -s)"
        print_status "Supported platforms: Linux, macOS, Windows"
        exit 1
    fi
    
    # Download and run the appropriate installer
    download_and_run_installer "$PLATFORM" "$ARCH"
}

# Run main function
main "$@"
