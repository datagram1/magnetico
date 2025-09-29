#!/bin/bash
# Release creation script for Magnetico

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_OWNER="datagram1"
REPO_NAME="magnetico"
RELEASES_DIR="../releases"
TEMP_DIR="/tmp/magnetico-release"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first."
        print_status "Visit: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI. Please run 'gh auth login'"
        exit 1
    fi
    
    # Check if releases directory exists
    if [ ! -d "$RELEASES_DIR" ]; then
        print_error "Releases directory not found: $RELEASES_DIR"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get version from user
get_version() {
    if [ -z "$VERSION" ]; then
        read -p "Enter version (e.g., v1.0.0): " VERSION
    fi
    
    if [ -z "$VERSION" ]; then
        print_error "Version cannot be empty"
        exit 1
    fi
    
    # Validate version format
    if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_warning "Version format should be vX.Y.Z (e.g., v1.0.0)"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_status "Using version: $VERSION"
}

# Function to create release notes
create_release_notes() {
    local version=$1
    local notes_file="$TEMP_DIR/RELEASE_NOTES.md"
    
    print_status "Creating release notes..."
    
    cat > "$notes_file" << EOF
# Magnetico $version

## What's New

- Initial release of Magnetico DHT search engine
- Cross-platform support (Linux, Windows, macOS)
- Interactive installation wizard
- PostgreSQL database support
- Web interface for searching torrents
- DHT crawler for discovering new torrents

## Installation

### Quick Install
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/install.sh | bash
\`\`\`

### Manual Installation
1. Download the appropriate binary for your platform
2. Extract and run the installation script
3. Follow the interactive configuration wizard

## Supported Platforms

- **Linux**: AMD64, ARM64
- **Windows**: AMD64
- **macOS**: AMD64 (Intel), ARM64 (Apple Silicon)

## Requirements

- PostgreSQL 12+ (local or remote)
- 2GB+ RAM recommended
- 10GB+ disk space for database

## Documentation

- [Installation Guide](https://github.com/$REPO_OWNER/$REPO_NAME/blob/main/README.md)
- [Configuration](https://github.com/$REPO_OWNER/$REPO_NAME/blob/main/doc/config.example.yml)

## Checksums

EOF

    # Add checksums for all binaries
    for platform_dir in "$RELEASES_DIR"/*; do
        if [ -d "$platform_dir" ]; then
            platform=$(basename "$platform_dir")
            for binary in "$platform_dir"/*.sha256; do
                if [ -f "$binary" ]; then
                    binary_name=$(basename "$binary" .sha256)
                    checksum=$(cat "$binary")
                    echo "- **$platform/$binary_name**: \`$checksum\`" >> "$notes_file"
                fi
            done
        fi
    done
    
    print_success "Release notes created"
}

# Function to create release package
create_release_package() {
    local version=$1
    local package_dir="$TEMP_DIR/magnetico-$version"
    
    print_status "Creating release package..."
    
    # Create package directory
    mkdir -p "$package_dir"
    
    # Copy binaries and checksums
    cp -r "$RELEASES_DIR"/* "$package_dir/"
    
    # Copy installation scripts
    cp -r "../install" "$package_dir/"
    
    # Copy documentation
    cp -r "../../doc" "$package_dir/" 2>/dev/null || true
    cp "../../README.md" "$package_dir/" 2>/dev/null || true
    
    # Create installation script
    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
# Magnetico Installation Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "darwin";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unsupported";;
    esac
}

detect_architecture() {
    case "$(uname -m)" in
        x86_64)     echo "amd64";;
        aarch64)    echo "arm64";;
        arm64)      echo "arm64";;
        *)          echo "amd64";;
    esac
}

# Main installation
main() {
    print_status "Magnetico Installation Script"
    print_status "=============================="
    
    PLATFORM=$(detect_platform)
    ARCH=$(detect_architecture)
    
    print_status "Detected platform: $PLATFORM"
    print_status "Detected architecture: $ARCH"
    
    if [ "$PLATFORM" = "unsupported" ]; then
        print_error "Unsupported platform"
        exit 1
    fi
    
    # Find appropriate installer
    INSTALLER_DIR="releases/$PLATFORM-$ARCH"
    if [ ! -d "$INSTALLER_DIR" ]; then
        print_error "No installer found for $PLATFORM-$ARCH"
        exit 1
    fi
    
    # Run platform-specific installer
    if [ -f "$INSTALLER_DIR/install.sh" ]; then
        print_status "Running Linux/macOS installer..."
        bash "$INSTALLER_DIR/install.sh"
    elif [ -f "$INSTALLER_DIR/install.bat" ]; then
        print_status "Running Windows installer..."
        cmd //c "$INSTALLER_DIR/install.bat"
    else
        print_error "No installer script found"
        exit 1
    fi
}

main "$@"
EOF

    chmod +x "$package_dir/install.sh"
    
    # Create tarball
    cd "$TEMP_DIR"
    tar -czf "magnetico-$version.tar.gz" "magnetico-$version"
    cd - > /dev/null
    
    print_success "Release package created: $TEMP_DIR/magnetico-$version.tar.gz"
}

# Function to create GitHub release
create_github_release() {
    local version=$1
    local notes_file="$TEMP_DIR/RELEASE_NOTES.md"
    local package_file="$TEMP_DIR/magnetico-$version.tar.gz"
    
    print_status "Creating GitHub release..."
    
    # Create the release
    if gh release create "$VERSION" \
        --title "Magnetico $VERSION" \
        --notes-file "$notes_file" \
        "$package_file"; then
        print_success "GitHub release created: $VERSION"
    else
        print_error "Failed to create GitHub release"
        exit 1
    fi
    
    # Upload individual binaries
    print_status "Uploading individual binaries..."
    for platform_dir in "$RELEASES_DIR"/*; do
        if [ -d "$platform_dir" ]; then
            platform=$(basename "$platform_dir")
            for binary in "$platform_dir"/*; do
                if [ -f "$binary" ] && [[ ! "$binary" =~ \.sha256$ ]]; then
                    binary_name=$(basename "$binary")
                    print_status "Uploading $platform/$binary_name..."
                    gh release upload "$VERSION" "$binary" --clobber
                fi
            done
        fi
    done
    
    print_success "All binaries uploaded"
}

# Function to clean up
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    print_success "Cleanup completed"
}

# Function to show help
show_help() {
    echo "Magnetico Release Creation Script"
    echo "================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Set version string"
    echo "  --dry-run      Show what would be done without creating release"
    echo ""
    echo "Environment Variables:"
    echo "  VERSION        Version string for the release"
    echo ""
    echo "Examples:"
    echo "  $0 --version v1.0.0"
    echo "  VERSION=v1.0.0 $0"
}

# Main script logic
main() {
    local dry_run=false
    
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
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Check prerequisites
    check_prerequisites
    
    # Get version
    get_version
    
    if [ "$dry_run" = true ]; then
        print_status "DRY RUN - No release will be created"
        print_status "Version: $VERSION"
        print_status "Release notes would be created"
        print_status "Package would be created"
        print_status "GitHub release would be created"
        cleanup
        exit 0
    fi
    
    # Create release notes
    create_release_notes "$VERSION"
    
    # Create release package
    create_release_package "$VERSION"
    
    # Create GitHub release
    create_github_release "$VERSION"
    
    # Cleanup
    cleanup
    
    print_success "Release $VERSION created successfully!"
    print_status "Visit: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$VERSION"
}

# Run main function
main "$@"
