#!/bin/bash
# OVPM Health Checker Setup Script
# Author: DevOps Health Monitor
# Version: 1.0

set -e

echo "🏥 OVPM Health Checker Setup Script"
echo "===================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)" 
   exit 1
fi

# Check if OVPM is installed
if ! command -v ovpm &> /dev/null; then
    echo "❌ OVPM is not installed. Please install OVPM first."
    exit 1
fi

echo "✅ OVPM found"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
apt update
apt install -y python3 python3-pip python3-venv

# Create installation directory
INSTALL_DIR="/opt/ovpm-health-checker"
echo "📁 Creating installation directory: $INSTALL_DIR"
mkdir -p $INSTALL_DIR

# Copy files
echo "📄 Copying health checker files..."
cp ovpm_health_checker.py $INSTALL_DIR/
cp requirements.txt $INSTALL_DIR/

# Set permissions
chmod +x $INSTALL_DIR/ovpm_health_checker.py

# Create virtual environment and install dependencies
echo "🐍 Setting up Python virtual environment..."
cd $INSTALL_DIR
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create config file if it doesn't exist
if [ ! -f "$INSTALL_DIR/ovpm_config.json" ]; then
    echo "⚙️ Creating configuration file..."
    python3 ovpm_health_checker.py --create-config-only 2>/dev/null || true
fi

# Install systemd service
echo "🔧 Installing systemd service..."
cp ovpm-health-checker.service /etc/systemd/system/

# Update systemd service to use virtual environment
sed -i "s|ExecStart=/usr/bin/python3|ExecStart=$INSTALL_DIR/venv/bin/python3|" /etc/systemd/system/ovpm-health-checker.service

# Reload systemd
systemctl daemon-reload

# Create log directory
mkdir -p /var/log
touch /var/log/ovpm_health.log
chown root:root /var/log/ovpm_health.log

echo ""
echo "✅ OVPM Health Checker installed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit configuration file: nano $INSTALL_DIR/ovpm_config.json"
echo "2. Add your Discord webhook URL"
echo "3. Adjust settings as needed"
echo "4. Start the service: systemctl enable ovpm-health-checker"
echo "5. Start the service: systemctl start ovpm-health-checker"
echo ""
echo "🔍 Useful commands:"
echo "- Check status: systemctl status ovpm-health-checker"
echo "- View logs: journalctl -u ovpm-health-checker -f"
echo "- View health logs: tail -f /var/log/ovpm_health.log"
echo "- Test run: cd $INSTALL_DIR && ./venv/bin/python3 ovpm_health_checker.py"
echo ""
echo "🎯 Configuration file location: $INSTALL_DIR/ovpm_config.json" 