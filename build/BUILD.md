# Magnetico Build System

This document describes the cross-platform build system for Magnetico, which supports building binaries for multiple operating systems and architectures.

## Supported Platforms

- **macOS x86_64** (darwin-amd64) - Built using Docker
- **macOS ARM64** (macos-arm64) - Built locally on ARM64 systems
- **Linux x86_64** (linux-amd64) - Built using Docker
- **Windows x86_64** (windows-amd64) - Built using Docker

## Build Scripts

### Main Build Script (`build.sh`)

The main build script provides a unified interface for building all platforms:

```bash
# Build all platforms using Docker for x86
./build.sh

# Build all platforms locally (requires Go on all target platforms)
./build.sh --local

# Build specific platform
./build.sh darwin-amd64

# Clean and build
./build.sh -c all

# Verbose output
./build.sh -v
```

### Docker Build Script (`build-docker.sh`)

Builds x86 platforms using Docker containers:

```bash
# Build all x86 platforms
./build-docker.sh

# Build specific platform
./build-docker.sh darwin-amd64

# Clean and build
./build-docker.sh -c all
```

### Local ARM Build Script (`build-local-arm.sh`)

Builds macOS ARM64 binary locally:

```bash
# Build macOS ARM64
./build-local-arm.sh

# Clean and build
./build-local-arm.sh -c

# Verbose output
./build-local-arm.sh -v
```

### Pre-configured Docker Build Script (`build-docker-preconfigured.sh`)

Builds a Docker image with SQLite database pre-configured:

```bash
# Build pre-configured Docker image
./build-docker-preconfigured.sh
```

This creates a Docker image that includes:
- Pre-configured SQLite database setup
- Default environment variables
- Health checks
- Simplified deployment (no separate database container needed)

## Makefile Targets

The Makefile provides convenient targets for common build operations:

```bash
# Show help
make help

# Build all platforms
make build-all

# Build specific platform
make build-darwin-amd64
make build-darwin-arm64
make build-linux-amd64
make build-windows-amd64

# Build using Docker
make build-docker

# Build locally for ARM
make build-local-arm

# Build pre-configured Docker image
make build-docker-preconfigured

# Clean build artifacts
make clean

# Run tests
make test

# Development build
make build-dev

# Run the application
make run

# Create release archives
make archive

# Show build information
make info

# Check system requirements
make check

# Full CI pipeline
make ci
```

## Requirements

### For Docker Builds (x86 platforms)
- Docker
- Go (for local ARM builds)

### For Local Builds
- Go 1.25 or later
- Platform-specific build tools

## Build Process

1. **Dependency Resolution**: Downloads Go modules
2. **Cross-Compilation**: Builds binaries for target platforms
3. **Installation Scripts**: Copies platform-specific install scripts
4. **Archive Creation**: Creates compressed archives for distribution

## Output Structure

```
releases/
├── darwin-amd64/
│   ├── magnetico
│   └── install.sh
├── macos-arm64/
│   ├── magnetico
│   └── install.sh
├── linux-amd64/
│   ├── magnetico
│   └── install.sh
├── windows-amd64/
│   ├── magnetico.exe
│   └── install.bat
└── *.tar.gz / *.zip (archives)
```

## GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/build.yml`) that:

1. Runs tests on all platforms
2. Builds binaries for all supported platforms
3. Creates release archives
4. Publishes releases when tags are pushed

## Development

### Local Development

```bash
# Set up development environment
make dev-setup

# Build and run locally
make run

# Run tests
make test
```

### Adding New Platforms

1. Add the platform to the build scripts
2. Create platform-specific installation script
3. Update the GitHub Actions workflow
4. Update this documentation

## Troubleshooting

### Docker Issues
- Ensure Docker is running
- Check Docker has sufficient resources
- Try cleaning Docker images: `docker system prune`

### Go Issues
- Ensure Go 1.25+ is installed
- Check `GOPATH` and `GOROOT` environment variables
- Verify Go modules are properly configured

### Permission Issues
- Ensure build scripts are executable: `chmod +x *.sh`
- Check file permissions in the releases directory

## Contributing

When contributing to the build system:

1. Test builds on multiple platforms
2. Update documentation
3. Ensure CI/CD pipeline passes
4. Follow the existing code style and patterns
