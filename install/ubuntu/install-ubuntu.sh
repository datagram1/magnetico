#!/bin/bash

# Magnetico Ubuntu Server Installation Script
# This script installs magnetico as a native binary with systemd service
# Web interface will run on port 80 via Nginx, DHT crawler starts automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAGNETICO_USER="magnetico"
MAGNETICO_HOME="/opt/magnetico"
WEB_PORT="80"
DHT_PORT="6881"
POSTGRES_HOST="192.168.11.3"
POSTGRES_USER="keynetworks"
POSTGRES_PASS="K3yn3tw0rk5"
POSTGRES_DB="magnetico"

echo -e "${GREEN}Magnetico Ubuntu Server Installation${NC}"
echo "=================================="
echo -e "${BLUE}Server: $(hostname)${NC}"
echo -e "${BLUE}IP: $(hostname -I | awk '{print $1}')${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt install -y \
    curl \
    wget \
    git \
    build-essential \
    postgresql-client \
    nginx \
    ufw \
    golang-go

# Install and configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
systemctl start nginx
systemctl enable nginx

# Create Nginx configuration for Magnetico
tee /etc/nginx/sites-available/magnetico << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/magnetico /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl reload nginx

# Create magnetico user
echo -e "${YELLOW}Creating magnetico user...${NC}"
if ! id "$MAGNETICO_USER" &>/dev/null; then
    useradd -r -s /bin/false -d $MAGNETICO_HOME $MAGNETICO_USER
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p $MAGNETICO_HOME/{data,config,logs}
chown $MAGNETICO_USER:$MAGNETICO_USER $MAGNETICO_HOME

# Build Magnetico binary
echo -e "${YELLOW}Building Magnetico binary...${NC}"
cd /tmp
git clone https://github.com/datagram1/magnetico.git
cd magnetico

# Build the binary with FTS5 support
go build -tags fts5 -o magnetico .

# Install the binary
cp magnetico $MAGNETICO_HOME/
chown $MAGNETICO_USER:$MAGNETICO_USER $MAGNETICO_HOME/magnetico
chmod +x $MAGNETICO_HOME/magnetico

# Clean up
cd /
rm -rf /tmp/magnetico

# Test PostgreSQL connection
echo -e "${YELLOW}Testing PostgreSQL connection...${NC}"
if PGPASSWORD="$POSTGRES_PASS" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}PostgreSQL connection successful!${NC}"
else
    echo -e "${YELLOW}PostgreSQL connection failed. Creating database...${NC}"
    PGPASSWORD="$POSTGRES_PASS" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE IF NOT EXISTS $POSTGRES_DB;" || echo "Database creation failed or already exists"
    PGPASSWORD="$POSTGRES_PASS" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" || echo "Extension creation failed or already exists"
fi

# Create environment configuration
echo -e "${YELLOW}Creating environment configuration...${NC}"
tee $MAGNETICO_HOME/.env << EOF
# Database Configuration
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=5432
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASS

# Magnetico Configuration
WEB_PORT=8080
DHT_PORT=$DHT_PORT
MAGNETICO_ADDR=127.0.0.1:8080
EOF

chown $MAGNETICO_USER:$MAGNETICO_USER $MAGNETICO_HOME/.env
chmod 600 $MAGNETICO_HOME/.env

# Create systemd service
echo -e "${YELLOW}Creating systemd service...${NC}"
tee /etc/systemd/system/magnetico.service << EOF
[Unit]
Description=Magnetico DHT Search Engine
After=network.target postgresql.service
Wants=postgresql.service
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$MAGNETICO_HOME
ExecStart=$MAGNETICO_HOME/magnetico \\
  --addr=127.0.0.1:8080 \\
  --database=postgres://$POSTGRES_USER:$POSTGRES_PASS@$POSTGRES_HOST:5432/$POSTGRES_DB?sslmode=disable \\
  --daemon \\
  --web \\
  --max-rps=500 \\
  --leech-max-n=1000
ExecReload=/bin/kill -HUP \\\$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=30
User=$MAGNETICO_USER
Group=$MAGNETICO_USER
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=magnetico

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$MAGNETICO_HOME/data $MAGNETICO_HOME/logs
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow $WEB_PORT/tcp comment "Nginx Web Interface"
ufw allow $DHT_PORT/udp comment "Magnetico DHT"
ufw allow ssh
ufw --force enable

# Reload systemd
systemctl daemon-reload

# Enable and start service
echo -e "${YELLOW}Starting Magnetico service...${NC}"
systemctl enable magnetico
systemctl start magnetico

# Wait a moment for the service to start
sleep 10

# Check status
echo -e "${YELLOW}Checking service status...${NC}"
systemctl status magnetico --no-pager

# Test web interface
echo -e "${YELLOW}Testing web interface...${NC}"
sleep 5
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$WEB_PORT | grep -q "200"; then
    echo -e "${GREEN}Web interface is responding!${NC}"
else
    echo -e "${YELLOW}Web interface may still be starting up...${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo "=================================="
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "  Start:   systemctl start magnetico"
echo "  Stop:    systemctl stop magnetico"
echo "  Restart: systemctl restart magnetico"
echo "  Status:  systemctl status magnetico"
echo ""
echo -e "${BLUE}Web Interface:${NC}"
echo "  Local:   http://localhost:$WEB_PORT"
echo "  Network: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  Service: journalctl -u magnetico -f"
echo ""
echo -e "${BLUE}Database:${NC}"
echo "  Type: PostgreSQL"
echo "  Host: $POSTGRES_HOST"
echo "  Database: $POSTGRES_DB"
echo "  User: $POSTGRES_USER"
echo ""
echo -e "${YELLOW}The DHT crawler will start automatically and begin discovering torrents.${NC}"
echo -e "${YELLOW}The web interface is available immediately for searching.${NC}"
