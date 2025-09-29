#!/bin/bash
# Magnetico Installation Test Script
# Comprehensive testing of the installation process

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
TEST_RESULTS_DIR="/tmp/magnetico-test-results"

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

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to create test results directory
create_test_results_dir() {
    mkdir -p "$TEST_RESULTS_DIR"
    echo "Test started at: $(date)" > "$TEST_RESULTS_DIR/test-summary.txt"
}

# Function to log test result
log_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $test_name: $result" >> "$TEST_RESULTS_DIR/test-summary.txt"
    if [ -n "$details" ]; then
        echo "  Details: $details" >> "$TEST_RESULTS_DIR/test-summary.txt"
    fi
}

# Function to test system requirements
test_system_requirements() {
    print_step "Testing system requirements..."
    
    local platform=$(detect_platform)
    local distro=$(detect_distro)
    local all_passed=true
    
    # Test disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ "$available_gb" -ge 2 ]; then
        print_success "Disk space: ${available_gb}GB available"
        log_test_result "Disk Space" "PASS" "${available_gb}GB available"
    else
        print_error "Disk space: Only ${available_gb}GB available (minimum 2GB required)"
        log_test_result "Disk Space" "FAIL" "Only ${available_gb}GB available"
        all_passed=false
    fi
    
    # Test memory
    if command -v free &> /dev/null; then
        local available_mem=$(free -m | awk 'NR==2{print $7}')
        if [ "$available_mem" -ge 1024 ]; then
            print_success "Memory: ${available_mem}MB available"
            log_test_result "Memory" "PASS" "${available_mem}MB available"
        else
            print_warning "Memory: Only ${available_mem}MB available (recommended 1GB+)"
            log_test_result "Memory" "WARN" "Only ${available_mem}MB available"
        fi
    else
        print_warning "Memory: Cannot check memory usage"
        log_test_result "Memory" "WARN" "Cannot check"
    fi
    
    # Test platform support
    if [ "$platform" != "unsupported" ]; then
        print_success "Platform: $platform supported"
        log_test_result "Platform" "PASS" "$platform"
    else
        print_error "Platform: $(uname -s) not supported"
        log_test_result "Platform" "FAIL" "$(uname -s)"
        all_passed=false
    fi
    
    # Test required commands
    local required_commands=("curl" "wget" "systemctl" "nginx" "psql")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            print_success "Command: $cmd available"
            log_test_result "Command $cmd" "PASS" "Available"
        else
            print_warning "Command: $cmd not available"
            log_test_result "Command $cmd" "WARN" "Not available"
        fi
    done
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to test installation process
test_installation_process() {
    print_step "Testing installation process..."
    
    local all_passed=true
    
    # Test if installation directory exists
    if [ -d "$INSTALL_DIR" ]; then
        print_success "Installation directory exists"
        log_test_result "Installation Directory" "PASS" "Exists"
    else
        print_error "Installation directory missing"
        log_test_result "Installation Directory" "FAIL" "Missing"
        all_passed=false
    fi
    
    # Test if binary exists and is executable
    if [ -f "$INSTALL_DIR/magnetico" ]; then
        if [ -x "$INSTALL_DIR/magnetico" ]; then
            print_success "Binary exists and is executable"
            log_test_result "Binary" "PASS" "Executable"
        else
            print_error "Binary exists but is not executable"
            log_test_result "Binary" "FAIL" "Not executable"
            all_passed=false
        fi
    else
        print_error "Binary missing"
        log_test_result "Binary" "FAIL" "Missing"
        all_passed=false
    fi
    
    # Test if configuration directory exists
    if [ -d "$CONFIG_DIR" ]; then
        print_success "Configuration directory exists"
        log_test_result "Configuration Directory" "PASS" "Exists"
    else
        print_error "Configuration directory missing"
        log_test_result "Configuration Directory" "FAIL" "Missing"
        all_passed=false
    fi
    
    # Test if log directory exists
    if [ -d "$LOG_DIR" ]; then
        print_success "Log directory exists"
        log_test_result "Log Directory" "PASS" "Exists"
    else
        print_error "Log directory missing"
        log_test_result "Log Directory" "FAIL" "Missing"
        all_passed=false
    fi
    
    # Test if service user exists
    if id "magnetico" &>/dev/null; then
        print_success "Service user exists"
        log_test_result "Service User" "PASS" "Exists"
    else
        print_error "Service user missing"
        log_test_result "Service User" "FAIL" "Missing"
        all_passed=false
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to test service functionality
test_service_functionality() {
    print_step "Testing service functionality..."
    
    local all_passed=true
    
    # Test service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service is running"
        log_test_result "Service Status" "PASS" "Running"
    else
        print_error "Service is not running"
        log_test_result "Service Status" "FAIL" "Not running"
        all_passed=false
    fi
    
    # Test service is enabled
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        print_success "Service is enabled"
        log_test_result "Service Enabled" "PASS" "Enabled"
    else
        print_warning "Service is not enabled"
        log_test_result "Service Enabled" "WARN" "Not enabled"
    fi
    
    # Test web interface
    if command -v curl &> /dev/null; then
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/health 2>/dev/null || echo "000")
        if [ "$response_code" = "200" ]; then
            print_success "Web interface responding"
            log_test_result "Web Interface" "PASS" "HTTP 200"
        else
            print_error "Web interface not responding (HTTP $response_code)"
            log_test_result "Web Interface" "FAIL" "HTTP $response_code"
            all_passed=false
        fi
    else
        print_warning "Cannot test web interface (curl not available)"
        log_test_result "Web Interface" "WARN" "Cannot test"
    fi
    
    # Test DHT port
    if netstat -uln | grep -q ":6881 "; then
        print_success "DHT port is listening"
        log_test_result "DHT Port" "PASS" "Listening"
    else
        print_warning "DHT port is not listening"
        log_test_result "DHT Port" "WARN" "Not listening"
    fi
    
    # Test database connection
    if command -v psql &> /dev/null; then
        if psql -h localhost -U magnetico -d magnetico -c "SELECT 1;" &> /dev/null; then
            print_success "Database connection working"
            log_test_result "Database Connection" "PASS" "Connected"
        else
            print_error "Database connection failed"
            log_test_result "Database Connection" "FAIL" "Failed"
            all_passed=false
        fi
    else
        print_warning "Cannot test database connection (psql not available)"
        log_test_result "Database Connection" "WARN" "Cannot test"
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to test configuration
test_configuration() {
    print_step "Testing configuration..."
    
    local all_passed=true
    
    # Test if configuration file exists
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        print_success "Configuration file exists"
        log_test_result "Configuration File" "PASS" "Exists"
        
        # Test configuration file is readable
        if [ -r "$CONFIG_DIR/config.yml" ]; then
            print_success "Configuration file is readable"
            log_test_result "Configuration Readable" "PASS" "Readable"
        else
            print_error "Configuration file is not readable"
            log_test_result "Configuration Readable" "FAIL" "Not readable"
            all_passed=false
        fi
        
        # Test configuration file has required sections
        local required_sections=("database" "web" "dht" "logging")
        for section in "${required_sections[@]}"; do
            if grep -q "^$section:" "$CONFIG_DIR/config.yml"; then
                print_success "Configuration section '$section' exists"
                log_test_result "Config Section $section" "PASS" "Exists"
            else
                print_error "Configuration section '$section' missing"
                log_test_result "Config Section $section" "FAIL" "Missing"
                all_passed=false
            fi
        done
    else
        print_error "Configuration file missing"
        log_test_result "Configuration File" "FAIL" "Missing"
        all_passed=false
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to test security
test_security() {
    print_step "Testing security configuration..."
    
    local all_passed=true
    
    # Test file permissions
    if [ -f "$INSTALL_DIR/magnetico" ]; then
        local perms=$(stat -c "%a" "$INSTALL_DIR/magnetico" 2>/dev/null || echo "000")
        if [ "$perms" = "755" ] || [ "$perms" = "750" ]; then
            print_success "Binary permissions are secure"
            log_test_result "Binary Permissions" "PASS" "$perms"
        else
            print_warning "Binary permissions may be insecure: $perms"
            log_test_result "Binary Permissions" "WARN" "$perms"
        fi
    fi
    
    # Test configuration file permissions
    if [ -f "$CONFIG_DIR/config.yml" ]; then
        local perms=$(stat -c "%a" "$CONFIG_DIR/config.yml" 2>/dev/null || echo "000")
        if [ "$perms" = "600" ] || [ "$perms" = "640" ]; then
            print_success "Configuration file permissions are secure"
            log_test_result "Config Permissions" "PASS" "$perms"
        else
            print_warning "Configuration file permissions may be insecure: $perms"
            log_test_result "Config Permissions" "WARN" "$perms"
        fi
    fi
    
    # Test service user permissions
    if id "magnetico" &>/dev/null; then
        local user_home=$(getent passwd magnetico | cut -d: -f6)
        if [ -d "$user_home" ]; then
            local perms=$(stat -c "%a" "$user_home" 2>/dev/null || echo "000")
            if [ "$perms" = "755" ] || [ "$perms" = "750" ]; then
                print_success "Service user home permissions are secure"
                log_test_result "User Home Permissions" "PASS" "$perms"
            else
                print_warning "Service user home permissions may be insecure: $perms"
                log_test_result "User Home Permissions" "WARN" "$perms"
            fi
        fi
    fi
    
    # Test firewall rules
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_success "Firewall is active"
            log_test_result "Firewall" "PASS" "Active"
        else
            print_warning "Firewall is not active"
            log_test_result "Firewall" "WARN" "Not active"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state | grep -q "running"; then
            print_success "Firewall is active"
            log_test_result "Firewall" "PASS" "Active"
        else
            print_warning "Firewall is not active"
            log_test_result "Firewall" "WARN" "Not active"
        fi
    else
        print_warning "Cannot check firewall status"
        log_test_result "Firewall" "WARN" "Cannot check"
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to test performance
test_performance() {
    print_step "Testing performance..."
    
    local all_passed=true
    
    # Test response time
    if command -v curl &> /dev/null; then
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' http://127.0.0.1:8080/health 2>/dev/null || echo "999")
        if (( $(echo "$response_time < 2.0" | bc -l) )); then
            print_success "Response time is good: ${response_time}s"
            log_test_result "Response Time" "PASS" "${response_time}s"
        else
            print_warning "Response time is slow: ${response_time}s"
            log_test_result "Response Time" "WARN" "${response_time}s"
        fi
    else
        print_warning "Cannot test response time (curl not available)"
        log_test_result "Response Time" "WARN" "Cannot test"
    fi
    
    # Test memory usage
    if command -v ps &> /dev/null; then
        local memory_usage=$(ps -o pid,rss,comm -C magnetico | awk 'NR==2 {print $2}')
        if [ -n "$memory_usage" ]; then
            local memory_mb=$((memory_usage / 1024))
            if [ "$memory_mb" -lt 500 ]; then
                print_success "Memory usage is reasonable: ${memory_mb}MB"
                log_test_result "Memory Usage" "PASS" "${memory_mb}MB"
            else
                print_warning "Memory usage is high: ${memory_mb}MB"
                log_test_result "Memory Usage" "WARN" "${memory_mb}MB"
            fi
        else
            print_warning "Cannot get memory usage"
            log_test_result "Memory Usage" "WARN" "Cannot get"
        fi
    else
        print_warning "Cannot test memory usage (ps not available)"
        log_test_result "Memory Usage" "WARN" "Cannot test"
    fi
    
    # Test CPU usage
    if command -v top &> /dev/null; then
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
        if [ -n "$cpu_usage" ]; then
            if [ "$cpu_usage" -lt 50 ]; then
                print_success "CPU usage is reasonable: ${cpu_usage}%"
                log_test_result "CPU Usage" "PASS" "${cpu_usage}%"
            else
                print_warning "CPU usage is high: ${cpu_usage}%"
                log_test_result "CPU Usage" "WARN" "${cpu_usage}%"
            fi
        else
            print_warning "Cannot get CPU usage"
            log_test_result "CPU Usage" "WARN" "Cannot get"
        fi
    else
        print_warning "Cannot test CPU usage (top not available)"
        log_test_result "CPU Usage" "WARN" "Cannot test"
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to generate test report
generate_test_report() {
    print_step "Generating test report..."
    
    local report_file="$TEST_RESULTS_DIR/test-report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Magnetico Installation Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .test-result { margin: 10px 0; padding: 10px; border-radius: 5px; }
        .pass { background-color: #d4edda; color: #155724; }
        .fail { background-color: #f8d7da; color: #721c24; }
        .warn { background-color: #fff3cd; color: #856404; }
        .summary { background-color: #e2e3e5; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Magnetico Installation Test Report</h1>
        <p>Generated on: $(date)</p>
        <p>Platform: $(uname -s) $(uname -m)</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p>Total tests: $(wc -l < "$TEST_RESULTS_DIR/test-summary.txt")</p>
        <p>Passed: $(grep -c "PASS" "$TEST_RESULTS_DIR/test-summary.txt")</p>
        <p>Failed: $(grep -c "FAIL" "$TEST_RESULTS_DIR/test-summary.txt")</p>
        <p>Warnings: $(grep -c "WARN" "$TEST_RESULTS_DIR/test-summary.txt")</p>
    </div>
    
    <h2>Test Results</h2>
EOF
    
    # Add test results
    while IFS= read -r line; do
        if [[ $line == *"PASS"* ]]; then
            echo "    <div class=\"test-result pass\">$line</div>" >> "$report_file"
        elif [[ $line == *"FAIL"* ]]; then
            echo "    <div class=\"test-result fail\">$line</div>" >> "$report_file"
        elif [[ $line == *"WARN"* ]]; then
            echo "    <div class=\"test-result warn\">$line</div>" >> "$report_file"
        else
            echo "    <div class=\"test-result\">$line</div>" >> "$report_file"
        fi
    done < "$TEST_RESULTS_DIR/test-summary.txt"
    
    cat >> "$report_file" << EOF
</body>
</html>
EOF
    
    print_success "Test report generated: $report_file"
}

# Function to show help
show_help() {
    echo "Magnetico Installation Test Script"
    echo "=================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  --system-only      Test system requirements only"
    echo "  --installation-only Test installation process only"
    echo "  --service-only     Test service functionality only"
    echo "  --config-only      Test configuration only"
    echo "  --security-only    Test security configuration only"
    echo "  --performance-only Test performance only"
    echo "  --report-only      Generate test report only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 --system-only      # Test system requirements"
    echo "  $0 --service-only     # Test service functionality"
}

# Main function
main() {
    local system_only=false
    local installation_only=false
    local service_only=false
    local config_only=false
    local security_only=false
    local performance_only=false
    local report_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --system-only)
                system_only=true
                shift
                ;;
            --installation-only)
                installation_only=true
                shift
                ;;
            --service-only)
                service_only=true
                shift
                ;;
            --config-only)
                config_only=true
                shift
                ;;
            --security-only)
                security_only=true
                shift
                ;;
            --performance-only)
                performance_only=true
                shift
                ;;
            --report-only)
                report_only=true
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
    
    # Create test results directory
    create_test_results_dir
    
    print_step "Starting Magnetico installation tests..."
    echo ""
    
    local overall_result=0
    
    # Run tests based on options
    if [ "$system_only" = true ]; then
        test_system_requirements || overall_result=1
    elif [ "$installation_only" = true ]; then
        test_installation_process || overall_result=1
    elif [ "$service_only" = true ]; then
        test_service_functionality || overall_result=1
    elif [ "$config_only" = true ]; then
        test_configuration || overall_result=1
    elif [ "$security_only" = true ]; then
        test_security || overall_result=1
    elif [ "$performance_only" = true ]; then
        test_performance || overall_result=1
    elif [ "$report_only" = true ]; then
        generate_test_report
    else
        # Run all tests
        test_system_requirements || overall_result=1
        test_installation_process || overall_result=1
        test_service_functionality || overall_result=1
        test_configuration || overall_result=1
        test_security || overall_result=1
        test_performance || overall_result=1
        generate_test_report
    fi
    
    echo ""
    print_step "Test Summary"
    echo "============="
    
    if [ "$overall_result" -eq 0 ]; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed!"
    fi
    
    print_status "Test results: $TEST_RESULTS_DIR"
    print_status "Test report: $TEST_RESULTS_DIR/test-report.html"
    
    exit $overall_result
}

# Run main function
main "$@"

