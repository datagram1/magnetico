# Magnetico Developer Guide

This guide provides information for developers who want to contribute to Magnetico or understand its architecture.

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Build System](#build-system)
- [Testing](#testing)
- [Contributing](#contributing)
- [Architecture Overview](#architecture-overview)
- [API Documentation](#api-documentation)
- [Database Schema](#database-schema)
- [Configuration Reference](#configuration-reference)

## Development Environment Setup

### Prerequisites

- **Go**: Version 1.21 or later
- **PostgreSQL**: Version 12 or later
- **Git**: For version control
- **Make**: For build automation (optional)

### Local Development Setup

1. **Clone the repository**
```bash
git clone https://github.com/datagram1/magnetico.git
cd magnetico
```

2. **Install dependencies**
```bash
go mod download
```

3. **Set up PostgreSQL**
```bash
# Create database
sudo -u postgres createdb magnetico_dev

# Create user
sudo -u postgres createuser magnetico_dev

# Set password
sudo -u postgres psql -c "ALTER USER magnetico_dev PASSWORD 'dev_password';"

# Grant permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE magnetico_dev TO magnetico_dev;"
```

4. **Create development configuration**
```bash
cp doc/config.example.yml config.dev.yml
```

Edit `config.dev.yml`:
```yaml
database:
  driver: postgresql
  host: localhost
  port: 5432
  name: magnetico_dev
  user: magnetico_dev
  password: "dev_password"

web:
  host: "127.0.0.1"
  port: 8080

dht:
  port: 6881

logging:
  level: debug
  file: "magnetico.dev.log"
```

5. **Run the application**
```bash
go run main.go --config=config.dev.yml
```

## Project Structure

```
magnetico/
├── main.go                 # Application entry point
├── go.mod                  # Go module definition
├── go.sum                  # Go module checksums
├── README.md               # Project documentation
├── LICENSE                 # License file
├── doc/                    # Documentation
│   ├── config.example.yml  # Example configuration
│   └── *.md               # Documentation files
├── install/                # Installation scripts
│   ├── universal/          # Cross-platform installer
│   ├── ubuntu/             # Ubuntu-specific installer
│   └── docker/             # Docker installation
├── bencode/                # Bencode encoding/decoding
├── dht/                    # DHT protocol implementation
│   └── mainline/           # Mainline DHT implementation
├── metadata/               # Metadata handling
├── metainfo/               # Torrent metainfo parsing
├── persistence/            # Database persistence layer
├── stats/                  # Statistics and metrics
├── types/                  # Type definitions
├── web/                    # Web interface
└── opflags/                # Command-line options
```

## Build System

### Local Build

```bash
# Build for current platform
go build -tags fts5 -ldflags "-s -w" -o magnetico .

# Build with version information
go build -tags fts5 -ldflags "-s -w -X main.version=v1.0.0" -o magnetico .
```

### Cross-Platform Build

```bash
# Build for Linux
GOOS=linux GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-linux-amd64 .

# Build for Windows
GOOS=windows GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-windows-amd64.exe .

# Build for macOS
GOOS=darwin GOARCH=amd64 go build -tags fts5 -ldflags "-s -w" -o magnetico-darwin-amd64 .
```

### Using Build Scripts

```bash
# Build all platforms
cd install/universal/scripts
./build.sh

# Build specific platform
./build.sh --linux
./build.sh --windows
./build.sh --darwin
```

## Testing

### Unit Tests

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run specific package tests
go test ./dht/mainline
go test ./persistence
```

### Integration Tests

```bash
# Run integration tests (requires PostgreSQL)
go test -tags=integration ./...

# Run with specific database
DATABASE_URL="postgres://user:pass@localhost/magnetico_test" go test -tags=integration ./...
```

### Test Database Setup

```bash
# Create test database
sudo -u postgres createdb magnetico_test

# Run tests
go test -tags=integration ./...
```

### Performance Tests

```bash
# Run benchmarks
go test -bench=. ./...

# Run with profiling
go test -bench=. -cpuprofile=cpu.prof -memprofile=mem.prof ./...
```

## Contributing

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
```bash
git checkout -b feature/your-feature-name
```

3. **Make your changes**
4. **Add tests for new functionality**
5. **Run tests and ensure they pass**
```bash
go test ./...
go vet ./...
gofmt -s -w .
```

6. **Commit your changes**
```bash
git add .
git commit -m "Add your feature description"
```

7. **Push to your fork**
```bash
git push origin feature/your-feature-name
```

8. **Create a pull request**

### Code Style

- Follow Go conventions and idioms
- Use `gofmt` for formatting
- Write clear, self-documenting code
- Add comments for public APIs
- Use meaningful variable and function names

### Commit Messages

Use clear, descriptive commit messages:
```
Add DHT bootstrap node discovery
Fix PostgreSQL connection pool issue
Update web interface styling
```

### Pull Request Guidelines

- Provide a clear description of changes
- Include tests for new functionality
- Update documentation if needed
- Ensure all tests pass
- Follow the existing code style

## Architecture Overview

### Core Components

1. **DHT Crawler** (`dht/`)
   - Implements the DHT protocol
   - Discovers and crawls torrents
   - Manages peer connections

2. **Metadata Parser** (`metadata/`)
   - Parses torrent metadata
   - Extracts file information
   - Handles different torrent formats

3. **Persistence Layer** (`persistence/`)
   - Database abstraction
   - Supports PostgreSQL and SQLite
   - Handles data storage and retrieval

4. **Web Interface** (`web/`)
   - HTTP API endpoints
   - Search functionality
   - Statistics and monitoring

5. **Statistics** (`stats/`)
   - Performance metrics
   - System monitoring
   - Health checks

### Data Flow

```
DHT Network → DHT Crawler → Metadata Parser → Persistence Layer → Database
                                                      ↓
Web Interface ← HTTP API ← Search Engine ← Database
```

### Key Design Decisions

- **Modular Architecture**: Each component is independent and testable
- **Database Abstraction**: Support for multiple database backends
- **Configuration-Driven**: All behavior configurable via YAML
- **Performance-Focused**: Optimized for high-throughput operations

## API Documentation

### HTTP Endpoints

#### Search API
```http
GET /api/search?q=query&limit=50&offset=0
```

Response:
```json
{
  "results": [
    {
      "infohash": "abc123...",
      "name": "Example Torrent",
      "size": 1024000,
      "files": [
        {
          "path": "file1.txt",
          "size": 512000
        }
      ],
      "discovered_at": "2023-01-01T00:00:00Z"
    }
  ],
  "total": 100,
  "limit": 50,
  "offset": 0
}
```

#### Statistics API
```http
GET /api/stats
```

Response:
```json
{
  "torrents": 10000,
  "files": 50000,
  "size": "1.2 TB",
  "uptime": "24h30m15s",
  "dht_nodes": 1500
}
```

#### Health Check API
```http
GET /health
```

Response:
```json
{
  "status": "healthy",
  "database": "connected",
  "dht": "active",
  "uptime": "24h30m15s"
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

### Tables

#### `torrents`
```sql
CREATE TABLE torrents (
    id SERIAL PRIMARY KEY,
    infohash VARCHAR(40) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    size BIGINT NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### `files`
```sql
CREATE TABLE files (
    id SERIAL PRIMARY KEY,
    torrent_id INTEGER REFERENCES torrents(id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    size BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### `statistics`
```sql
CREATE TABLE statistics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value BIGINT NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Indexes

```sql
-- Search optimization
CREATE INDEX idx_torrents_name ON torrents USING gin(to_tsvector('english', name));
CREATE INDEX idx_torrents_infohash ON torrents(infohash);
CREATE INDEX idx_files_path ON files USING gin(to_tsvector('english', path));

-- Performance optimization
CREATE INDEX idx_torrents_discovered_at ON torrents(discovered_at);
CREATE INDEX idx_files_torrent_id ON files(torrent_id);
```

## Configuration Reference

### Database Configuration
```yaml
database:
  driver: postgresql          # postgresql, sqlite3
  host: localhost            # Database host
  port: 5432                 # Database port
  name: magnetico            # Database name
  user: magnetico            # Database user
  password: ""               # Database password
  max_open_conns: 25         # Maximum open connections
  max_idle_conns: 5          # Maximum idle connections
  conn_max_lifetime: 300s    # Connection lifetime
```

### Web Configuration
```yaml
web:
  host: "0.0.0.0"           # Bind address
  port: 8080                # HTTP port
  enable_cors: true         # Enable CORS
  cors_origins:             # Allowed origins
    - "http://localhost"
  rate_limit:
    enabled: true           # Enable rate limiting
    requests_per_minute: 100
    burst_size: 20
```

### DHT Configuration
```yaml
dht:
  port: 6881                # DHT port (UDP)
  bootstrap_nodes:          # Bootstrap nodes
    - "router.bittorrent.com:6881"
    - "dht.transmissionbt.com:6881"
  max_peers: 1000           # Maximum peers
  max_torrents: 10000       # Maximum torrents
  crawl_interval: 30s       # Crawl interval
```

### Logging Configuration
```yaml
logging:
  level: info               # debug, info, warn, error
  file: "/var/log/magnetico/magnetico.log"
  format: text              # text, json
  max_size: 100MB           # Log file max size
  max_age: 30               # Log retention days
  max_backups: 10           # Number of backup files
  compress: true            # Compress old logs
```

### Security Configuration
```yaml
security:
  rate_limit:
    enabled: true
    requests_per_minute: 100
    burst_size: 20
  cors:
    enabled: true
    allowed_origins:
      - "http://localhost"
    allowed_methods:
      - "GET"
      - "POST"
      - "OPTIONS"
  api_key: ""               # API key for authentication
```

### Performance Configuration
```yaml
performance:
  workers: 4                # Number of worker goroutines
  cache:
    enabled: true
    size: 100MB
    ttl: 300s
  db_pool:
    max_open_conns: 25
    max_idle_conns: 5
    conn_max_lifetime: 300s
```

## Development Tools

### Code Quality

```bash
# Format code
gofmt -s -w .

# Lint code
golangci-lint run

# Check for security issues
gosec ./...

# Check for race conditions
go test -race ./...
```

### Profiling

```bash
# CPU profiling
go tool pprof http://localhost:8080/debug/pprof/profile

# Memory profiling
go tool pprof http://localhost:8080/debug/pprof/heap

# Goroutine profiling
go tool pprof http://localhost:8080/debug/pprof/goroutine
```

### Benchmarking

```bash
# Run benchmarks
go test -bench=. ./...

# Compare benchmarks
go test -bench=. -benchmem ./... > old.txt
# Make changes
go test -bench=. -benchmem ./... > new.txt
benchcmp old.txt new.txt
```

## Deployment

### Development Deployment

```bash
# Build and run locally
go build -o magnetico .
./magnetico --config=config.dev.yml
```

### Production Deployment

```bash
# Use the installer
curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | bash

# Or build and deploy manually
go build -tags fts5 -ldflags "-s -w" -o magnetico .
sudo cp magnetico /opt/magnetico/
sudo systemctl start magnetico
```

### Docker Deployment

```bash
# Build Docker image
docker build -t magnetico .

# Run container
docker run -d \
  --name magnetico \
  -p 8080:8080 \
  -p 6881:6881/udp \
  -v /path/to/config:/etc/magnetico \
  -v /path/to/data:/var/lib/magnetico \
  magnetico
```

## Monitoring and Observability

### Metrics

Magnetico exposes Prometheus metrics at `/metrics`:

- `magnetico_torrents_total`: Total number of torrents
- `magnetico_files_total`: Total number of files
- `magnetico_dht_nodes`: Number of DHT nodes
- `magnetico_crawl_duration_seconds`: DHT crawl duration
- `magnetico_http_requests_total`: HTTP request count
- `magnetico_http_request_duration_seconds`: HTTP request duration

### Health Checks

- `/health`: Basic health check
- `/health/detailed`: Detailed health information
- `/ready`: Readiness probe
- `/live`: Liveness probe

### Logging

Structured logging with configurable levels:
- `debug`: Detailed debugging information
- `info`: General information
- `warn`: Warning messages
- `error`: Error messages

## Security Considerations

### Input Validation
- All user inputs are validated and sanitized
- SQL injection prevention through parameterized queries
- XSS prevention through proper output encoding

### Rate Limiting
- Configurable rate limits for API endpoints
- DDoS protection through connection limiting
- Resource usage monitoring

### Authentication
- Optional API key authentication
- CORS configuration for web security
- Secure headers implementation

## Performance Optimization

### Database Optimization
- Connection pooling
- Query optimization
- Index optimization
- Vacuum and analyze operations

### Memory Management
- Efficient data structures
- Garbage collection optimization
- Memory profiling and monitoring

### Network Optimization
- Connection reuse
- Compression
- Caching strategies
- Load balancing support

## Future Development

### Planned Features
- [ ] Distributed crawling
- [ ] Advanced search filters
- [ ] Real-time notifications
- [ ] API rate limiting improvements
- [ ] Additional database backends
- [ ] Kubernetes support
- [ ] GraphQL API
- [ ] Mobile app support

### Contributing Areas
- DHT protocol improvements
- Search algorithm optimization
- Web interface enhancements
- Performance optimizations
- Security improvements
- Documentation updates
- Test coverage improvements

## Support and Community

### Getting Help
- **GitHub Issues**: https://github.com/datagram1/magnetico/issues
- **GitHub Discussions**: https://github.com/datagram1/magnetico/discussions
- **Documentation**: https://github.com/datagram1/magnetico

### Contributing
- Read the [Contributing Guide](CONTRIBUTING.md)
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md)
- Join our [Discord server](https://discord.gg/magnetico)

### License
Magnetico is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
