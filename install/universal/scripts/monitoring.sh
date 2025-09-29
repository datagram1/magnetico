#!/bin/bash
# Magnetico Monitoring Script
# Sets up monitoring and alerting for Magnetico

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/magnetico"
CONFIG_DIR="/etc/magnetico"
LOG_DIR="/var/log/magnetico"
SERVICE_NAME="magnetico"
MONITORING_DIR="/opt/magnetico/monitoring"
CRON_DIR="/etc/cron.d"

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

# Function to detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "darwin";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unsupported";;
    esac
}

# Function to setup log monitoring
setup_log_monitoring() {
    print_step "Setting up log monitoring..."
    
    # Create monitoring directory
    mkdir -p "$MONITORING_DIR"
    
    # Create log monitoring script
    cat > "$MONITORING_DIR/log-monitor.sh" << 'EOF'
#!/bin/bash
# Log monitoring script for Magnetico

LOG_FILE="/var/log/magnetico/magnetico.log"
ALERT_EMAIL=""
ALERT_WEBHOOK=""

# Function to send alert
send_alert() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] ALERT: $message" >> /var/log/magnetico/monitoring.log
    
    # Send email alert if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Magnetico Alert" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert if configured
    if [ -n "$ALERT_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"Magnetico Alert: $message\"}" \
             "$ALERT_WEBHOOK" &> /dev/null
    fi
}

# Check for errors in the last 5 minutes
if [ -f "$LOG_FILE" ]; then
    # Count errors in the last 5 minutes
    error_count=$(tail -n 1000 "$LOG_FILE" | grep -i "error\|fatal\|panic" | wc -l)
    
    if [ "$error_count" -gt 10 ]; then
        send_alert "High error count detected: $error_count errors in recent logs"
    fi
    
    # Check for service restart
    if tail -n 100 "$LOG_FILE" | grep -q "service started\|service restarted"; then
        send_alert "Service restart detected"
    fi
    
    # Check for database connection issues
    if tail -n 100 "$LOG_FILE" | grep -qi "database.*connection\|postgresql.*error"; then
        send_alert "Database connection issue detected"
    fi
fi
EOF
    
    chmod +x "$MONITORING_DIR/log-monitor.sh"
    
    # Create cron job for log monitoring
    cat > "$CRON_DIR/magnetico-log-monitor" << EOF
# Magnetico log monitoring
*/5 * * * * root $MONITORING_DIR/log-monitor.sh
EOF
    
    print_success "Log monitoring configured"
}

# Function to setup performance monitoring
setup_performance_monitoring() {
    print_step "Setting up performance monitoring..."
    
    # Create performance monitoring script
    cat > "$MONITORING_DIR/performance-monitor.sh" << 'EOF'
#!/bin/bash
# Performance monitoring script for Magnetico

LOG_FILE="/var/log/magnetico/performance.log"
ALERT_EMAIL=""
ALERT_WEBHOOK=""

# Function to send alert
send_alert() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] PERFORMANCE ALERT: $message" >> "$LOG_FILE"
    
    # Send email alert if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Magnetico Performance Alert" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert if configured
    if [ -n "$ALERT_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"Magnetico Performance Alert: $message\"}" \
             "$ALERT_WEBHOOK" &> /dev/null
    fi
}

# Check disk space
disk_usage=$(df /opt/magnetico | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    send_alert "Disk usage is high: ${disk_usage}%"
fi

# Check memory usage
if command -v free &> /dev/null; then
    memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -gt 90 ]; then
        send_alert "Memory usage is high: ${memory_usage}%"
    fi
fi

# Check CPU usage
if command -v top &> /dev/null; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    if [ "$cpu_usage" -gt 90 ]; then
        send_alert "CPU usage is high: ${cpu_usage}%"
    fi
fi

# Check service response time
if command -v curl &> /dev/null; then
    response_time=$(curl -o /dev/null -s -w '%{time_total}' http://127.0.0.1:8080/health 2>/dev/null || echo "999")
    if (( $(echo "$response_time > 5.0" | bc -l) )); then
        send_alert "Service response time is slow: ${response_time}s"
    fi
fi

# Log performance metrics
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$timestamp] Disk: ${disk_usage}%, Memory: ${memory_usage}%, CPU: ${cpu_usage}%, Response: ${response_time}s" >> "$LOG_FILE"
EOF
    
    chmod +x "$MONITORING_DIR/performance-monitor.sh"
    
    # Create cron job for performance monitoring
    cat > "$CRON_DIR/magnetico-performance-monitor" << EOF
