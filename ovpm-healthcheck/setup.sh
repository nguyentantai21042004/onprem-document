#!/bin/bash
# OVPM Health Checker Setup Script - Enhanced Version
# Author: DevOps Health Monitor  
# Version: 2.0
# Installation Directory: /opt/ovpm-health-checker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

echo "🏥 OVPM Health Checker Setup Script v2.0"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log "Running as root - full installation mode"
    SUDO=""
else
    error "This script must be run as root for installation to /opt/"
    echo "Please run: sudo $0"
    exit 1
fi

# Set installation directory
INSTALL_DIR="/opt/ovpm-health-checker"
SERVICE_FILE="/etc/systemd/system/ovpm-health-checker.service"

log "Installation directory: $INSTALL_DIR"

# Check if OVPM is installed
if ! command -v ovpm &> /dev/null; then
    error "OVPM is not installed. Please install OVPM first."
    echo ""
    echo "To install OVPM, visit: https://github.com/cad/ovpm"
    exit 1
fi

log "OVPM found - version: $(ovpm version 2>/dev/null || echo 'unknown')"

# Check if ovpmd service exists
if ! systemctl list-unit-files | grep -q ovpmd; then
    warn "ovpmd service not found. Make sure OVPM is properly installed and configured."
fi

# Stop existing service if running
if systemctl is-active --quiet ovpm-health-checker 2>/dev/null; then
    log "Stopping existing ovpm-health-checker service..."
    systemctl stop ovpm-health-checker
fi

# Install system dependencies
log "Installing system dependencies..."
apt update
apt install -y python3 python3-pip python3-venv python3-dev curl wget git \
               build-essential htop net-tools jq tree systemd

# Create installation directory
log "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Backup existing configuration if it exists
if [ -f "$INSTALL_DIR/config.json" ]; then
    log "Backing up existing configuration..."
    cp config.json config.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create directory structure
log "Creating directory structure..."
mkdir -p logs data backup

# Remove existing virtual environment if it exists
if [ -d "venv" ]; then
    log "Removing existing virtual environment..."
    rm -rf venv
fi

# Create new virtual environment
log "Creating Python virtual environment..."
python3 -m venv venv

# Activate virtual environment and upgrade pip
log "Activating virtual environment and upgrading pip..."
source venv/bin/activate
pip install --upgrade pip setuptools wheel

# Install Python dependencies
log "Installing Python dependencies..."

# Create requirements.txt if not provided
if [ ! -f "requirements.txt" ]; then
    cat > requirements.txt << 'EOF'
requests>=2.28.0
psutil>=5.9.0
schedule>=1.2.0
urllib3>=1.26.0
certifi>=2022.12.7
simplejson>=3.18.0
colorlog>=6.7.0
EOF
fi

pip install -r requirements.txt

# Copy main script (assuming it's provided)
if [ ! -f "ovpm_health_checker.py" ]; then
    error "ovpm_health_checker.py not found in current directory"
    echo "Please ensure the main script is available before running setup"
    exit 1
fi

# Make script executable
chmod +x ovpm_health_checker.py

# Create default configuration if it doesn't exist
log "Creating configuration..."
if [ ! -f "config.json" ]; then
    log "Creating default configuration file..."
    ./venv/bin/python3 ovpm_health_checker.py --create-config
    
    # Get server information
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_HOSTNAME=$(hostname -f)
    
    # Update config with detected values
    if command -v jq &> /dev/null; then
        tmp=$(mktemp)
        jq --arg ip "$SERVER_IP" --arg hostname "$SERVER_HOSTNAME" \
           '.ovpm_server_ip = $ip | .ovpm_hostname = $hostname' config.json > "$tmp"
        mv "$tmp" config.json
        log "Updated config with detected server IP: $SERVER_IP"
    fi
else
    log "Using existing configuration file"
fi

# Create systemd service file
log "Installing systemd service..."

cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=OVPM Health Checker Service
Documentation=man:ovpm-health-checker(8)
After=network-online.target ovpmd.service
Wants=network-online.target ovpmd.service
BindsTo=ovpmd.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/ovpm-health-checker
ExecStart=/opt/ovpm-health-checker/venv/bin/python3 /opt/ovpm-health-checker/ovpm_health_checker.py
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID

# Restart settings
Restart=always
RestartSec=30
StartLimitInterval=300
StartLimitBurst=5

# Timeouts
TimeoutStartSec=60
TimeoutStopSec=60
KillMode=mixed

# Resource limits
MemoryMax=512M
CPUQuota=50%

# Environment
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=/opt/ovpm-health-checker

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ovpm-health-checker

# Security
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/opt/ovpm-health-checker /var/log

[Install]
WantedBy=multi-user.target
Also=ovpmd.service
EOF

