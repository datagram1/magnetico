#!/bin/bash
# Docker-based build script for x86 platforms

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
    echo "Magnetico Docker Build Script"
    echo "============================="
    echo ""
    echo "Usage: $0 [OPTIONS] [PLATFORMS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build artifacts before building"
    echo "  -v, --verbose  Enable verbose output"
    echo ""
    echo "Platforms:"
    echo "  all            Build all x86 platforms (default)"
    echo "  darwin-amd64   Build for macOS x86_64"
    echo "  linux-amd64    Build for Linux x86_64"
    echo "  windows-amd64  Build for Windows x86_64"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build all x86 platforms"
    echo "  $0 darwin-amd64       # Build macOS x86_64 only"
    echo "  $0 -c all             # Clean and build all x86 platforms"
}

# Function to clean build artifacts
clean_builds() {
    print_step "Cleaning build artifacts..."
    
    # Remove existing binaries
    find "$RELEASES_DIR" -name "$PROJECT_NAME" -o -name "$PROJECT_NAME.exe" | xargs rm -f
    
    # Remove Docker images
    docker images | grep "$PROJECT_NAME-build" | awk '{print $3}' | xargs -r docker rmi -f
    
    # Remove build directories
    rm -rf build/
    
    print_success "Build artifacts cleaned"
}

# Function to build for a specific platform using Docker
build_platform_docker() {
    local platform=$1
    local verbose=$2
    
    local os=$(echo $platform | cut -d'-' -f1)
    local arch=$(echo $platform | cut -d'-' -f2)
    local output_dir="$RELEASES_DIR/$platform"
    local binary_name="$PROJECT_NAME"
    
    if [ "$os" = "windows" ]; then
        binary_name="${PROJECT_NAME}.exe"
    fi
    
    print_step "Building $platform using Docker..."
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Create platform-specific Dockerfile
    cat > "Dockerfile.$platform" << EOF
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
ENV GOOS=$os
ENV GOARCH=$arch
ENV CGO_ENABLED=0
RUN go build -ldflags '$LDFLAGS' -o $binary_name .

# Create final image
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/$binary_name .
EOF
    
    # Build Docker image
    local image_name="$PROJECT_NAME-build-$platform"
    if [ "$verbose" = true ]; then
        print_status "Building Docker image: $image_name"
        docker build -f "Dockerfile.$platform" -t "$image_name" .
    else
        docker build -f "Dockerfile.$platform" -t "$image_name" . > /dev/null
    fi
    
    # Extract binary from container
    local container_name="temp-$platform-$$"
    docker create --name "$container_name" "$image_name" > /dev/null
    docker cp "$container_name:/root/$binary_name" "$output_dir/"
    docker rm "$container_name" > /dev/null
    
    # Cleanup
    rm -f "Dockerfile.$platform"
    docker rmi "$image_name" > /dev/null
    
    # Verify binary was created
    if [ -f "$output_dir/$binary_name" ]; then
        local size=$(ls -lh "$output_dir/$binary_name" | awk '{print $5}')
        print_success "Built $platform binary: $output_dir/$binary_name ($size)"
    else
        print_error "Failed to build $platform binary"
        return 1
    fi
}

# Function to build all x86 platforms
build_all_x86() {
    local verbose=$1
    
    local platforms=("darwin-amd64" "linux-amd64" "windows-amd64")
    
    for platform in "${platforms[@]}"; do
        build_platform_docker "$platform" "$verbose"
    done
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
            all|darwin-amd64|linux-amd64|windows-amd64)
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
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not installed"
        exit 1
    fi
    
    # Clean if requested
    if [ "$clean" = true ]; then
        clean_builds
    fi
    
    print_step "Starting Docker build process..."
    print_status "Version: $VERSION"
    print_status "Build time: $BUILD_TIME"
    print_status "Platforms: ${platforms[*]}"
    
    # Build for each platform
    for platform in "${platforms[@]}"; do
        if [ "$platform" = "all" ]; then
            build_all_x86 "$verbose"
        else
            build_platform_docker "$platform" "$verbose"
        fi
    done
    
    # Copy installation scripts
    copy_install_scripts
    
    # Create release archives
    create_archives
    
    print_success "Docker build process completed successfully!"
    print_status "Binaries are available in the $RELEASES_DIR directory"
}

# Run main function
main "$@"
