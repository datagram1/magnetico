#!/bin/bash
# Local ARM build script for macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_NAME="magnetico"
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
RELEASES_DIR="releases"

# Build flags
LDFLAGS="-X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -s -w"

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

# Function to show help
show_help() {
    echo "Magnetico Local ARM Build Script"
    echo "================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build artifacts before building"
    echo "  -v, --verbose  Enable verbose output"
    echo ""
    echo "This script builds the macOS ARM64 binary locally using the system Go installation."
    echo ""
    echo "Examples:"
    echo "  $0                    # Build macOS ARM64 binary"
    echo "  $0 -c                 # Clean and build macOS ARM64 binary"
    echo "  $0 -v                 # Build with verbose output"
}

# Function to clean build artifacts
clean_builds() {
    print_step "Cleaning build artifacts..."
    
    # Remove existing binaries
    find "$RELEASES_DIR" -name "$PROJECT_NAME" -o -name "$PROJECT_NAME.exe" | xargs rm -f
    
    # Remove build directories
    rm -rf build/
    
    print_success "Build artifacts cleaned"
}

# Function to check system requirements
check_requirements() {
    print_step "Checking system requirements..."
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS systems"
        exit 1
    fi
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is required but not installed"
        print_status "Please install Go from https://golang.org/dl/"
        exit 1
    fi
    
    # Check Go version
    local go_version=$(go version | awk '{print $3}' | sed 's/go//')
    print_status "Go version: $go_version"
    
    # Check if we're on ARM64
    local arch=$(uname -m)
    if [ "$arch" != "arm64" ]; then
        print_warning "This script is optimized for ARM64 systems, but you're running on $arch"
        print_status "The build will still work, but it may not be optimal"
    fi
    
    print_success "System requirements check passed"
}

# Function to build macOS ARM64 binary
build_macos_arm64() {
    local verbose=$1
    
    local platform="macos-arm64"
    local output_dir="$RELEASES_DIR/$platform"
    local binary_name="$PROJECT_NAME"
    
    print_step "Building $platform binary locally..."
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Set environment variables
    export GOOS="darwin"
    export GOARCH="arm64"
    export CGO_ENABLED=0
    
    # Build command
    local build_cmd="go build -ldflags '$LDFLAGS' -o '$output_dir/$binary_name' ."
    
    if [ "$verbose" = true ]; then
        print_status "Build command: $build_cmd"
        print_status "GOOS: $GOOS"
        print_status "GOARCH: $GOARCH"
        print_status "CGO_ENABLED: $CGO_ENABLED"
    fi
    
    # Build the binary
    eval $build_cmd
    
    # Verify binary was created
    if [ -f "$output_dir/$binary_name" ]; then
        local size=$(ls -lh "$output_dir/$binary_name" | awk '{print $5}')
        print_success "Built $platform binary: $output_dir/$binary_name ($size)"
        
        # Show binary info
        if [ "$verbose" = true ]; then
            print_status "Binary information:"
            file "$output_dir/$binary_name"
            otool -hv "$output_dir/$binary_name" 2>/dev/null || true
        fi
    else
        print_error "Failed to build $platform binary"
        return 1
    fi
}

# Function to copy installation script
copy_install_script() {
    print_step "Copying installation script..."
    
    # Create macOS ARM64 install script (copy from darwin-amd64 and modify)
    if [ -f "install/universal/releases/darwin-amd64/install.sh" ]; then
        cp "install/universal/releases/darwin-amd64/install.sh" "$RELEASES_DIR/macos-arm64/install.sh"
        chmod +x "$RELEASES_DIR/macos-arm64/install.sh"
        
        # Update the script to reference macos-arm64
        sed -i '' 's/darwin-amd64/macos-arm64/g' "$RELEASES_DIR/macos-arm64/install.sh"
        
        print_success "Installation script copied and updated"
    else
        print_warning "Could not find darwin-amd64 install script to copy"
    fi
}

# Function to create release archive
create_archive() {
    print_step "Creating release archive..."
    
    local platform="macos-arm64"
    local archive_name="${PROJECT_NAME}-${VERSION}-${platform}"
    
    # Create TAR.GZ archive
    (cd "$RELEASES_DIR" && tar -czf "${archive_name}.tar.gz" "$platform")
    
    if [ -f "$RELEASES_DIR/${archive_name}.tar.gz" ]; then
        local size=$(ls -lh "$RELEASES_DIR/${archive_name}.tar.gz" | awk '{print $5}')
        print_success "Created ${archive_name}.tar.gz ($size)"
    else
        print_error "Failed to create archive"
        return 1
    fi
}

# Function to run tests
run_tests() {
    print_step "Running tests..."
    
    if go test ./...; then
        print_success "All tests passed"
    else
        print_warning "Some tests failed, but continuing with build"
    fi
}

# Main function
main() {
    local clean=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Clean if requested
    if [ "$clean" = true ]; then
        clean_builds
    fi
    
    # Check system requirements
    check_requirements
    
    print_step "Starting local ARM build process..."
    print_status "Version: $VERSION"
    print_status "Build time: $BUILD_TIME"
    print_status "Platform: macos-arm64"
    
    # Run tests
    run_tests
    
    # Build the binary
    build_macos_arm64 "$verbose"
    
    # Copy installation script
    copy_install_script
    
    # Create release archive
    create_archive
    
    print_success "Local ARM build process completed successfully!"
    print_status "Binary is available at: $RELEASES_DIR/macos-arm64/$PROJECT_NAME"
    print_status "Archive is available at: $RELEASES_DIR/${PROJECT_NAME}-${VERSION}-macos-arm64.tar.gz"
}

# Run main function
main "$@"
