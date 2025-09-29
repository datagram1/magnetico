#!/bin/bash
# Magnetico Health Check Script
# Monitors the health and status of Magnetico installation

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
WEB_PORT=8080
DHT_PORT=6881
HEALTH_ENDPOINT="http://127.0.0.1:$WEB_PORT/health"

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

# Function to check if service is running
check_service_status() {
    local platform=$1
    local status="unknown"
    
    case $platform in
        "linux")
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                status="running"
            elif systemctl is-failed --quiet "$SERVICE_NAME"; then
                status="failed"
            else
                status="stopped"
            fi
            ;;
        "darwin")
            if launchctl list | grep -q "com.magnetico"; then
                status="running"
            else
                status="stopped"
            fi
            ;;
        "windows")
            if sc query "$SERVICE_NAME" | grep -q "RUNNING"; then
                status="running"
            elif sc query "$SERVICE_NAME" | grep -q "STOPPED"; then
                status="stopped"
            else
                status="unknown"
            fi
            ;;
    esac
    
    echo "$status"
}

# Function to check binary existence
check_binary() {
    if [ -f "$INSTALL_DIR/magnetico" ]; then
        if [ -x "$INSTALL_DIR/magnetico" ]; then
            echo "exists_executable"
        else
            echo "exists_not_executable"
        fi
    else
        echo "missing"
    fi
}

# Function to check configuration
check_configuration() {
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        if [ -r "$CONFIG_DIR/config.yml" ]; then
            echo "exists_readable"
        else
            echo "exists_not_readable"
        fi
    else
        echo "missing"
    fi
}

# Function to check log directory
check_log_directory() {
    if [ -d "$LOG_DIR" ]; then
        if [ -w "$LOG_DIR" ]; then
            echo "exists_writable"
        else
            echo "exists_not_writable"
        fi
    else
        echo "missing"
    fi
}

# Function to check web interface
check_web_interface() {
    local response_code=""
    
    if command -v curl &> /dev/null; then
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
    elif command -v wget &> /dev/null; then
        response_code=$(wget --spider -q -S "$HEALTH_ENDPOINT" 2>&1 | grep "HTTP/" | tail -n1 | cut -d' ' -f2 || echo "000")
    else
        response_code="000"
    fi
    
    case $response_code in
        "200") echo "healthy" ;;
        "000") echo "unreachable" ;;
        *) echo "error_$response_code" ;;
    esac
}

# Function to check DHT port
check_dht_port() {
    if command -v netstat &> /dev/null; then
        if netstat -uln | grep -q ":$DHT_PORT "; then
            echo "listening"
        else
            echo "not_listening"
        fi
    elif command -v ss &> /dev/null; then
        if ss -uln | grep -q ":$DHT_PORT "; then
            echo "listening"
        else
            echo "not_listening"
        fi
    else
        echo "unknown"
    fi
}

# Function to check disk space
check_disk_space() {
    local available_space=$(df "$INSTALL_DIR" | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_gb" -ge 10 ]; then
        echo "sufficient"
    elif [ "$available_gb" -ge 5 ]; then
        echo "low"
    else
        echo "critical"
    fi
}

# Function to check memory usage
check_memory_usage() {
    if command -v free &> /dev/null; then
        local available_mem=$(free -m | awk 'NR==2{print $7}')
        if [ "$available_mem" -ge 1024 ]; then
            echo "sufficient"
        elif [ "$available_mem" -ge 512 ]; then
            echo "low"
        else
            echo "critical"
        fi
    else
        echo "unknown"
    fi
}

# Function to check database connection
check_database_connection() {
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        # Extract database configuration from YAML
        local db_host=$(grep -A 10 "database:" "$CONFIG_DIR/config.yml" | grep "host:" | cut -d'"' -f2 | head -n1)
        local db_port=$(grep -A 10 "database:" "$CONFIG_DIR/config.yml" | grep "port:" | awk '{print $2}' | head -n1)
        local db_name=$(grep -A 10 "database:" "$CONFIG_DIR/config.yml" | grep "name:" | cut -d'"' -f2 | head -n1)
        local db_user=$(grep -A 10 "database:" "$CONFIG_DIR/config.yml" | grep "user:" | cut -d'"' -f2 | head -n1)
        
        if [ -n "$db_host" ] && [ -n "$db_port" ] && [ -n "$db_name" ] && [ -n "$db_user" ]; then
            # Test database connection
            if command -v psql &> /dev/null; then
                if PGPASSWORD="" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1;" &> /dev/null; then
                    echo "connected"
                else
                    echo "connection_failed"
                fi
            else
                echo "psql_not_available"
            fi
        else
            echo "config_incomplete"
        fi
    else
        echo "config_missing"
    fi
}

# Function to get service uptime
get_service_uptime() {
    local platform=$1
    
    case $platform in
        "linux")
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null || echo "unknown"
            else
                echo "not_running"
            fi
            ;;
        "darwin")
            if launchctl list | grep -q "com.magnetico"; then
                launchctl list | grep "com.magnetico" | awk '{print $1}' || echo "unknown"
            else
                echo "not_running"
            fi
            ;;
        "windows")
            if sc query "$SERVICE_NAME" | grep -q "RUNNING"; then
                sc query "$SERVICE_NAME" | grep "START_TYPE" | awk '{print $3}' || echo "unknown"
            else
                echo "not_running"
            fi
            ;;
    esac
}