# Set proper permissions
log "Setting file permissions..."
chown -R root:root "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"
chmod 644 "$INSTALL_DIR/config.json"
chmod 755 "$INSTALL_DIR/ovpm_health_checker.py"
chmod 644 "$SERVICE_FILE"

# Create log directories
mkdir -p /var/log/ovpm-health-checker
chown root:root /var/log/ovpm-health-checker

# Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service
log "Enabling ovpm-health-checker service..."
systemctl enable ovpm-health-checker

# Run test check
log "Running test health check..."
cd "$INSTALL_DIR"
if ./venv/bin/python3 ovpm_health_checker.py --test; then
    log "Test check passed successfully!"
else
    warn "Test check had issues, but continuing with installation..."
fi

# Start the service
log "Starting ovpm-health-checker service..."
systemctl start ovpm-health-checker

# Wait for service to start
sleep 5

# Check service status
log "Checking service status..."
if systemctl is-active --quiet ovpm-health-checker; then
    log "✅ Service is running successfully!"
    STATUS="RUNNING"
else
    warn "⚠️ Service may not be running properly"
    STATUS="STOPPED"
fi

if systemctl is-enabled --quiet ovpm-health-checker; then
    log "✅ Service will start automatically on boot!"
    AUTOSTART="ENABLED"
else
    warn "⚠️ Service auto-start may not be enabled properly"
    AUTOSTART="DISABLED"
fi

# Create management scripts
log "Creating management scripts..."

# Create status script
cat > "$INSTALL_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "=== OVPM Health Checker Status ==="
echo "Service Status: $(systemctl is-active ovpm-health-checker)"
echo "Auto-start: $(systemctl is-enabled ovpm-health-checker)"
echo "Last 10 log entries:"
journalctl -u ovpm-health-checker -n 10 --no-pager
EOF

# Create restart script
cat > "$INSTALL_DIR/restart.sh" << 'EOF'
#!/bin/bash
echo "Restarting OVPM Health Checker..."
sudo systemctl restart ovpm-health-checker
echo "Service restarted. Status: $(systemctl is-active ovpm-health-checker)"
EOF

# Create update script
cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
echo "Updating OVPM Health Checker..."
cd /opt/ovpm-health-checker
sudo systemctl stop ovpm-health-checker
source venv/bin/activate
pip install --upgrade -r requirements.txt
sudo systemctl start ovpm-health-checker
echo "Update completed. Status: $(systemctl is-active ovpm-health-checker)"
EOF

chmod +x "$INSTALL_DIR"/*.sh

echo ""
echo "======================================================================"
log "🎉 OVPM Health Checker installed and configured successfully!"
echo "======================================================================"
echo ""
echo "📋 Installation Summary:"
echo "  ✅ Installation Directory: $INSTALL_DIR"
echo "  ✅ Service Status: $STATUS"
echo "  ✅ Auto-start on Boot: $AUTOSTART"
echo "  ✅ Configuration: $INSTALL_DIR/config.json"
echo "  ✅ Logs: $INSTALL_DIR/logs/ and journalctl"
echo ""
echo "🔧 Management Commands:"
echo "  • Check status:     sudo systemctl status ovpm-health-checker"
echo "  • View logs:        sudo journalctl -u ovpm-health-checker -f"
echo "  • Restart service:  sudo systemctl restart ovpm-health-checker"
echo "  • Stop service:     sudo systemctl stop ovpm-health-checker"
echo "  • Disable service:  sudo systemctl disable ovpm-health-checker"
echo ""
echo "📁 Quick Scripts:"
echo "  • Status check:     $INSTALL_DIR/status.sh"
echo "  • Restart:          $INSTALL_DIR/restart.sh"
echo "  • Update:           $INSTALL_DIR/update.sh"
echo ""
echo "🧪 Manual Test:"
echo "  cd $INSTALL_DIR && ./venv/bin/python3 ovpm_health_checker.py --test"
echo ""
echo "⚙️ Configuration:"
echo "  Edit: $INSTALL_DIR/config.json"
echo "  📝 Remember to update your Discord webhook URL!"
echo ""

# Check Discord webhook configuration
if grep -q "YOUR_WEBHOOK_HERE" "$INSTALL_DIR/config.json" 2>/dev/null; then
    warn "⚠️  Discord webhook URL needs to be configured!"
    echo "     Edit $INSTALL_DIR/config.json and update the discord_webhook field"
    echo "     Then restart the service: sudo systemctl restart ovpm-health-checker"
    echo ""
fi

log "💬 Discord notifications should start appearing in your channel (if webhook configured)!"
log "🔄 The service will automatically start on system boot"

echo ""
echo "======================================================================"
echo "🏥 OVPM Health Checker v2.0 is now monitoring your VPN server!"
echo "======================================================================"