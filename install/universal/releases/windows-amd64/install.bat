@echo off
REM Windows Installation Script for Magnetico

setlocal enabledelayedexpansion

REM Configuration
set INSTALL_DIR=C:\Program Files\Magnetico
set CONFIG_DIR=C:\ProgramData\Magnetico
set LOG_DIR=C:\ProgramData\Magnetico\logs
set SERVICE_NAME=Magnetico
set SERVICE_DISPLAY_NAME=Magnetico DHT Search Engine
set SERVICE_DESCRIPTION=DHT search engine for discovering and searching torrents

REM Colors (using echo for Windows)
set INFO=[INFO]
set SUCCESS=[SUCCESS]
set ERROR=[ERROR]
set WARNING=[WARNING]
set STEP=[STEP]

echo.
echo ================================
echo    Magnetico DHT Search Engine
echo    Windows Installer v1.0.0
echo ================================
echo.

REM Function to print status
:print_status
echo %INFO% %~1
goto :eof

:print_success
echo %SUCCESS% %~1
goto :eof

:print_error
echo %ERROR% %~1
goto :eof

:print_warning
echo %WARNING% %~1
goto :eof

:print_step
echo %STEP% %~1
goto :eof

REM Check if running as administrator
:check_admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    call :print_error "This script must be run as Administrator"
    pause
    exit /b 1
)
goto :eof

REM Install dependencies
:install_dependencies
call :print_step "Installing system dependencies..."

REM Check if Chocolatey is installed
choco --version >nul 2>&1
if %errorLevel% neq 0 (
    call :print_status "Installing Chocolatey package manager..."
    powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    if %errorLevel% neq 0 (
        call :print_error "Failed to install Chocolatey"
        exit /b 1
    )
)

REM Install required packages
call :print_status "Installing required packages..."
choco install -y nginx postgresql
if %errorLevel% neq 0 (
    call :print_error "Failed to install packages"
    exit /b 1
)

call :print_success "System dependencies installed"
goto :eof

REM Create directories
:create_directories
call :print_step "Creating directories..."

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :print_success "Directories created"
goto :eof

REM Install binary
:install_binary
call :print_step "Installing Magnetico binary..."

if exist "magnetico.exe" (
    copy "magnetico.exe" "%INSTALL_DIR%\"
    call :print_success "Binary installed"
) else (
    call :print_error "Binary file not found"
    exit /b 1
)
goto :eof

REM Create Windows service
:create_service
call :print_step "Creating Windows service..."

REM Create service using sc command
sc create "%SERVICE_NAME%" binPath= "%INSTALL_DIR%\magnetico.exe --config=%CONFIG_DIR%\config.yml" DisplayName= "%SERVICE_DISPLAY_NAME%" start= auto
if %errorLevel% neq 0 (
    call :print_error "Failed to create Windows service"
    exit /b 1
)

REM Set service description
sc description "%SERVICE_NAME%" "%SERVICE_DESCRIPTION%"
if %errorLevel% neq 0 (
    call :print_warning "Failed to set service description"
)

call :print_success "Windows service created"
goto :eof

REM Configure Nginx
:configure_nginx
call :print_step "Configuring Nginx reverse proxy..."

REM Get Nginx installation path
for /f "tokens=*" %%i in ('where nginx') do set NGINX_PATH=%%i
set NGINX_DIR=!NGINX_PATH:~0,-10!

