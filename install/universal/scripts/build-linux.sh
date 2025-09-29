#!/bin/bash
# Linux-specific build script for Magnetico

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Build configuration
VERSION=${VERSION:-"dev"}
BUILD_FLAGS="-tags fts5 -ldflags \"-s -w -X main.version=${VERSION}\""
OUTPUT_DIR="../releases/linux-amd64"

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

# Function to build for Linux
build_linux() {
    print_status "Building Magnetico for Linux..."
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | cut -d' ' -f3 | sed 's/go//')
    print_status "Using Go version: ${GO_VERSION}"
    
    # Set environment for Linux build
    export GOOS=linux
    export GOARCH=amd64
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Build the binary
    print_status "Compiling magnetico for Linux..."
    if go build ${BUILD_FLAGS} -o "${OUTPUT_DIR}/magnetico" .; then
        print_success "Built magnetico for Linux"
        
        # Create checksum
        cd "${OUTPUT_DIR}"
        sha256sum "magnetico" > "magnetico.sha256"
        cd - > /dev/null
        
        print_success "Created checksum for magnetico"
        
        # Show file info
        print_status "Binary information:"
        ls -la "${OUTPUT_DIR}/magnetico"
        file "${OUTPUT_DIR}/magnetico"
    else
        print_error "Failed to build for Linux"
        exit 1
    fi
}

# Function to build for Linux ARM64
build_linux_arm64() {
    print_status "Building Magnetico for Linux ARM64..."
    
    # Set environment for Linux ARM64 build
    export GOOS=linux
    export GOARCH=arm64
    OUTPUT_DIR="../releases/linux-arm64"
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Build the binary
    print_status "Compiling magnetico for Linux ARM64..."
    if go build ${BUILD_FLAGS} -o "${OUTPUT_DIR}/magnetico" .; then
        print_success "Built magnetico for Linux ARM64"
        
        # Create checksum
        cd "${OUTPUT_DIR}"
        sha256sum "magnetico" > "magnetico.sha256"
        cd - > /dev/null
        
        print_success "Created checksum for magnetico"
        
        # Show file info
        print_status "Binary information:"
        ls -la "${OUTPUT_DIR}/magnetico"
        file "${OUTPUT_DIR}/magnetico"
    else
        print_error "Failed to build for Linux ARM64"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "Magnetico Linux Build Script"
    echo "==========================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Set version string (default: dev)"
    echo "  --arm64        Build for ARM64 architecture"
    echo "  --amd64        Build for AMD64 architecture (default)"
    echo ""
    echo "Environment Variables:"
    echo "  VERSION        Version string for the build"
    echo ""
    echo "Examples:"
    echo "  $0 --version v1.0.0"
    echo "  $0 --arm64"
}

# Main script logic
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            --arm64)
                build_linux_arm64
                exit 0
                ;;
            --amd64)
                build_linux
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action: build for AMD64
    build_linux
}

# Run main function
main "$@"