# Function to check recent logs for errors
check_recent_errors() {
    local log_file="$LOG_DIR/magnetico.log"
    local error_count=0
    
    if [ -f "$log_file" ]; then
        # Check for errors in the last 100 lines
        error_count=$(tail -n 100 "$log_file" | grep -i "error\|fatal\|panic" | wc -l)
    fi
    
    if [ "$error_count" -eq 0 ]; then
        echo "no_errors"
    elif [ "$error_count" -le 5 ]; then
        echo "few_errors"
    else
        echo "many_errors"
    fi
}

# Function to perform comprehensive health check
perform_health_check() {
    local platform=$(detect_platform)
    local overall_status="healthy"
    local issues=()
    
    print_step "Performing comprehensive health check..."
    echo ""
    
    # Check service status
    local service_status=$(check_service_status "$platform")
    if [ "$service_status" = "running" ]; then
        print_success "Service: Running"
    elif [ "$service_status" = "failed" ]; then
        print_error "Service: Failed"
        overall_status="unhealthy"
        issues+=("Service is in failed state")
    else
        print_error "Service: Stopped"
        overall_status="unhealthy"
        issues+=("Service is not running")
    fi
    
    # Check binary
    local binary_status=$(check_binary)
    if [ "$binary_status" = "exists_executable" ]; then
        print_success "Binary: Present and executable"
    elif [ "$binary_status" = "exists_not_executable" ]; then
        print_error "Binary: Present but not executable"
        overall_status="unhealthy"
        issues+=("Binary is not executable")
    else
        print_error "Binary: Missing"
        overall_status="unhealthy"
        issues+=("Binary file is missing")
    fi
    
    # Check configuration
    local config_status=$(check_configuration)
    if [ "$config_status" = "exists_readable" ]; then
        print_success "Configuration: Present and readable"
    elif [ "$config_status" = "exists_not_readable" ]; then
        print_error "Configuration: Present but not readable"
        overall_status="unhealthy"
        issues+=("Configuration file is not readable")
    else
        print_error "Configuration: Missing"
        overall_status="unhealthy"
        issues+=("Configuration file is missing")
    fi
    
    # Check log directory
    local log_status=$(check_log_directory)
    if [ "$log_status" = "exists_writable" ]; then
        print_success "Log directory: Present and writable"
    elif [ "$log_status" = "exists_not_writable" ]; then
        print_warning "Log directory: Present but not writable"
        issues+=("Log directory is not writable")
    else
        print_error "Log directory: Missing"
        overall_status="unhealthy"
        issues+=("Log directory is missing")
    fi
    
    # Check web interface
    local web_status=$(check_web_interface)
    if [ "$web_status" = "healthy" ]; then
        print_success "Web interface: Healthy"
    elif [ "$web_status" = "unreachable" ]; then
        print_error "Web interface: Unreachable"
        overall_status="unhealthy"
        issues+=("Web interface is not responding")
    else
        print_error "Web interface: Error ($web_status)"
        overall_status="unhealthy"
        issues+=("Web interface returned error: $web_status")
    fi
    
    # Check DHT port
    local dht_status=$(check_dht_port)
    if [ "$dht_status" = "listening" ]; then
        print_success "DHT port: Listening"
    else
        print_warning "DHT port: Not listening"
        issues+=("DHT port is not listening")
    fi
    
    # Check disk space
    local disk_status=$(check_disk_space)
    if [ "$disk_status" = "sufficient" ]; then
        print_success "Disk space: Sufficient"
    elif [ "$disk_status" = "low" ]; then
        print_warning "Disk space: Low"
        issues+=("Disk space is low")
    else
        print_error "Disk space: Critical"
        overall_status="unhealthy"
        issues+=("Disk space is critically low")
    fi
    
    # Check memory usage
    local memory_status=$(check_memory_usage)
    if [ "$memory_status" = "sufficient" ]; then
        print_success "Memory: Sufficient"
    elif [ "$memory_status" = "low" ]; then
        print_warning "Memory: Low"
        issues+=("Available memory is low")
    else
        print_error "Memory: Critical"
        overall_status="unhealthy"
        issues+=("Available memory is critically low")
    fi
    
    # Check database connection
    local db_status=$(check_database_connection)
    if [ "$db_status" = "connected" ]; then
        print_success "Database: Connected"
    elif [ "$db_status" = "connection_failed" ]; then
        print_error "Database: Connection failed"
        overall_status="unhealthy"
        issues+=("Database connection failed")
    else
        print_warning "Database: $db_status"
        issues+=("Database issue: $db_status")
    fi
    
    # Check recent errors
    local error_status=$(check_recent_errors)
    if [ "$error_status" = "no_errors" ]; then
        print_success "Recent logs: No errors"
    elif [ "$error_status" = "few_errors" ]; then
        print_warning "Recent logs: Few errors"
        issues+=("Some errors in recent logs")
    else
        print_error "Recent logs: Many errors"
        overall_status="unhealthy"
        issues+=("Many errors in recent logs")
    fi
    
    echo ""
    print_step "Health Check Summary"
    echo "======================"
    
    if [ "$overall_status" = "healthy" ]; then
        print_success "Overall Status: HEALTHY"
    else
        print_error "Overall Status: UNHEALTHY"
    fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        echo ""
        print_warning "Issues found:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
    
    echo ""
    print_status "Service uptime: $(get_service_uptime "$platform")"
    
    return $([ "$overall_status" = "healthy" ] && echo 0 || echo 1)
}

