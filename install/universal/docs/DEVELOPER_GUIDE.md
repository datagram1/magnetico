# Magnetico Developer Guide

This guide is for developers who want to contribute to Magnetico, understand its architecture, or extend its functionality.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Development Environment](#development-environment)
4. [Building from Source](#building-from-source)
5. [Code Structure](#code-structure)
6. [API Documentation](#api-documentation)
7. [Database Schema](#database-schema)
8. [Testing](#testing)
9. [Contributing](#contributing)
10. [Release Process](#release-process)

## Getting Started

### Prerequisites

- Go 1.21 or later
- PostgreSQL 12+ or SQLite3
- Git
- Make (optional)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/datagram1/magnetico.git
cd magnetico

# Install dependencies
go mod download

# Build the project
go build -tags fts5 -ldflags "-s -w" -o magnetico .

# Run tests
go test ./...

# Start development server
./magnetico --config=config.example.yml
```

## Architecture Overview

Magnetico follows a modular architecture with the following main components:

### Core Components

1. **DHT Crawler**: Discovers torrents from the BitTorrent DHT network
2. **Database Layer**: Stores and indexes torrent metadata
3. **Web Interface**: Provides HTTP API and web UI
4. **Configuration System**: Manages application settings
5. **Logging System**: Handles structured logging

### Data Flow

```
DHT Network → Crawler → Database → Web Interface → Users
     ↑           ↓         ↓           ↓
   Bootstrap   Metadata  Indexing   Search/API
   Nodes       Storage   Queries    Responses
```

### Key Design Principles

- **Modularity**: Components are loosely coupled
- **Scalability**: Designed to handle large datasets
- **Performance**: Optimized for fast search and indexing
- **Reliability**: Robust error handling and recovery
- **Security**: Secure by default with configurable options

## Development Environment

### Local Development Setup

1. **Install Go**:
   ```bash
   # Ubuntu/Debian
   sudo apt install golang-go
   
   # macOS
   brew install go
   
   # Or download from https://golang.org/dl/
   ```

2. **Install PostgreSQL**:
   ```bash
   # Ubuntu/Debian
   sudo apt install postgresql postgresql-contrib
   
   # macOS
   brew install postgresql@15
   
   # Start PostgreSQL
   sudo systemctl start postgresql  # Linux
   brew services start postgresql@15  # macOS
   ```

3. **Set up Development Database**:
   ```bash
   sudo -u postgres createdb magnetico_dev
   sudo -u postgres psql -d magnetico_dev -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
   ```

4. **Clone and Setup**:
   ```bash
   git clone https://github.com/datagram1/magnetico.git
   cd magnetico
   go mod download
   ```

### IDE Setup

#### VS Code

Install recommended extensions:
- Go (by Google)
- GitLens
- YAML
- Docker

Create `.vscode/settings.json`:
```json
{
    "go.testFlags": ["-v"],
    "go.buildTags": "fts5",
    "go.lintTool": "golangci-lint",
    "go.formatTool": "goimports"
}
```

#### GoLand/IntelliJ

1. Install Go plugin
2. Configure Go SDK
3. Set build tags: `fts5`
4. Configure database connection for debugging

### Environment Variables

Create `.env` file for development:
```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=magnetico_dev
DB_USER=postgres
DB_PASSWORD=

# Web Interface
WEB_HOST=127.0.0.1
WEB_PORT=8080

# DHT
DHT_PORT=6881

# Logging
LOG_LEVEL=debug
LOG_FILE=./magnetico.log
```

## Building from Source

### Basic Build

```bash
# Build for current platform
go build -tags fts5 -ldflags "-s -w" -o magnetico .

# Build with version info
go build -tags fts5 -ldflags "-s -w -X main.version=$(git describe --tags)" -o magnetico .
```

### Cross-Platform Builds

```bash
# Linux AMD64
GOOS=linux GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-linux-amd64 .

# Windows AMD64
GOOS=windows GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-windows-amd64.exe .

# macOS AMD64
GOOS=darwin GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-darwin-amd64 .

# macOS ARM64
GOOS=darwin GOARCH=arm64 go build -tags fts5 -ldflags "-s -w" -o magnetico-darwin-arm64 .
```

### Using Make

```bash
# Build all platforms
make build-all

# Build specific platform
make build-linux
make build-windows
make build-macos

# Clean build artifacts
make clean

# Run tests
make test

# Run linting
make lint
```

## Code Structure

```
magnetico/
├── main.go                 # Application entry point
├── go.mod                  # Go module definition
├── go.sum                  # Go module checksums
├── config.example.yml      # Example configuration
├── bencode/                # Bencode encoding/decoding
├── dht/                    # DHT network implementation
│   └── mainline/          # Mainline DHT protocol
├── metadata/               # Torrent metadata handling
├── metainfo/               # Torrent metainfo parsing
├── persistence/            # Database abstraction layer
├── web/                    # Web interface and API
├── types/                  # Type definitions
├── stats/                  # Statistics and metrics
├── opflags/                # Command line flags
├── install/                # Installation scripts
└── docs/                   # Documentation
```

### Key Packages

#### `bencode/`
Handles Bencode encoding/decoding for BitTorrent protocol.

**Key files:**
- `encode.go`: Bencode encoding
- `decode.go`: Bencode decoding
- `scanner.go`: Bencode tokenization

#### `dht/mainline/`
Implements the Mainline DHT protocol for discovering torrents.

**Key files:**
- `protocol.go`: DHT protocol implementation
- `routingTable.go`: DHT routing table management
- `transport.go`: Network transport layer

#### `persistence/`
Database abstraction layer supporting multiple backends.

**Key files:**
- `interface.go`: Database interface definition
- `postgres.go`: PostgreSQL implementation
- `sqlite3.go`: SQLite3 implementation

#### `web/`
HTTP API and web interface.

**Key files:**
- `router.go`: HTTP routing
- `torrents.go`: Torrent search API
- `statistics.go`: Statistics API

## API Documentation

### REST API Endpoints

#### Search Torrents
```http
GET /api/torrents?q=search+query&limit=50&offset=0
```

**Parameters:**
- `q`: Search query (required)
- `limit`: Number of results (default: 50, max: 100)
- `offset`: Pagination offset (default: 0)
- `sort`: Sort order (`name`, `size`, `date`)
- `order`: Sort direction (`asc`, `desc`)

**Response:**
```json
{
  "torrents": [
    {
      "id": "abc123...",
      "name": "Example Torrent",
      "size": 1073741824,
      "files": [
        {
          "path": "file1.txt",
          "size": 536870912
        }
      ],
      "discovered_at": "2023-01-01T00:00:00Z"
    }
  ],
  "total": 1000,
  "limit": 50,
  "offset": 0
}
```

#### Get Torrent Details
```http
GET /api/torrents/{id}
```

**Response:**
```json
{
  "id": "abc123...",
  "name": "Example Torrent",
  "size": 1073741824,
  "files": [...],
  "discovered_at": "2023-01-01T00:00:00Z",
  "info_hash": "abc123...",
  "magnet_link": "magnet:?xt=urn:btih:abc123..."
}
```

#### Get Statistics
```http
GET /api/statistics
```

**Response:**
```json
{
  "total_torrents": 1000000,
  "total_size": 1099511627776,
  "discovery_rate": 1000,
  "uptime": 86400,
  "dht_nodes": 50000
}
```

#### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 86400,
  "database": "connected",
  "dht": "active"
}
```

### WebSocket API

#### Real-time Statistics
```javascript
const ws = new WebSocket('ws://localhost:8080/ws/stats');
ws.onmessage = function(event) {
    const stats = JSON.parse(event.data);
    console.log('Updated stats:', stats);
};
```

## Database Schema

### PostgreSQL Schema

```sql
-- Torrents table
CREATE TABLE torrents (
    id SERIAL PRIMARY KEY,
    info_hash BYTEA NOT NULL UNIQUE,
    name TEXT NOT NULL,
    size BIGINT NOT NULL,
    discovered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    files JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_torrents_name ON torrents USING gin(to_tsvector('english', name));
CREATE INDEX idx_torrents_size ON torrents(size);
CREATE INDEX idx_torrents_discovered_at ON torrents(discovered_at);
CREATE INDEX idx_torrents_info_hash ON torrents(info_hash);

-- Full-text search index
CREATE INDEX idx_torrents_search ON torrents USING gin(to_tsvector('english', name));

-- Statistics table
CREATE TABLE statistics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value BIGINT NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- DHT nodes table
CREATE TABLE dht_nodes (
    id SERIAL PRIMARY KEY,
    node_id BYTEA NOT NULL,
    address INET NOT NULL,
    port INTEGER NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(node_id, address, port)
);
```

### SQLite Schema

```sql
-- Torrents table
CREATE TABLE torrents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    info_hash BLOB NOT NULL UNIQUE,
    name TEXT NOT NULL,
    size INTEGER NOT NULL,
    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    files TEXT, -- JSON string
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_torrents_name ON torrents(name);
CREATE INDEX idx_torrents_size ON torrents(size);
CREATE INDEX idx_torrents_discovered_at ON torrents(discovered_at);
CREATE INDEX idx_torrents_info_hash ON torrents(info_hash);
```

## Testing

### Unit Tests

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run specific package tests
go test ./web/...

# Run tests with verbose output
go test -v ./...
```

### Integration Tests

```bash
# Run integration tests (requires database)
go test -tags=integration ./...

# Run tests with specific database
DB_DRIVER=postgres go test -tags=integration ./...
```

### Test Database Setup

```bash
# Create test database
sudo -u postgres createdb magnetico_test
sudo -u postgres psql -d magnetico_test -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Run tests with test database
DB_NAME=magnetico_test go test ./...
```

### Benchmarking

```bash
# Run benchmarks
go test -bench=. ./...

# Run specific benchmark
go test -bench=BenchmarkSearch ./web/...

# Run benchmarks with memory profiling
go test -bench=. -benchmem ./...
```

### Test Coverage

```bash
# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# View coverage in terminal
go tool cover -func=coverage.out
```

## Contributing

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Write tests** for new functionality
5. **Run tests and linting**:
   ```bash
   make test
   make lint
   ```
6. **Commit your changes**:
   ```bash
   git commit -m "Add feature: description of changes"
   ```
7. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
8. **Create a pull request**

### Code Style Guidelines

- Follow Go conventions: https://golang.org/doc/effective_go.html
- Use `gofmt` for formatting
- Use `goimports` for import organization
- Write comprehensive tests
- Document public APIs
- Use meaningful variable and function names

### Commit Message Format

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build process or auxiliary tool changes

**Examples:**
```
feat(web): add torrent search API endpoint

fix(dht): resolve connection timeout issues

docs(api): update REST API documentation
```

### Pull Request Guidelines

1. **Keep PRs focused**: One feature/fix per PR
2. **Write clear descriptions**: Explain what and why
3. **Include tests**: New code should have tests
4. **Update documentation**: Update relevant docs
5. **Check CI**: Ensure all tests pass

### Code Review Process

1. **Automated checks**: CI runs tests and linting
2. **Manual review**: Maintainers review code
3. **Feedback**: Address review comments
4. **Approval**: Maintainer approves PR
5. **Merge**: PR is merged to main branch

## Release Process

### Versioning

Magnetico uses semantic versioning (SemVer):
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Steps

1. **Update version** in `main.go` and `go.mod`
2. **Update CHANGELOG.md** with new features/fixes
3. **Create release branch**:
   ```bash
   git checkout -b release/v1.0.0
   ```
4. **Tag the release**:
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```
5. **Create GitHub release** with release notes
6. **Build and upload binaries** using GitHub Actions
7. **Update documentation** if needed

### Pre-release Testing

```bash
# Build release candidate
make build-all

# Test on different platforms
# Run comprehensive tests
make test-all

# Test installation scripts
./install/universal/scripts/test-installation.sh
```

### Release Checklist

- [ ] Version updated in code
- [ ] CHANGELOG.md updated
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Release notes written
- [ ] Binaries built and tested
- [ ] Installation scripts tested
- [ ] GitHub release created
- [ ] Announcement posted

## Advanced Topics

### Performance Optimization

#### Database Optimization
- Use appropriate indexes
- Optimize queries
- Use connection pooling
- Consider read replicas

#### Memory Optimization
- Use object pooling
- Implement caching
- Monitor memory usage
- Optimize data structures

#### Network Optimization
- Use connection pooling
- Implement rate limiting
- Optimize DHT crawling
- Use compression

### Security Considerations

#### Input Validation
- Validate all user inputs
- Sanitize search queries
- Prevent SQL injection
- Use parameterized queries

#### Authentication & Authorization
- Implement API authentication
- Use secure session management
- Implement rate limiting
- Log security events

#### Data Protection
- Encrypt sensitive data
- Use secure connections
- Implement access controls
- Regular security audits

### Monitoring and Observability

#### Metrics
- Application metrics
- System metrics
- Business metrics
- Custom metrics

#### Logging
- Structured logging
- Log levels
- Log aggregation
- Log analysis

#### Tracing
- Request tracing
- Performance profiling
- Error tracking
- User analytics

### Deployment Strategies

#### Containerization
- Docker images
- Kubernetes deployment
- Container orchestration
- Service mesh

#### CI/CD
- Automated testing
- Continuous integration
- Continuous deployment
- Environment management

#### Scaling
- Horizontal scaling
- Load balancing
- Database scaling
- Caching strategies

This developer guide provides a comprehensive overview of Magnetico's development process. For specific implementation details, refer to the source code and inline documentation.