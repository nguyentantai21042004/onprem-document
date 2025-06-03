#!/bin/bash
echo "Starting MongoDB cleanup and removal..."

# Stop MongoDB service
echo "Stopping MongoDB service..."
sudo systemctl stop mongod

# Disable MongoDB service
echo "Disabling MongoDB service..."
sudo systemctl disable mongod

# Remove package holds
echo "Removing package holds..."
echo "mongodb-org install" | sudo dpkg --set-selections
echo "mongodb-org-database install" | sudo dpkg --set-selections
echo "mongodb-org-server install" | sudo dpkg --set-selections

# Remove MongoDB packages
echo "Removing MongoDB packages..."
sudo apt remove --purge -y mongodb-org*
sudo apt autoremove -y

# Remove MongoDB repository
echo "Removing MongoDB repository..."
sudo rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list

# Remove GPG key
echo "Removing MongoDB GPG key..."
sudo rm -f /usr/share/keyrings/mongodb-server-7.0.gpg

# Remove MongoDB directories and data
echo "Removing MongoDB directories and data..."
sudo rm -rf /var/lib/mongodb
sudo rm -rf /var/log/mongodb
sudo rm -rf /etc/mongod.conf
sudo rm -rf /tmp/mongodb-*.sock

# Remove MongoDB user and group (if they exist)
echo "Removing MongoDB user and group..."
sudo userdel mongodb 2>/dev/null || true
sudo groupdel mongodb 2>/dev/null || true

# Clean apt cache
echo "Cleaning apt cache..."
sudo apt update
sudo apt autoclean

# Remove any remaining MongoDB processes
echo "Checking for remaining MongoDB processes..."
sudo pkill -f mongod || true

echo "MongoDB cleanup completed!"
echo "All MongoDB components have been removed from the system." 