# Magnetico performance monitoring
*/2 * * * * root $MONITORING_DIR/performance-monitor.sh
EOF
    
    print_success "Performance monitoring configured"
}

# Function to setup health check monitoring
setup_health_monitoring() {
    print_step "Setting up health check monitoring..."
    
    # Create health check monitoring script
    cat > "$MONITORING_DIR/health-monitor.sh" << 'EOF'
#!/bin/bash
# Health check monitoring script for Magnetico

LOG_FILE="/var/log/magnetico/health.log"
ALERT_EMAIL=""
ALERT_WEBHOOK=""
SERVICE_NAME="magnetico"

# Function to send alert
send_alert() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] HEALTH ALERT: $message" >> "$LOG_FILE"
    
    # Send email alert if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Magnetico Health Alert" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert if configured
    if [ -n "$ALERT_WEBHOOK" ] && command -v curl &> /dev/null; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"Magnetico Health Alert: $message\"}" \
             "$ALERT_WEBHOOK" &> /dev/null
    fi
}

# Check service status
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    send_alert "Service is not running"
    # Try to restart the service
    systemctl start "$SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        send_alert "Service restarted successfully"
    else
        send_alert "Failed to restart service"
    fi
fi

# Check web interface health
if command -v curl &> /dev/null; then
    if ! curl -f -s http://127.0.0.1:8080/health &> /dev/null; then
        send_alert "Web interface health check failed"
    fi
fi

# Check DHT port
if ! netstat -uln | grep -q ":6881 "; then
    send_alert "DHT port is not listening"
fi

# Check database connection
if command -v psql &> /dev/null; then
    if ! psql -h localhost -U magnetico -d magnetico -c "SELECT 1;" &> /dev/null; then
        send_alert "Database connection failed"
    fi
fi
EOF
    
    chmod +x "$MONITORING_DIR/health-monitor.sh"
    
    # Create cron job for health monitoring
    cat > "$CRON_DIR/magnetico-health-monitor" << EOF
# Magnetico health monitoring
*/1 * * * * root $MONITORING_DIR/health-monitor.sh
EOF
    
    print_success "Health monitoring configured"
}

# Function to setup log rotation for monitoring
setup_monitoring_log_rotation() {
    print_step "Setting up monitoring log rotation..."
    
    cat > "/etc/logrotate.d/magnetico-monitoring" << EOF
/var/log/magnetico/monitoring.log
/var/log/magnetico/performance.log
/var/log/magnetico/health.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    print_success "Monitoring log rotation configured"
}

# Function to configure alerting
configure_alerting() {
    print_step "Configuring alerting..."
    
    # Create alerting configuration file
    cat > "$MONITORING_DIR/alerting.conf" << 'EOF'
# Magnetico Alerting Configuration
# Uncomment and configure the following options

# Email alerting
# ALERT_EMAIL="admin@example.com"

# Webhook alerting (Slack, Discord, etc.)
# ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Alert thresholds
DISK_THRESHOLD=90
MEMORY_THRESHOLD=90
CPU_THRESHOLD=90
RESPONSE_TIME_THRESHOLD=5.0
ERROR_COUNT_THRESHOLD=10
EOF
    
    print_success "Alerting configuration created"
    print_status "Edit $MONITORING_DIR/alerting.conf to configure alerting"
}

