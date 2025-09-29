# Magnetico Troubleshooting Guide

This guide helps you diagnose and resolve common issues with Magnetico installation and operation.

## Quick Diagnostics

### Health Check
Run the built-in health check to identify issues:

```bash
sudo /opt/magnetico/scripts/health-check.sh
```

### Service Status
Check if the service is running:

```bash
# Linux/macOS
sudo systemctl status magnetico

# Windows
sc query Magnetico
```

### Log Analysis
View recent logs for errors:

```bash
# Service logs
sudo journalctl -u magnetico -n 50

# Application logs
sudo tail -n 50 /var/log/magnetico/magnetico.log
```

## Common Installation Issues

### 1. Permission Denied Errors

**Symptoms:**
- "Permission denied" when running installer
- Cannot create directories or files

**Solutions:**
```bash
# Run installer with sudo
sudo curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | sudo bash

# Check file permissions
ls -la /opt/magnetico/
sudo chown -R magnetico:magnetico /opt/magnetico/
```

### 2. Network Connectivity Issues

**Symptoms:**
- Installer cannot download files
- "Connection refused" errors

**Solutions:**
```bash
# Test internet connectivity
ping -c 3 google.com

# Check DNS resolution
nslookup github.com

# Use alternative download method
wget -O install.sh https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh
sudo bash install.sh
```

### 3. Package Manager Issues

**Symptoms:**
- "Package not found" errors
- Repository update failures

**Solutions:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade
sudo apt install -y curl wget nginx postgresql-client

# CentOS/RHEL
sudo yum update
sudo yum install -y curl wget nginx postgresql

# macOS
brew update
brew install nginx postgresql@15
```

### 4. Port Conflicts

**Symptoms:**
- "Port already in use" errors
- Service fails to start

**Solutions:**
```bash
# Check what's using the port
sudo netstat -tulpn | grep :80
sudo netstat -ulpn | grep :6881

# Kill conflicting processes
sudo kill -9 <PID>

# Change ports in configuration
sudo nano /etc/magnetico/config.yml
```

## Service Issues

### 1. Service Won't Start

**Symptoms:**
- Service status shows "failed"
- No response from web interface

**Diagnosis:**
```bash
# Check service status
sudo systemctl status magnetico

# Check detailed logs
sudo journalctl -u magnetico -n 100

# Test configuration
sudo /opt/magnetico/magnetico --config=/etc/magnetico/config.yml --check
```

**Common Causes and Solutions:**

#### Configuration Errors
```bash
# Validate YAML syntax
sudo yamllint /etc/magnetico/config.yml

# Check file permissions
ls -la /etc/magnetico/config.yml
sudo chmod 600 /etc/magnetico/config.yml
sudo chown magnetico:magnetico /etc/magnetico/config.yml
```

#### Database Connection Issues
```bash
# Test PostgreSQL connection
sudo -u postgres psql -c "SELECT 1;"

# Check if database exists
sudo -u postgres psql -l | grep magnetico

# Create database if missing
sudo -u postgres createdb magnetico
sudo -u postgres psql -c "CREATE USER magnetico WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE magnetico TO magnetico;"
```

#### Binary Issues
```bash
# Check binary exists and is executable
ls -la /opt/magnetico/magnetico
sudo chmod +x /opt/magnetico/magnetico

# Test binary directly
sudo -u magnetico /opt/magnetico/magnetico --version
```

### 2. Service Keeps Restarting

**Symptoms:**
- Service status shows "restarting"
- Frequent log entries about restarts

**Diagnosis:**
```bash
# Check restart count
sudo systemctl status magnetico | grep "Main PID"

# Check for crash logs
sudo journalctl -u magnetico --since "1 hour ago" | grep -i "panic\|fatal\|error"

# Check resource usage
sudo systemctl show magnetico --property=MemoryCurrent,CPUUsageNSec
```

**Solutions:**
```bash
# Increase restart delay
sudo systemctl edit magnetico
# Add:
[Service]
RestartSec=30

# Check for memory issues
free -h
sudo dmesg | grep -i "killed process"

