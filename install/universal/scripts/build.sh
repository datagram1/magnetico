#!/bin/bash
# Cross-platform build script for Magnetico

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
OUTPUT_DIR="../releases"

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

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local arch=$2
    local output_name=$3
    
    print_status "Building for ${platform}/${arch}..."
    
    # Set environment variables for cross-compilation
    case $platform in
        "linux")
            export GOOS=linux
            export GOARCH=$arch
            ;;
        "windows")
            export GOOS=windows
            export GOARCH=$arch
            output_name="${output_name}.exe"
            ;;
        "darwin")
            export GOOS=darwin
            export GOARCH=$arch
            ;;
        *)
            print_error "Unsupported platform: $platform"
            return 1
            ;;
    esac
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}/${platform}-${arch}"
    
    # Build the binary
    print_status "Compiling magnetico for ${platform}/${arch}..."
    if go build ${BUILD_FLAGS} -o "${OUTPUT_DIR}/${platform}-${arch}/${output_name}" .; then
        print_success "Built ${output_name} for ${platform}/${arch}"
        
        # Create checksum
        cd "${OUTPUT_DIR}/${platform}-${arch}"
        sha256sum "${output_name}" > "${output_name}.sha256"
        cd - > /dev/null
        
        print_success "Created checksum for ${output_name}"
    else
        print_error "Failed to build for ${platform}/${arch}"
        return 1
    fi
}

# Function to build all platforms
build_all() {
    print_status "Starting cross-platform build for version ${VERSION}..."
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | cut -d' ' -f3 | sed 's/go//')
    print_status "Using Go version: ${GO_VERSION}"
    
    # Build for all supported platforms
    build_platform "linux" "amd64" "magnetico"
    build_platform "linux" "arm64" "magnetico"
    build_platform "windows" "amd64" "magnetico"
    build_platform "darwin" "amd64" "magnetico"
    build_platform "darwin" "arm64" "magnetico"
    
    print_success "All builds completed successfully!"
    
    # List built binaries
    print_status "Built binaries:"
    find "${OUTPUT_DIR}" -name "magnetico*" -type f | sort
}

# Function to clean build artifacts
clean() {
    print_status "Cleaning build artifacts..."
    rm -rf "${OUTPUT_DIR}"
    print_success "Build artifacts cleaned"
}

# Function to show help
show_help() {
    echo "Magnetico Cross-Platform Build Script"
    echo "====================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Set version string (default: dev)"
    echo "  -c, --clean    Clean build artifacts"
    echo "  -a, --all      Build all platforms (default)"
    echo "  --linux        Build for Linux only"
    echo "  --windows      Build for Windows only"
    echo "  --darwin       Build for macOS only"
    echo ""
    echo "Environment Variables:"
    echo "  VERSION        Version string for the build"
    echo "  OUTPUT_DIR     Output directory for binaries"
    echo ""
    echo "Examples:"
    echo "  $0 --version v1.0.0"
    echo "  $0 --linux"
    echo "  $0 --clean"
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
            -c|--clean)
                clean
                exit 0
                ;;
            -a|--all)
                build_all
                exit 0
                ;;
            --linux)
                build_platform "linux" "amd64" "magnetico"
                build_platform "linux" "arm64" "magnetico"
                exit 0
                ;;
            --windows)
                build_platform "windows" "amd64" "magnetico"
                exit 0
                ;;
            --darwin)
                build_platform "darwin" "amd64" "magnetico"
                build_platform "darwin" "arm64" "magnetico"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action: build all
    build_all
}

# Run main function
main "$@"