# Function to create monitoring dashboard
create_monitoring_dashboard() {
    print_step "Creating monitoring dashboard..."
    
    # Create simple HTML dashboard
    cat > "$MONITORING_DIR/dashboard.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Magnetico Monitoring Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .healthy { background-color: #d4edda; color: #155724; }
        .warning { background-color: #fff3cd; color: #856404; }
        .error { background-color: #f8d7da; color: #721c24; }
        .metric { display: inline-block; margin: 10px; padding: 10px; border: 1px solid #ccc; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Magnetico Monitoring Dashboard</h1>
    <p>Last updated: <span id="timestamp"></span></p>
    
    <div class="status" id="service-status">
        <h3>Service Status</h3>
        <p>Loading...</p>
    </div>
    
    <div class="status" id="web-status">
        <h3>Web Interface</h3>
        <p>Loading...</p>
    </div>
    
    <div class="status" id="database-status">
        <h3>Database</h3>
        <p>Loading...</p>
    </div>
    
    <div class="metrics">
        <div class="metric">
            <h4>Disk Usage</h4>
            <p id="disk-usage">Loading...</p>
        </div>
        <div class="metric">
            <h4>Memory Usage</h4>
            <p id="memory-usage">Loading...</p>
        </div>
        <div class="metric">
            <h4>Response Time</h4>
            <p id="response-time">Loading...</p>
        </div>
    </div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Simple status check
        fetch('/health')
            .then(response => response.ok ? 'healthy' : 'error')
            .then(status => {
                const element = document.getElementById('web-status');
                element.className = 'status ' + status;
                element.querySelector('p').textContent = 'Web interface: ' + status;
            })
            .catch(() => {
                const element = document.getElementById('web-status');
                element.className = 'status error';
                element.querySelector('p').textContent = 'Web interface: error';
            });
    </script>
</body>
</html>
EOF
    
    print_success "Monitoring dashboard created"
    print_status "Dashboard available at: http://localhost:8080/monitoring/dashboard.html"
}

# Function to show help
show_help() {
    echo "Magnetico Monitoring Setup Script"
    echo "================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  --logs-only        Setup log monitoring only"
    echo "  --performance-only Setup performance monitoring only"
    echo "  --health-only      Setup health monitoring only"
    echo "  --dashboard-only   Create monitoring dashboard only"
    echo "  --remove           Remove all monitoring components"
    echo ""
    echo "Examples:"
    echo "  $0                    # Setup all monitoring"
    echo "  $0 --logs-only        # Setup log monitoring only"
    echo "  $0 --remove           # Remove monitoring"
}

# Function to remove monitoring
remove_monitoring() {
    print_step "Removing monitoring components..."
    
    # Remove cron jobs
    rm -f "$CRON_DIR/magnetico-log-monitor"
    rm -f "$CRON_DIR/magnetico-performance-monitor"
    rm -f "$CRON_DIR/magnetico-health-monitor"
    
    # Remove log rotation
    rm -f "/etc/logrotate.d/magnetico-monitoring"
    
    # Remove monitoring directory
    rm -rf "$MONITORING_DIR"
    
    print_success "Monitoring components removed"
}

# Main function
main() {
    local logs_only=false
    local performance_only=false
    local health_only=false
    local dashboard_only=false
    local remove_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --logs-only)
                logs_only=true
                shift
                ;;
            --performance-only)
                performance_only=true
                shift
                ;;
            --health-only)
                health_only=true
                shift
                ;;
            --dashboard-only)
                dashboard_only=true
                shift
                ;;
            --remove)
                remove_mode=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Detect platform
    local platform=$(detect_platform)
    if [ "$platform" = "unsupported" ]; then
        print_error "Unsupported platform: $(uname -s)"
        exit 1
    fi
    
    # Handle remove mode
    if [ "$remove_mode" = true ]; then
        remove_monitoring
        exit 0
    fi
    
    print_step "Setting up Magnetico monitoring..."
    
    # Setup monitoring components
    if [ "$logs_only" = true ]; then
        setup_log_monitoring
    elif [ "$performance_only" = true ]; then
        setup_performance_monitoring
    elif [ "$health_only" = true ]; then
        setup_health_monitoring
    elif [ "$dashboard_only" = true ]; then
        create_monitoring_dashboard
    else
        # Setup all monitoring
        setup_log_monitoring
        setup_performance_monitoring
        setup_health_monitoring
        setup_monitoring_log_rotation
        configure_alerting
        create_monitoring_dashboard
    fi
    
    print_success "Monitoring setup completed!"
    print_status "Monitoring scripts: $MONITORING_DIR"
    print_status "Configuration: $MONITORING_DIR/alerting.conf"
    print_status "Dashboard: http://localhost:8080/monitoring/dashboard.html"
}

# Run main function
main "$@"

