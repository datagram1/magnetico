# Magnetico Ubuntu Installation Files

This directory contains all the necessary files to install Magnetico on Ubuntu servers with PostgreSQL database support.

## Files

### Installation Scripts
- **`install-ubuntu.sh`** - Automated installation script
- **`setup-postgres.sh`** - PostgreSQL database setup script

### Configuration Files
- **`env.template`** - Environment configuration template
- **`env.example`** - Example environment configuration with credentials
- **`credentials.example`** - Example web authentication credentials
- **`magnetico.service`** - Systemd service file template
- **`nginx-magnetico.conf`** - Nginx reverse proxy configuration

## Quick Installation

```bash
curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install/ubuntu/install-ubuntu.sh | sudo bash
```

## Manual Installation

1. Download the files to your server
2. Make scripts executable: `chmod +x *.sh`
3. Copy and customize configuration files:
   - `cp env.example /opt/magnetico/.env` (update with your settings)
   - `cp credentials.example /opt/magnetico/credentials` (optional, for web auth)
4. Run the setup: `sudo ./install-ubuntu.sh`

## File Descriptions

### `install-ubuntu.sh`
Complete automated installation script that:
- Updates system packages
- Installs dependencies (Go, Nginx, PostgreSQL client)
- Builds Magnetico from source
- Configures systemd service
- Sets up Nginx reverse proxy
- Configures firewall
- Starts all services

### `setup-postgres.sh`
Database setup script that:
- Tests PostgreSQL connectivity
- Creates database and user
- Installs pg_trgm extension
- Configures permissions

### `env.template`
Environment configuration template with:
- Database connection settings
- Magnetico configuration options
- Performance tuning parameters

### `env.example`
Example environment configuration with:
- Pre-configured database credentials
- All available configuration options
- Detailed comments and examples

### `credentials.example`
Example web authentication credentials with:
- Sample bcrypt hashed passwords
- Instructions for generating new credentials
- Username and password requirements

### `magnetico.service`
Systemd service file with:
- Service configuration
- Security hardening
- Auto-restart settings
- Resource limits

### `nginx-magnetico.conf`
Nginx configuration that:
- Proxies requests to Magnetico
- Handles WebSocket connections
- Sets appropriate timeouts
- Configures headers

## Installation Result

After running the installation, you'll have:
- Magnetico running on port 8080 (internal)
- Nginx reverse proxy on port 80
- DHT crawler on port 6881 (UDP)
- PostgreSQL database connection
- Auto-start on boot
- Firewall configured
- Security hardening applied

Access the web interface at: `http://YOUR_SERVER_IP`

## Support

For detailed installation instructions, see: `../readme/UBUNTU_INSTALLATION.md`
