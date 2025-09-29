#!/bin/bash
# Windows-specific build script for Magnetico

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
OUTPUT_DIR="../releases/windows-amd64"

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

# Function to build for Windows
build_windows() {
    print_status "Building Magnetico for Windows..."
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | cut -d' ' -f3 | sed 's/go//')
    print_status "Using Go version: ${GO_VERSION}"
    
    # Set environment for Windows build
    export GOOS=windows
    export GOARCH=amd64
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Build the binary
    print_status "Compiling magnetico for Windows..."
    if go build ${BUILD_FLAGS} -o "${OUTPUT_DIR}/magnetico.exe" .; then
        print_success "Built magnetico.exe for Windows"
        
        # Create checksum
        cd "${OUTPUT_DIR}"
        sha256sum "magnetico.exe" > "magnetico.exe.sha256"
        cd - > /dev/null
        
        print_success "Created checksum for magnetico.exe"
        
        # Show file info
        print_status "Binary information:"
        ls -la "${OUTPUT_DIR}/magnetico.exe"
        file "${OUTPUT_DIR}/magnetico.exe"
    else
        print_error "Failed to build for Windows"
        exit 1
    fi
}

# Function to show help
show_help() {
    echo "Magnetico Windows Build Script"
    echo "=============================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Set version string (default: dev)"
    echo ""
    echo "Environment Variables:"
    echo "  VERSION        Version string for the build"
    echo ""
    echo "Examples:"
    echo "  $0 --version v1.0.0"
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
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action: build for Windows
    build_windows
}

# Run main function
main "$@"