# Check disk space
df -h
```

### 3. Service Starts But Web Interface Unavailable

**Symptoms:**
- Service shows "active" but web interface doesn't load
- Connection refused on port 80/8080

**Diagnosis:**
```bash
# Check if process is listening
sudo netstat -tulpn | grep magnetico
sudo ss -tulpn | grep :8080

# Test local connection
curl -v http://127.0.0.1:8080/health

# Check firewall
sudo ufw status
sudo iptables -L
```

**Solutions:**
```bash
# Check configuration
grep -A 5 "web:" /etc/magnetico/config.yml

# Restart service
sudo systemctl restart magnetico

# Check Nginx configuration
sudo nginx -t
sudo systemctl restart nginx
```

## Database Issues

### 1. Connection Refused

**Symptoms:**
- "Connection refused" in logs
- Database connection errors

**Diagnosis:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check if PostgreSQL is listening
sudo netstat -tulpn | grep :5432

# Test connection
sudo -u postgres psql -c "SELECT 1;"
```

**Solutions:**
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check PostgreSQL configuration
sudo nano /etc/postgresql/*/main/postgresql.conf
# Ensure: listen_addresses = 'localhost'

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### 2. Authentication Failed

**Symptoms:**
- "Authentication failed" errors
- "Password authentication failed"

**Solutions:**
```bash
# Reset user password
sudo -u postgres psql -c "ALTER USER magnetico PASSWORD 'new_password';"

# Update configuration
sudo nano /etc/magnetico/config.yml
# Update password in database section

# Restart service
sudo systemctl restart magnetico
```

### 3. Database Not Found

**Symptoms:**
- "Database does not exist" errors
- Connection to non-existent database

**Solutions:**
```bash
# Create database
sudo -u postgres createdb magnetico

# Grant permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE magnetico TO magnetico;"

# Install required extensions
sudo -u postgres psql -d magnetico -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

## Performance Issues

### 1. High Memory Usage

**Symptoms:**
- System running out of memory
- OOM killer terminating processes

**Diagnosis:**
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head -10

# Check Magnetico memory usage
ps aux | grep magnetico
```

**Solutions:**
```bash
# Reduce worker count
sudo nano /etc/magnetico/config.yml
# Set: workers: 2

# Increase system memory
# Or add swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 2. High CPU Usage

**Symptoms:**
- System load high
- Slow response times

**Diagnosis:**
```bash
# Check CPU usage
top -p $(pgrep magnetico)
htop

# Check system load
uptime
```

**Solutions:**
```bash
# Reduce DHT crawler intensity
sudo nano /etc/magnetico/config.yml
# Reduce: max_peers, max_torrents

# Limit CPU usage
sudo systemctl edit magnetico
# Add:
[Service]
CPUQuota=50%
```

### 3. Slow Database Queries

**Symptoms:**
- Slow search responses
- High database CPU usage

**Diagnosis:**
```bash
# Check database performance
sudo -u postgres psql -d magnetico -c "SELECT * FROM pg_stat_activity;"
sudo -u postgres psql -d magnetico -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

**Solutions:**
```bash
# Add database indexes
sudo -u postgres psql -d magnetico -c "CREATE INDEX IF NOT EXISTS idx_torrents_name ON torrents USING gin(to_tsvector('english', name));"

# Optimize PostgreSQL configuration
sudo nano /etc/postgresql/*/main/postgresql.conf
# Increase: shared_buffers, effective_cache_size, work_mem
```

## Network Issues

### 1. DHT Not Working

**Symptoms:**
- No torrents being discovered
- DHT port not listening

**Diagnosis:**
```bash
# Check DHT port
sudo netstat -ulpn | grep :6881

# Check firewall
sudo ufw status
sudo iptables -L | grep 6881
```

**Solutions:**
```bash
# Open DHT port
sudo ufw allow 6881/udp

# Check DHT configuration
grep -A 10 "dht:" /etc/magnetico/config.yml

# Restart service
sudo systemctl restart magnetico
```

### 2. Web Interface Not Accessible from Network

**Symptoms:**
- Works locally but not from other machines
- Connection timeout from external IP

**Diagnosis:**
```bash
# Check binding address
grep -A 5 "web:" /etc/magnetico/config.yml

