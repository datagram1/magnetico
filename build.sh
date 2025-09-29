#!/bin/bash
# Cross-platform build script for Magnetico

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
    echo "Magnetico Cross-Platform Build Script"
    echo "====================================="
    echo ""
    echo "Usage: $0 [OPTIONS] [PLATFORMS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build artifacts before building"
    echo "  -v, --verbose  Enable verbose output"
    echo "  --docker       Use Docker for x86 builds"
    echo "  --local        Use local Go for all builds"
    echo ""
    echo "Platforms:"
    echo "  all            Build all platforms (default)"
    echo "  darwin-amd64   Build for macOS x86_64"
    echo "  darwin-arm64   Build for macOS ARM64"
    echo "  linux-amd64    Build for Linux x86_64"
    echo "  windows-amd64  Build for Windows x86_64"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build all platforms using Docker for x86"
    echo "  $0 --local                   # Build all platforms locally"
    echo "  $0 --docker darwin-amd64     # Build macOS x86_64 using Docker"
    echo "  $0 --local darwin-arm64      # Build macOS ARM64 locally"
    echo "  $0 -c all                    # Clean and build all platforms"
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

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local use_docker=$2
    local verbose=$3
    
    local os=$(echo $platform | cut -d'-' -f1)
    local arch=$(echo $platform | cut -d'-' -f2)
    local output_dir="$RELEASES_DIR/$platform"
    local binary_name="$PROJECT_NAME"
    
    if [ "$os" = "windows" ]; then
        binary_name="${PROJECT_NAME}.exe"
    fi
    
    print_step "Building for $platform..."
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Set environment variables
    export GOOS="$os"
    export GOARCH="$arch"
    export CGO_ENABLED=0
    
    # Build command
    local build_cmd="go build -ldflags '$LDFLAGS' -o '$output_dir/$binary_name' ."
    
    if [ "$use_docker" = true ] && [ "$arch" = "amd64" ]; then
        # Use Docker for x86 builds
        print_status "Using Docker for $platform build..."
        
        # Create temporary Dockerfile
        cat > Dockerfile.build << EOF
FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod download
RUN $build_cmd

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/$output_dir/$binary_name .
EOF
        
        # Build using Docker
        docker build -f Dockerfile.build -t "$PROJECT_NAME-build-$platform" .
        
        # Extract binary
        docker create --name temp-container "$PROJECT_NAME-build-$platform"
        docker cp temp-container:/root/$binary_name "$output_dir/"
        docker rm temp-container
        
        # Cleanup
        rm -f Dockerfile.build
        docker rmi "$PROJECT_NAME-build-$platform"
        
    else
        # Use local Go
        print_status "Using local Go for $platform build..."
        
        if [ "$verbose" = true ]; then
            echo "Build command: $build_cmd"
        fi
        
        eval $build_cmd
    fi
    
    # Verify binary was created
    if [ -f "$output_dir/$binary_name" ]; then
        local size=$(ls -lh "$output_dir/$binary_name" | awk '{print $5}')
        print_success "Built $platform binary: $output_dir/$binary_name ($size)"
    else
        print_error "Failed to build $platform binary"
        return 1
    fi
}

# Function to copy installation scripts
copy_install_scripts() {
    print_step "Copying installation scripts..."
    
    # Copy platform-specific install scripts
    if [ -f "install/universal/releases/darwin-amd64/install.sh" ]; then
        cp "install/universal/releases/darwin-amd64/install.sh" "$RELEASES_DIR/darwin-amd64/"
        chmod +x "$RELEASES_DIR/darwin-amd64/install.sh"
    fi
    
    if [ -f "install/universal/releases/linux-amd64/install.sh" ]; then
        cp "install/universal/releases/linux-amd64/install.sh" "$RELEASES_DIR/linux-amd64/"
        chmod +x "$RELEASES_DIR/linux-amd64/install.sh"
    fi
    
    if [ -f "install/universal/releases/windows-amd64/install.bat" ]; then
        cp "install/universal/releases/windows-amd64/install.bat" "$RELEASES_DIR/windows-amd64/"
    fi
    
    # Create macOS ARM64 install script (copy from darwin-amd64 and modify)
    if [ -f "install/universal/releases/darwin-amd64/install.sh" ]; then
        cp "install/universal/releases/darwin-amd64/install.sh" "$RELEASES_DIR/macos-arm64/install.sh"
        chmod +x "$RELEASES_DIR/macos-arm64/install.sh"
        # Update the script to reference macos-arm64
        sed -i '' 's/darwin-amd64/macos-arm64/g' "$RELEASES_DIR/macos-arm64/install.sh"
    fi
    
    print_success "Installation scripts copied"
}

# Function to create release archives
create_archives() {
    print_step "Creating release archives..."
    
    for platform_dir in "$RELEASES_DIR"/*; do
        if [ -d "$platform_dir" ]; then
            local platform=$(basename "$platform_dir")
            local archive_name="${PROJECT_NAME}-${VERSION}-${platform}"
            
            # Create archive
            if [ "$platform" = "windows-amd64" ]; then
                # Windows uses ZIP
                (cd "$RELEASES_DIR" && zip -r "${archive_name}.zip" "$platform")
                print_success "Created ${archive_name}.zip"
            else
                # Unix uses TAR.GZ
                (cd "$RELEASES_DIR" && tar -czf "${archive_name}.tar.gz" "$platform")
                print_success "Created ${archive_name}.tar.gz"
            fi
        fi
    done
}

# Main function
main() {
    local clean=false
    local verbose=false
    local use_docker=true
    local platforms=("all")
    
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
            --docker)
                use_docker=true
                shift
                ;;
            --local)
                use_docker=false
                shift
                ;;
            all|darwin-amd64|darwin-arm64|linux-amd64|windows-amd64)
                platforms=("$1")
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
    
    # Determine platforms to build
    if [ "${platforms[0]}" = "all" ]; then
        if [ "$use_docker" = true ]; then
            platforms=("darwin-amd64" "linux-amd64" "windows-amd64")
        else
            platforms=("darwin-amd64" "darwin-arm64" "linux-amd64" "windows-amd64")
        fi
    fi
    
    # Check if Docker is available when needed
    if [ "$use_docker" = true ]; then
        if ! command -v docker &> /dev/null; then
            print_error "Docker is required but not installed"
            exit 1
        fi
    fi
    
    # Check if Go is available
    if ! command -v go &> /dev/null; then
        print_error "Go is required but not installed"
        exit 1
    fi
    
    print_step "Starting build process..."
    print_status "Version: $VERSION"
    print_status "Build time: $BUILD_TIME"
    print_status "Platforms: ${platforms[*]}"
    print_status "Use Docker: $use_docker"
    
    # Build for each platform
    for platform in "${platforms[@]}"; do
        build_platform "$platform" "$use_docker" "$verbose"
    done
    
    # Copy installation scripts
    copy_install_scripts
    
    # Create release archives
    create_archives
    
    print_success "Build process completed successfully!"
    print_status "Binaries are available in the $RELEASES_DIR directory"
}

# Run main function
main "$@"
