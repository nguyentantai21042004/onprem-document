#!/bin/bash
echo "Starting MongoDB uninstallation..."

# Stop and disable MongoDB service
echo "Stopping MongoDB service..."
sudo systemctl stop mongod
sudo systemctl disable mongod

# Remove MongoDB packages
echo "Removing MongoDB packages..."
sudo apt remove -y mongodb-org mongodb-org-database mongodb-org-server mongodb-org-mongos mongodb-org-tools

# Remove MongoDB directories and data
echo "Removing MongoDB directories and data..."
sudo rm -rf /var/lib/mongodb
sudo rm -rf /var/log/mongodb
sudo rm -rf /etc/mongod.conf

# Remove MongoDB repository
echo "Removing MongoDB repository..."
sudo rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list

# Remove MongoDB GPG key
echo "Removing MongoDB GPG key..."
sudo rm -f /usr/share/keyrings/mongodb-server-7.0.gpg

# Clean up package cache
echo "Cleaning up package cache..."
sudo apt autoremove -y
sudo apt autoclean

# Update package list
sudo apt update

echo "MongoDB uninstallation completed!"
echo "Note: If you had any custom MongoDB data, it has been removed." 