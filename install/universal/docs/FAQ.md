# Magnetico Frequently Asked Questions (FAQ)

## General Questions

### What is Magnetico?
Magnetico is a DHT (Distributed Hash Table) search engine that crawls the BitTorrent DHT network to discover and index torrents. It provides a web interface for searching torrents without relying on centralized trackers.

### How does Magnetico work?
Magnetico connects to the BitTorrent DHT network, discovers torrents by crawling the network, stores metadata in a database, and provides a web interface for searching. It operates independently of traditional torrent trackers.

### Is Magnetico legal?
Magnetico itself is a tool for discovering publicly available information on the DHT network. The legality depends on your jurisdiction and how you use it. Always comply with local laws and respect copyright.

### What platforms are supported?
- **Linux**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora 35+
- **macOS**: macOS 11+ (Intel and Apple Silicon)
- **Windows**: Windows 10+, Windows Server 2019+

## Installation Questions

### Can I install Magnetico without root/sudo access?
No, Magnetico requires root or administrator access to:
- Install system dependencies
- Create system users
- Configure system services
- Set up firewall rules
- Install to system directories

### What are the system requirements?
**Minimum:**
- 2 CPU cores
- 2GB RAM
- 10GB disk space
- Internet connection

**Recommended:**
- 4+ CPU cores
- 4GB+ RAM
- 50GB+ disk space
- Stable internet connection

### Can I install Magnetico on a VPS?
Yes, Magnetico works well on VPS providers like DigitalOcean, Linode, AWS, etc. Ensure your VPS meets the system requirements and has adequate bandwidth for DHT crawling.

### How long does installation take?
Installation typically takes 5-15 minutes depending on:
- System performance
- Internet speed
- Package manager speed
- Configuration complexity

### Can I install multiple instances?
Yes, you can run multiple instances by:
- Using different ports
- Using different configuration files
- Installing to different directories
- Using different system users

## Configuration Questions

### What database should I use?
**PostgreSQL (Recommended):**
- Better performance for large datasets
- Advanced querying capabilities
- Better concurrency handling
- Full-text search support

**SQLite (Development only):**
- Simpler setup
- Single file database
- Limited concurrency
- Not recommended for production

### What ports does Magnetico use?
- **Web interface**: 80 (HTTP) or 8080 (if 80 is unavailable)
- **DHT crawler**: 6881 (UDP)
- **Database**: 5432 (PostgreSQL default)

### Can I change the default ports?
Yes, edit the configuration file:
```yaml
web:
  port: 8080
dht:
  port: 6881
```

### How do I configure SSL/HTTPS?
Use a reverse proxy like Nginx or Apache:
```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

### Can I run Magnetico behind a reverse proxy?
Yes, Magnetico works well behind reverse proxies like Nginx, Apache, or Cloudflare. Configure the proxy to forward requests to the Magnetico web interface.

## Operation Questions

### How many torrents will Magnetico discover?
The number depends on:
- How long it's been running
- DHT network activity
- Your internet connection
- System performance

Typically, you can expect:
- **First day**: 1,000-10,000 torrents
- **First week**: 50,000-100,000 torrents
- **First month**: 200,000-500,000 torrents

### Why isn't Magnetico finding many torrents?
Common causes:
- **Firewall blocking DHT port**: Ensure UDP port 6881 is open
- **Poor internet connection**: DHT requires stable connectivity
- **System resources**: Insufficient CPU/memory
- **Network restrictions**: Some networks block P2P traffic

### How do I monitor Magnetico performance?
Use the built-in monitoring tools:
```bash
# Health check
sudo /opt/magnetico/scripts/health-check.sh

# Performance monitoring
sudo /opt/magnetico/scripts/monitoring.sh

# View statistics
curl http://localhost/api/stats
```

### Can I backup my Magnetico data?
Yes, backup the database and configuration:
```bash
# Backup database
sudo -u postgres pg_dump magnetico > magnetico_backup.sql

# Backup configuration
sudo cp -r /etc/magnetico /backup/magnetico-config

# Backup logs
sudo cp -r /var/log/magnetico /backup/magnetico-logs
```

### How do I update Magnetico?
Use the built-in update script:
```bash
# Check for updates
sudo /opt/magnetico/scripts/update.sh --check