REM Create Nginx configuration
echo server { > "%NGINX_DIR%\conf\magnetico.conf"
echo     listen 80; >> "%NGINX_DIR%\conf\magnetico.conf"
echo     server_name _; >> "%NGINX_DIR%\conf\magnetico.conf"
echo. >> "%NGINX_DIR%\conf\magnetico.conf"
echo     # Security headers >> "%NGINX_DIR%\conf\magnetico.conf"
echo     add_header X-Frame-Options "SAMEORIGIN" always; >> "%NGINX_DIR%\conf\magnetico.conf"
echo     add_header X-Content-Type-Options "nosniff" always; >> "%NGINX_DIR%\conf\magnetico.conf"
echo     add_header X-XSS-Protection "1; mode=block" always; >> "%NGINX_DIR%\conf\magnetico.conf"
echo. >> "%NGINX_DIR%\conf\magnetico.conf"
echo     # Proxy settings >> "%NGINX_DIR%\conf\magnetico.conf"
echo     location / { >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_pass http://127.0.0.1:8080; >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_set_header Host $host; >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_set_header X-Real-IP $remote_addr; >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_set_header X-Forwarded-Proto $scheme; >> "%NGINX_DIR%\conf\magnetico.conf"
echo     } >> "%NGINX_DIR%\conf\magnetico.conf"
echo. >> "%NGINX_DIR%\conf\magnetico.conf"
echo     # Health check >> "%NGINX_DIR%\conf\magnetico.conf"
echo     location /health { >> "%NGINX_DIR%\conf\magnetico.conf"
echo         access_log off; >> "%NGINX_DIR%\conf\magnetico.conf"
echo         proxy_pass http://127.0.0.1:8080/health; >> "%NGINX_DIR%\conf\magnetico.conf"
echo     } >> "%NGINX_DIR%\conf\magnetico.conf"
echo } >> "%NGINX_DIR%\conf\magnetico.conf"

REM Include configuration in main nginx.conf
findstr /C:"include magnetico.conf" "%NGINX_DIR%\conf\nginx.conf" >nul
if %errorLevel% neq 0 (
    echo include magnetico.conf; >> "%NGINX_DIR%\conf\nginx.conf"
)

REM Test Nginx configuration
"%NGINX_DIR%\nginx.exe" -t
if %errorLevel% neq 0 (
    call :print_error "Nginx configuration is invalid"
    exit /b 1
)

call :print_success "Nginx configured"
goto :eof

REM Configure Windows Firewall
:configure_firewall
call :print_step "Configuring Windows Firewall..."

REM Allow HTTP traffic
netsh advfirewall firewall add rule name="Magnetico HTTP" dir=in action=allow protocol=TCP localport=80
if %errorLevel% neq 0 (
    call :print_warning "Failed to add HTTP firewall rule"
)

REM Allow HTTPS traffic
netsh advfirewall firewall add rule name="Magnetico HTTPS" dir=in action=allow protocol=TCP localport=443
if %errorLevel% neq 0 (
    call :print_warning "Failed to add HTTPS firewall rule"
)

REM Allow DHT traffic
netsh advfirewall firewall add rule name="Magnetico DHT" dir=in action=allow protocol=UDP localport=6881
if %errorLevel% neq 0 (
    call :print_warning "Failed to add DHT firewall rule"
)

call :print_success "Windows Firewall configured"
goto :eof

REM Create basic configuration
:create_basic_config
call :print_step "Creating basic configuration..."

