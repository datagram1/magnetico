# Magnetico Installation Guide

This guide will help you install Magnetico DHT Search Engine on your system using the automated installer.

## Quick Installation

The easiest way to install Magnetico is using the one-command installer:

```bash
curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | bash
```

This command will:
1. Detect your platform and architecture
2. Download the appropriate installer
3. Guide you through the configuration process
4. Install all dependencies
5. Set up the service
6. Start Magnetico

## Supported Platforms

- **Linux**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora 35+
- **macOS**: macOS 11+ (Intel and Apple Silicon)
- **Windows**: Windows 10+, Windows Server 2019+

## System Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 10GB free space
- **Network**: Internet connection for DHT crawling

### Recommended Requirements
- **CPU**: 4+ cores
- **RAM**: 4GB+
- **Disk**: 50GB+ free space
- **Network**: Stable internet connection

## Pre-Installation Checklist

Before installing Magnetico, ensure your system meets the following requirements:

### Linux
- [ ] Root or sudo access
- [ ] Internet connection
- [ ] Package manager (apt, yum, dnf) available
- [ ] Systemd available (for service management)

### macOS
- [ ] Administrator access
- [ ] Homebrew installed
- [ ] Internet connection

### Windows
- [ ] Administrator access
- [ ] PowerShell 5.1+
- [ ] Internet connection

## Installation Process

### Step 1: Download and Run Installer

```bash
curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | bash
```

### Step 2: Platform Detection

The installer will automatically detect your platform and architecture:

```
[INFO] Detected platform: linux
[INFO] Detected architecture: amd64
```

### Step 3: Configuration Wizard

The installer will guide you through the configuration process:

#### Database Setup
Choose your database option:
1. **Install PostgreSQL locally** (recommended for most users)
2. **Connect to existing PostgreSQL server**
3. **Use SQLite** (development only)

#### Web Interface Configuration
- **Host**: Default is `0.0.0.0` (all interfaces)
- **Port**: Default is `80` (HTTP) or `8080` (if 80 is unavailable)

#### DHT Crawler Configuration
- **Port**: Default is `6881` (UDP)
- **Bootstrap nodes**: Default DHT bootstrap nodes

#### Security Configuration
- **Rate limiting**: Enable/disable API rate limiting
- **CORS**: Configure cross-origin resource sharing

### Step 4: Installation

The installer will:
1. Install system dependencies
2. Create system user
3. Download and install Magnetico binary
4. Create configuration files
5. Set up system service
6. Configure firewall rules
7. Start the service

### Step 5: Verification

After installation, verify that everything is working:

```bash
# Check service status
systemctl status magnetico

# Check web interface
curl http://localhost/health

# Check logs
journalctl -u magnetico -f
```

## Post-Installation Configuration

### Database Configuration

Edit the configuration file:

```bash
sudo nano /etc/magnetico/config.yml
```

Key database settings:
```yaml
database:
  driver: postgresql
  host: localhost
  port: 5432
  name: magnetico
  user: magnetico
  password: "your_password"
```

### Web Interface Configuration

```yaml
web:
  host: "0.0.0.0"
  port: 80
  rate_limit:
    enabled: true
    requests_per_minute: 100
```

### DHT Configuration

```yaml
dht:
  port: 6881
  bootstrap_nodes:
    - "router.bittorrent.com:6881"
    - "dht.transmissionbt.com:6881"
```

## Service Management

### Linux/macOS

```bash
# Start service
sudo systemctl start magnetico

# Stop service
sudo systemctl stop magnetico

# Restart service
sudo systemctl restart magnetico

# Check status
sudo systemctl status magnetico

# View logs
sudo journalctl -u magnetico -f

# Enable auto-start
sudo systemctl enable magnetico
```

### Windows

```cmd
# Start service
net start Magnetico

# Stop service
net stop Magnetico

# Check status
sc query Magnetico
```

## Accessing the Web Interface

Once installed, you can access the Magnetico web interface at:

- **Local access**: http://localhost
- **Network access**: http://your-server-ip

The web interface provides:
- Torrent search functionality
- Statistics and monitoring
- Configuration management
- Health status

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status magnetico

# Check logs for errors
sudo journalctl -u magnetico -n 50

# Check configuration
sudo magnetico --config=/etc/magnetico/config.yml --check
```

#### Database Connection Issues
```bash
# Test PostgreSQL connection
sudo -u postgres psql -c "SELECT 1;"

# Check database exists
sudo -u postgres psql -l | grep magnetico

# Reset database password
sudo -u postgres psql -c "ALTER USER magnetico PASSWORD 'new_password';"
```

#### Port Conflicts
```bash
# Check what's using port 80
sudo netstat -tulpn | grep :80

# Check what's using port 6881
sudo netstat -ulpn | grep :6881

# Change ports in configuration
sudo nano /etc/magnetico/config.yml
```

#### Firewall Issues
```bash
# Check firewall status
sudo ufw status

# Allow HTTP traffic
sudo ufw allow 80/tcp

# Allow DHT traffic
sudo ufw allow 6881/udp
```

### Log Files

Important log files:
- **Service logs**: `journalctl -u magnetico`
- **Application logs**: `/var/log/magnetico/magnetico.log`
- **Nginx logs**: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`

### Performance Issues

#### High Memory Usage
```bash
# Check memory usage
free -h
ps aux | grep magnetico

# Adjust worker count in config
sudo nano /etc/magnetico/config.yml
```

#### Slow Response Times
```bash
# Check disk I/O
iostat -x 1

# Check database performance
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

## Security Considerations

### Firewall Configuration
- Only open necessary ports (80, 443, 6881)
- Use fail2ban for additional protection
- Consider using a reverse proxy with SSL

### Database Security
- Use strong passwords
- Limit database user privileges
- Enable SSL for remote connections

### Web Interface Security
- Enable rate limiting
- Use HTTPS in production
- Regularly update the software

## Updates

### Automatic Updates
```bash
# Check for updates
sudo /opt/magnetico/scripts/update.sh --check

# Install updates
sudo /opt/magnetico/scripts/update.sh
```

### Manual Updates
```bash
# Download latest release
wget https://github.com/datagram1/magnetico/releases/latest/download/magnetico-linux-amd64

# Stop service
sudo systemctl stop magnetico

# Backup current binary
sudo cp /opt/magnetico/magnetico /opt/magnetico/magnetico.backup

# Install new binary
sudo cp magnetico-linux-amd64 /opt/magnetico/magnetico
sudo chmod +x /opt/magnetico/magnetico

# Start service
sudo systemctl start magnetico
```

## Uninstallation

To completely remove Magnetico:

```bash
# Run uninstaller
sudo /opt/magnetico/scripts/uninstall.sh

# Or with options
sudo /opt/magnetico/scripts/uninstall.sh --keep-backups --remove-deps
```

## Support

### Getting Help
- **Documentation**: https://github.com/datagram1/magnetico
- **Issues**: https://github.com/datagram1/magnetico/issues
- **Discussions**: https://github.com/datagram1/magnetico/discussions

### Reporting Issues
When reporting issues, please include:
- Platform and version
- Installation method
- Error messages
- Log files
- Configuration (sanitized)

### Contributing
We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

Magnetico is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

