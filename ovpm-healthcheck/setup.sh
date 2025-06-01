#!/bin/bash
# OVPM Health Checker Setup Script
# Author: DevOps Health Monitor
# Version: 1.0

set -e

echo "🏥 OVPM Health Checker Setup Script"
echo "===================================="

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    echo "✅ Running as root"
elif command -v sudo &> /dev/null; then
    echo "✅ Using sudo for privileged operations"
    SUDO="sudo"
else
    echo "❌ This script needs root privileges or sudo access"
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
${SUDO} apt update
${SUDO} apt install -y python3 python3-pip python3-venv python3-dev

# Install system monitoring tools
${SUDO} apt install -y curl wget git build-essential htop net-tools

# Set installation directory to current directory
INSTALL_DIR="/home/tantai/healthcheck"
echo "📁 Using installation directory: $INSTALL_DIR"

# Create virtual environment and install dependencies
echo "🐍 Setting up Python virtual environment..."
cd $INSTALL_DIR

# Remove existing venv if it exists
if [ -d "venv" ]; then
    echo "Removing existing virtual environment..."
    rm -rf venv
fi

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Set permissions
chmod +x ovpm_health_checker.py

# Create config file if it doesn't exist
if [ ! -f "$INSTALL_DIR/ovpm_config.json" ]; then
    echo "⚙️ Creating configuration file..."
    python3 ovpm_health_checker.py --create-config-only 2>/dev/null || true
fi

# Install systemd service
echo "🔧 Installing systemd service..."
${SUDO} cp ovpm-health-checker.service /etc/systemd/system/

# Update systemd service to use correct paths
${SUDO} sed -i "s|WorkingDirectory=/opt/ovpm-health-checker|WorkingDirectory=$INSTALL_DIR|" /etc/systemd/system/ovpm-health-checker.service
${SUDO} sed -i "s|ExecStart=/usr/bin/python3 /opt/ovpm-health-checker|ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR|" /etc/systemd/system/ovpm-health-checker.service

# Reload systemd
${SUDO} systemctl daemon-reload

# Create log directory and file
${SUDO} mkdir -p /var/log
${SUDO} touch /var/log/ovpm_health.log
${SUDO} chown tantai:tantai /var/log/ovpm_health.log

echo ""
echo "✅ OVPM Health Checker installed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit configuration file: nano $INSTALL_DIR/ovpm_config.json"
echo "2. Verify Discord webhook URL is correct"
echo "3. Adjust settings as needed"
echo "4. Enable the service: sudo systemctl enable ovpm-health-checker"
echo "5. Start the service: sudo systemctl start ovpm-health-checker"
echo ""
echo "🔍 Useful commands:"
echo "- Check status: sudo systemctl status ovpm-health-checker"
echo "- View logs: sudo journalctl -u ovpm-health-checker -f"
echo "- View health logs: tail -f /var/log/ovpm_health.log"
echo "- Test run: cd $INSTALL_DIR && ./venv/bin/python3 ovpm_health_checker.py"
echo ""
echo "🎯 Configuration file location: $INSTALL_DIR/ovpm_config.json" 