if not exist "%CONFIG_DIR%\config.yml" (
    echo # Magnetico Configuration > "%CONFIG_DIR%\config.yml"
    echo database: >> "%CONFIG_DIR%\config.yml"
    echo   driver: postgresql >> "%CONFIG_DIR%\config.yml"
    echo   host: localhost >> "%CONFIG_DIR%\config.yml"
    echo   port: 5432 >> "%CONFIG_DIR%\config.yml"
    echo   name: magnetico >> "%CONFIG_DIR%\config.yml"
    echo   user: magnetico >> "%CONFIG_DIR%\config.yml"
    echo   password: "" >> "%CONFIG_DIR%\config.yml"
    echo. >> "%CONFIG_DIR%\config.yml"
    echo web: >> "%CONFIG_DIR%\config.yml"
    echo   port: 8080 >> "%CONFIG_DIR%\config.yml"
    echo   host: "127.0.0.1" >> "%CONFIG_DIR%\config.yml"
    echo. >> "%CONFIG_DIR%\config.yml"
    echo dht: >> "%CONFIG_DIR%\config.yml"
    echo   port: 6881 >> "%CONFIG_DIR%\config.yml"
    echo   bootstrap_nodes: >> "%CONFIG_DIR%\config.yml"
    echo     - "router.bittorrent.com:6881" >> "%CONFIG_DIR%\config.yml"
    echo     - "dht.transmissionbt.com:6881" >> "%CONFIG_DIR%\config.yml"
    echo. >> "%CONFIG_DIR%\config.yml"
    echo logging: >> "%CONFIG_DIR%\config.yml"
    echo   level: info >> "%CONFIG_DIR%\config.yml"
    echo   file: "%LOG_DIR%\magnetico.log" >> "%CONFIG_DIR%\config.yml"
    
    call :print_success "Basic configuration created"
) else (
    call :print_status "Configuration file already exists"
)
goto :eof

REM Start services
:start_services
call :print_step "Starting services..."

REM Start Nginx
net start nginx
if %errorLevel% neq 0 (
    call :print_warning "Failed to start Nginx service"
)

REM Start Magnetico service
net start "%SERVICE_NAME%"
if %errorLevel% neq 0 (
    call :print_error "Failed to start Magnetico service"
    exit /b 1
)

call :print_success "Services started"
goto :eof

REM Show installation summary
:show_summary
call :print_step "Installation Summary"
echo.
echo Magnetico has been successfully installed on your Windows system!
echo.
echo Installation Details:
echo   - Installation directory: %INSTALL_DIR%
echo   - Configuration directory: %CONFIG_DIR%
echo   - Log directory: %LOG_DIR%
echo   - Service name: %SERVICE_NAME%
echo.
echo Service Management:
echo   - Start service: net start %SERVICE_NAME%
echo   - Stop service: net stop %SERVICE_NAME%
echo   - Check status: sc query %SERVICE_NAME%
echo.
echo Web Interface:
echo   - URL: http://localhost
echo.
echo Next Steps:
echo   1. Configure your database connection in %CONFIG_DIR%\config.yml
echo   2. Restart the service: net stop %SERVICE_NAME% ^&^& net start %SERVICE_NAME%
echo   3. Access the web interface at http://localhost
echo.
echo For support, visit: https://github.com/datagram1/magnetico
goto :eof

REM Show help
:show_help
echo Magnetico Windows Installation Script
echo =====================================
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   -h, --help     Show this help message
echo   --no-nginx     Skip Nginx configuration
echo   --no-firewall  Skip firewall configuration
echo   --no-service   Skip service creation
echo.
echo Examples:
echo   %~nx0                    # Standard installation
echo   %~nx0 --no-nginx        # Skip Nginx setup
echo   %~nx0 --no-firewall     # Skip firewall setup
goto :eof

REM Main installation function
:main
set no_nginx=false
set no_firewall=false
set no_service=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_install
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help
if "%~1"=="--no-nginx" set no_nginx=true
if "%~1"=="--no-firewall" set no_firewall=true
if "%~1"=="--no-service" set no_service=true
shift
goto :parse_args

:start_install
REM Check if running as administrator
call :check_admin

call :print_step "Starting Magnetico installation for Windows..."

REM Install dependencies
call :install_dependencies

REM Create directories
call :create_directories

REM Install binary
call :install_binary

REM Create basic configuration
call :create_basic_config

REM Create Windows service
if "%no_service%"=="false" (
    call :create_service
)

REM Configure Nginx
if "%no_nginx%"=="false" (
    call :configure_nginx
)

REM Configure firewall
if "%no_firewall%"=="false" (
    call :configure_firewall
)

REM Start services
if "%no_service%"=="false" (
    call :start_services
)

REM Show summary
call :show_summary

pause
goto :eof

REM Run main function
call :main %*