# Test from external machine
telnet your-server-ip 80
```

**Solutions:**
```bash
# Update configuration to bind to all interfaces
sudo nano /etc/magnetico/config.yml
# Set: host: "0.0.0.0"

# Check firewall rules
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Restart service
sudo systemctl restart magnetico
```

## Log Analysis

### Understanding Log Levels

- **DEBUG**: Detailed information for debugging
- **INFO**: General information about operation
- **WARN**: Warning messages about potential issues
- **ERROR**: Error messages about failures
- **FATAL**: Fatal errors that cause service to stop

### Common Log Patterns

#### Database Connection Errors
```
ERROR: failed to connect to database: connection refused
```
**Solution**: Check PostgreSQL service and configuration

#### Port Binding Errors
```
ERROR: listen tcp :8080: bind: address already in use
```
**Solution**: Kill conflicting process or change port

#### Permission Errors
```
ERROR: permission denied: open /var/log/magnetico/magnetico.log
```
**Solution**: Fix file permissions and ownership

#### DHT Errors
```
WARN: DHT bootstrap failed: no response from bootstrap nodes
```
**Solution**: Check network connectivity and firewall

### Log Rotation Issues

**Symptoms:**
- Log files growing too large
- Disk space issues

**Solutions:**
```bash
# Check log rotation configuration
cat /etc/logrotate.d/magnetico

# Manually rotate logs
sudo logrotate -f /etc/logrotate.d/magnetico

# Check disk usage
du -sh /var/log/magnetico/
```

## Recovery Procedures

### 1. Complete Service Recovery

```bash
# Stop service
sudo systemctl stop magnetico

# Backup configuration
sudo cp /etc/magnetico/config.yml /etc/magnetico/config.yml.backup

# Reset to defaults
sudo /opt/magnetico/scripts/config-wizard.sh

# Restart service
sudo systemctl start magnetico
```

### 2. Database Recovery

```bash
# Stop service
sudo systemctl stop magnetico

# Backup database
sudo -u postgres pg_dump magnetico > magnetico_backup.sql

# Recreate database
sudo -u postgres dropdb magnetico
sudo -u postgres createdb magnetico
sudo -u postgres psql -d magnetico -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Restore from backup
sudo -u postgres psql -d magnetico < magnetico_backup.sql

# Restart service
sudo systemctl start magnetico
```

### 3. Complete Reinstallation

```bash
# Uninstall completely
sudo /opt/magnetico/scripts/uninstall.sh

# Clean up any remaining files
sudo rm -rf /opt/magnetico
sudo rm -rf /etc/magnetico
sudo rm -rf /var/log/magnetico

# Reinstall
curl -fsSL https://raw.githubusercontent.com/datagram1/magnetico/main/install.sh | sudo bash
```

## Getting Help

### Before Asking for Help

1. **Run health check**: `sudo /opt/magnetico/scripts/health-check.sh`
2. **Check logs**: `sudo journalctl -u magnetico -n 100`
3. **Test configuration**: `sudo /opt/magnetico/magnetico --config=/etc/magnetico/config.yml --check`
4. **Document the issue**: Note exact error messages and when they occur

### Information to Include

When reporting issues, please provide:

- **Platform**: OS version and architecture
- **Installation method**: How you installed Magnetico
- **Error messages**: Exact error text
- **Logs**: Relevant log entries
- **Configuration**: Sanitized config file
- **Steps to reproduce**: What you did before the issue occurred

### Support Channels

- **GitHub Issues**: https://github.com/datagram1/magnetico/issues
- **GitHub Discussions**: https://github.com/datagram1/magnetico/discussions
- **Documentation**: https://github.com/datagram1/magnetico/wiki

### Emergency Recovery

If you need immediate assistance:

1. **Stop the service**: `sudo systemctl stop magnetico`
2. **Backup your data**: `sudo cp -r /etc/magnetico /tmp/magnetico-backup`
3. **Document the issue**: Take screenshots and note error messages
4. **Create a GitHub issue**: Include all relevant information

Remember: Most issues can be resolved by checking logs, verifying configuration, and ensuring all dependencies are properly installed and running.