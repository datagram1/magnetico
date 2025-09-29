#!/bin/bash
# Version management script for Magnetico
# Automatically increments version and updates build artifacts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VERSION_FILE="VERSION"
PROJECT_NAME="magnetico"
RELEASES_DIR="releases"

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

# Function to get current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0.0"
    fi
}

# Function to increment version
increment_version() {
    local current_version=$1
    local major=$(echo $current_version | cut -d'.' -f1)
    local minor=$(echo $current_version | cut -d'.' -f2)
    local patch=$(echo $current_version | cut -d'.' -f3)
    local build=$(echo $current_version | cut -d'.' -f4)
    
    # Increment build number
    build=$((build + 1))
    
    echo "${major}.${minor}.${patch}.${build}"
}

# Function to update version file
update_version_file() {
    local new_version=$1
    echo "$new_version" > "$VERSION_FILE"
    print_success "Updated version file: $new_version"
}

# Function to update README badge
update_readme_badge() {
    local version=$1
    local readme_file="README.md"
    
    if [ -f "$readme_file" ]; then
        # Create version badge
        local badge_url="https://img.shields.io/badge/version-${version}-blue.svg"
        local badge_markdown="![Version](https://img.shields.io/badge/version-${version}-blue.svg)"
        
        # Check if version badge already exists
        if grep -q "![Version]" "$readme_file"; then
            # Update existing badge
            sed -i.bak "s|![Version](https://img.shields.io/badge/version-[^-]*-blue\.svg)|${badge_markdown}|g" "$readme_file"
            rm -f "$readme_file.bak"
        else
            # Add new badge after the existing badges
            sed -i.bak "/\[!\[codecov\].*\]/a\\
${badge_markdown}" "$readme_file"
            rm -f "$readme_file.bak"
        fi
        
        print_success "Updated README version badge: $version"
    else
        print_warning "README.md not found, skipping badge update"
    fi
}

# Function to update build scripts
update_build_scripts() {
    local version=$1
    
    # Update build.sh
    if [ -f "build.sh" ]; then
        sed -i.bak "s/VERSION=\$(git describe --tags --always --dirty 2>\/dev\/null || echo \"dev\")/VERSION=\"${version}\"/g" "build.sh"
        rm -f "build.sh.bak"
        print_success "Updated build.sh with version: $version"
    fi
    
    # Update Makefile
    if [ -f "Makefile" ]; then
        sed -i.bak "s/VERSION := \$(shell git describe --tags --always --dirty 2>\/dev\/null || echo \"dev\")/VERSION := ${version}/g" "Makefile"
        rm -f "Makefile.bak"
        print_success "Updated Makefile with version: $version"
    fi
}

# Function to create git tag
create_git_tag() {
    local version=$1
    local tag_name="v${version}"
    
    if git tag -l | grep -q "^${tag_name}$"; then
        print_warning "Tag $tag_name already exists"
    else
        git tag -a "$tag_name" -m "Release version $version"
        print_success "Created git tag: $tag_name"
    fi
}

# Function to show help
show_help() {
    echo "Magnetico Version Management Script"
    echo "==================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --increment Increment version and update all files"
    echo "  -s, --show     Show current version"
    echo "  -t, --tag      Create git tag for current version"
    echo "  -v, --version  Set specific version (format: x.y.z.build)"
    echo ""
    echo "Examples:"
    echo "  $0 --increment              # Increment build number"
    echo "  $0 --show                   # Show current version"
    echo "  $0 --version 1.2.3.4        # Set specific version"
    echo "  $0 --tag                    # Create git tag"
}

# Function to show current version
show_version() {
    local current_version=$(get_current_version)
    print_status "Current version: $current_version"
}

# Function to set specific version
set_version() {
    local new_version=$1
    
    # Validate version format (x.y.z.build)
    if ! echo "$new_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        print_error "Invalid version format. Use: x.y.z.build (e.g., 1.0.0.1)"
        exit 1
    fi
    
    print_step "Setting version to: $new_version"
    update_version_file "$new_version"
    update_readme_badge "$new_version"
    update_build_scripts "$new_version"
    print_success "Version set to: $new_version"
}

# Function to increment version
increment_version_and_update() {
    local current_version=$(get_current_version)
    local new_version=$(increment_version "$current_version")
    
    print_step "Incrementing version from $current_version to $new_version"
    update_version_file "$new_version"
    update_readme_badge "$new_version"
    update_build_scripts "$new_version"
    print_success "Version incremented to: $new_version"
}

# Main function
main() {
    local action=""
    local version=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--increment)
                action="increment"
                shift
                ;;
            -s|--show)
                action="show"
                shift
                ;;
            -t|--tag)
                action="tag"
                shift
                ;;
            -v|--version)
                action="set"
                version="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action if none specified
    if [ -z "$action" ]; then
        action="increment"
    fi
    
    # Execute action
    case $action in
        "increment")
            increment_version_and_update
            ;;
        "show")
            show_version
            ;;
        "set")
            if [ -z "$version" ]; then
                print_error "Version required for --version option"
                exit 1
            fi
            set_version "$version"
            ;;
        "tag")
            local current_version=$(get_current_version)
            create_git_tag "$current_version"
            ;;
    esac
}

# Run main function
main "$@"