# Install updates
sudo /opt/magnetico/scripts/update.sh
```

## Security Questions

### Is Magnetico secure?
Magnetico includes several security features:
- Rate limiting
- CORS protection
- Secure file permissions
- Firewall configuration
- System user isolation

### Should I expose Magnetico to the internet?
**For personal use**: Consider using a VPN or restricting access to your local network.

**For public use**: Implement additional security measures:
- Use HTTPS
- Implement authentication
- Use a reverse proxy
- Monitor access logs
- Regular security updates

### How do I secure the web interface?
1. **Use HTTPS**: Configure SSL certificates
2. **Implement authentication**: Add basic auth or OAuth
3. **Use a reverse proxy**: Nginx with security headers
4. **Restrict access**: Use firewall rules
5. **Monitor logs**: Set up log monitoring

### Can I restrict access to specific IPs?
Yes, configure your firewall or reverse proxy:
```nginx
# Nginx example
location / {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://127.0.0.1:8080;
}
```

## Performance Questions

### Why is Magnetico using so much memory?
High memory usage can be caused by:
- **Large database**: Many indexed torrents
- **High concurrency**: Many simultaneous requests
- **Inefficient queries**: Missing database indexes
- **Memory leaks**: Software bugs

**Solutions:**
- Reduce worker count
- Optimize database queries
- Add more RAM
- Restart service periodically

### Why is the web interface slow?
Common causes:
- **Database performance**: Slow queries, missing indexes
- **System resources**: High CPU/memory usage
- **Network latency**: Slow internet connection
- **Configuration issues**: Suboptimal settings

**Solutions:**
- Add database indexes
- Increase system resources
- Optimize configuration
- Use a faster database

### How can I improve search performance?
1. **Add database indexes**:
   ```sql
   CREATE INDEX idx_torrents_name ON torrents USING gin(to_tsvector('english', name));
   CREATE INDEX idx_torrents_size ON torrents(size);
   ```

2. **Optimize configuration**:
   ```yaml
   performance:
     workers: 4
     cache:
       enabled: true
       size: 100MB
   ```

3. **Use faster hardware**: SSD storage, more RAM, faster CPU

### Can I run Magnetico on a Raspberry Pi?
Yes, but with limitations:
- **Performance**: Slower than x86 systems
- **Memory**: Limited RAM (use 4GB+ model)
- **Storage**: Use fast SD card or USB drive
- **Network**: Ensure stable internet connection

**Recommended setup:**
- Raspberry Pi 4 with 4GB+ RAM
- Fast SD card (Class 10) or USB SSD
- Stable internet connection
- Reduce worker count in configuration

## Troubleshooting Questions

### Why won't Magnetico start?
Common causes:
1. **Configuration errors**: Invalid YAML syntax
2. **Database issues**: Connection problems
3. **Port conflicts**: Port already in use
4. **Permission issues**: File/directory permissions
5. **Missing dependencies**: Required packages not installed

**Diagnosis:**
```bash
# Check service status
sudo systemctl status magnetico

# Check logs
sudo journalctl -u magnetico -n 50

# Test configuration
sudo /opt/magnetico/magnetico --config=/etc/magnetico/config.yml --check
```

### Why is the database connection failing?
Common causes:
1. **PostgreSQL not running**: Service stopped
2. **Wrong credentials**: Incorrect username/password
3. **Database doesn't exist**: Missing database
4. **Network issues**: Connection refused
5. **Permission issues**: User lacks privileges

**Solutions:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
sudo -u postgres psql -c "SELECT 1;"

# Create database
sudo -u postgres createdb magnetico
```

### Why can't I access the web interface?
Common causes:
1. **Service not running**: Magnetico service stopped
2. **Wrong port**: Using incorrect port number
3. **Firewall blocking**: Port not open
4. **Binding issues**: Service not listening on correct interface
5. **Nginx issues**: Reverse proxy problems

**Diagnosis:**
```bash
# Check service status
sudo systemctl status magnetico

# Check if port is listening
sudo netstat -tulpn | grep :8080

# Test local connection
curl http://127.0.0.1:8080/health
```

### How do I reset Magnetico to defaults?
1. **Stop service**: `sudo systemctl stop magnetico`
2. **Backup configuration**: `sudo cp /etc/magnetico/config.yml /etc/magnetico/config.yml.backup`
3. **Run configuration wizard**: `sudo /opt/magnetico/scripts/config-wizard.sh`
4. **Restart service**: `sudo systemctl start magnetico`

### How do I completely uninstall Magnetico?
```bash
# Run uninstaller
sudo /opt/magnetico/scripts/uninstall.sh

# Or with options
sudo /opt/magnetico/scripts/uninstall.sh --keep-backups --remove-deps
```

## Advanced Questions

### Can I customize the web interface?
Yes, you can:
- Modify templates in `/opt/magnetico/templates/`
- Customize CSS in `/opt/magnetico/static/`
- Add new API endpoints
- Modify the search algorithm

### Can I integrate Magnetico with other tools?
Yes, Magnetico provides:
- **REST API**: For programmatic access
- **RSS feeds**: For torrent updates
- **Webhooks**: For event notifications
- **Database access**: Direct database queries

### How do I scale Magnetico for high traffic?
1. **Use a load balancer**: Distribute requests across multiple instances
2. **Optimize database**: Use read replicas, connection pooling
3. **Use caching**: Redis or Memcached for frequent queries
4. **CDN**: Use CloudFlare or similar for static content
5. **Monitor performance**: Set up comprehensive monitoring

### Can I run Magnetico in Docker?
Yes, you can containerize Magnetico:
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o magnetico .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/magnetico .
CMD ["./magnetico"]
```

### How do I contribute to Magnetico?
1. **Fork the repository**: Create your own fork
2. **Create a branch**: Work on a feature branch
3. **Make changes**: Implement your improvements
4. **Test thoroughly**: Ensure your changes work
5. **Submit a pull request**: Open a PR for review

### Where can I get help?
- **GitHub Issues**: Report bugs and request features
- **GitHub Discussions**: Ask questions and share ideas
- **Documentation**: Read the comprehensive guides
- **Community**: Join discussions and help others

## Legal and Ethical Questions

### Is it legal to run Magnetico?
The legality depends on your jurisdiction. Magnetico itself is a tool for discovering publicly available information. Always:
- Comply with local laws
- Respect copyright
- Use responsibly
- Consider the implications

### Should I run Magnetico publicly?
Consider the implications:
- **Legal risks**: Potential copyright issues
- **Resource usage**: Bandwidth and system resources
- **Security concerns**: Exposing services to the internet
- **Ethical considerations**: Impact on content creators

### How do I use Magnetico responsibly?
1. **Respect copyright**: Don't use for copyrighted content
2. **Monitor usage**: Keep track of what's being accessed
3. **Implement restrictions**: Use authentication and rate limiting
4. **Regular updates**: Keep the software updated
5. **Legal compliance**: Follow local laws and regulations

Remember: This FAQ covers common questions, but your specific situation may require additional research or professional advice.