# Function to show help
show_help() {
    echo "Magnetico Health Check Script"
    echo "============================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --json         Output results in JSON format"
    echo "  --quiet        Only show errors and warnings"
    echo "  --service      Check service status only"
    echo "  --web          Check web interface only"
    echo "  --database     Check database connection only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full health check"
    echo "  $0 --json            # JSON output"
    echo "  $0 --service         # Service status only"
    echo "  $0 --quiet           # Quiet mode"
}

# Main function
main() {
    local json_output=false
    local quiet_mode=false
    local service_only=false
    local web_only=false
    local database_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --json)
                json_output=true
                shift
                ;;
            --quiet)
                quiet_mode=true
                shift
                ;;
            --service)
                service_only=true
                shift
                ;;
            --web)
                web_only=true
                shift
                ;;
            --database)
                database_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Perform health check
    if [ "$json_output" = true ]; then
        # TODO: Implement JSON output
        print_error "JSON output not implemented yet"
        exit 1
    elif [ "$quiet_mode" = true ]; then
        # TODO: Implement quiet mode
        print_error "Quiet mode not implemented yet"
        exit 1
    elif [ "$service_only" = true ]; then
        local platform=$(detect_platform)
        local service_status=$(check_service_status "$platform")
        echo "Service status: $service_status"
        exit $([ "$service_status" = "running" ] && echo 0 || echo 1)
    elif [ "$web_only" = true ]; then
        local web_status=$(check_web_interface)
        echo "Web interface: $web_status"
        exit $([ "$web_status" = "healthy" ] && echo 0 || echo 1)
    elif [ "$database_only" = true ]; then
        local db_status=$(check_database_connection)
        echo "Database: $db_status"
        exit $([ "$db_status" = "connected" ] && echo 0 || echo 1)
    else
        perform_health_check
    fi
}

# Run main function
main "$@"

