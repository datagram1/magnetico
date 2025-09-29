# Magnetico Makefile
# Cross-platform build system

.PHONY: help build build-all build-docker build-local-arm build-docker-preconfigured clean test install

# Configuration
PROJECT_NAME := magnetico
VERSION := $(shell cat VERSION 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
RELEASES_DIR := releases

# Build flags
LDFLAGS := -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -s -w

# Default target
.DEFAULT_GOAL := help

# Help target
help: ## Show this help message
	@echo "Magnetico Build System"
	@echo "====================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make build-all          # Build all platforms using Docker for x86"
	@echo "  make build-local-arm    # Build macOS ARM64 locally"
	@echo "  make build-docker       # Build x86 platforms using Docker"
	@echo "  make build-docker-preconfigured # Build pre-configured Docker image"
	@echo "  make clean              # Clean build artifacts"

# Version management
version: ## Show current version
	@./build/version.sh --show

version-increment: ## Increment version
	@./build/version.sh --increment

version-tag: ## Create git tag for current version
	@./build/version.sh --tag

# Build all platforms
build-all: ## Build all platforms (Docker for x86, local for ARM)
	@echo "Building all platforms..."
	@./build/build.sh --docker

# Build using Docker for x86 platforms
build-docker: ## Build x86 platforms using Docker
	@echo "Building x86 platforms using Docker..."
	@./build/build-docker.sh

# Build macOS ARM64 locally
build-local-arm: ## Build macOS ARM64 locally
	@echo "Building macOS ARM64 locally..."
	@./build/build-local-arm.sh

# Build pre-configured Docker image
build-docker-preconfigured: ## Build pre-configured Docker image with SQLite
	@echo "Building pre-configured Docker image..."
	@./build/build-docker-preconfigured.sh

# Build specific platform
build-darwin-amd64: ## Build macOS x86_64
	@echo "Building macOS x86_64..."
	@./build/build-docker.sh darwin-amd64

build-darwin-arm64: ## Build macOS ARM64
	@echo "Building macOS ARM64..."
	@./build/build-local-arm.sh

build-linux-amd64: ## Build Linux x86_64
	@echo "Building Linux x86_64..."
	@./build/build-docker.sh linux-amd64

build-windows-amd64: ## Build Windows x86_64
	@echo "Building Windows x86_64..."
	@./build/build-docker.sh windows-amd64

# Clean build artifacts
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf $(RELEASES_DIR)/*/$(PROJECT_NAME)
	@rm -rf $(RELEASES_DIR)/*/$(PROJECT_NAME).exe
	@rm -rf build/
	@docker images | grep $(PROJECT_NAME)-build | awk '{print $$3}' | xargs -r docker rmi -f 2>/dev/null || true
	@echo "Build artifacts cleaned"

# Run tests
test: ## Run tests
	@echo "Running tests..."
	@go test ./...

# Install dependencies
install-deps: ## Install Go dependencies
	@echo "Installing Go dependencies..."
	@go mod download
	@go mod tidy

# Build for current platform (development)
build-dev: ## Build for current platform (development)
	@echo "Building for current platform..."
	@go build -ldflags '$(LDFLAGS)' -o $(PROJECT_NAME) .

# Run the application
run: build-dev ## Build and run the application
	@echo "Running $(PROJECT_NAME)..."
	@./$(PROJECT_NAME)

# Create release archives
archive: build-all ## Create release archives
	@echo "Creating release archives..."
	@for platform_dir in $(RELEASES_DIR)/*; do \
		if [ -d "$$platform_dir" ]; then \
			platform=$$(basename "$$platform_dir"); \
			archive_name="$(PROJECT_NAME)-$(VERSION)-$$platform"; \
			if [ "$$platform" = "windows-amd64" ]; then \
				(cd $(RELEASES_DIR) && zip -r "$$archive_name.zip" "$$platform"); \
				echo "Created $$archive_name.zip"; \
			else \
				(cd $(RELEASES_DIR) && tar -czf "$$archive_name.tar.gz" "$$platform"); \
				echo "Created $$archive_name.tar.gz"; \
			fi; \
		fi; \
	done

# Show build information
info: ## Show build information
	@echo "Build Information"
	@echo "================="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Go Version: $(shell go version)"
	@echo "OS: $(shell uname -s)"
	@echo "Architecture: $(shell uname -m)"
	@echo "Docker Available: $(shell command -v docker >/dev/null 2>&1 && echo "Yes" || echo "No")"

# Check system requirements
check: ## Check system requirements
	@echo "Checking system requirements..."
	@command -v go >/dev/null 2>&1 || (echo "ERROR: Go is not installed" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "WARNING: Docker is not installed (required for x86 builds)" && exit 0)
	@echo "System requirements check passed"

# Development setup
dev-setup: install-deps check ## Set up development environment
	@echo "Development environment setup complete"

# Full build and test
ci: clean test build-all ## Full CI pipeline (clean, test, build all)
	@echo "CI pipeline completed successfully"
