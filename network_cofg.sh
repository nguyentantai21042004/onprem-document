#!/bin/bash

# === DISABLE CLOUD-INIT NETWORK CONFIG ===
echo -e "\033[0;36m[+] Disabling cloud-init network config...\033[0m"
sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg > /dev/null

# === REMOVE CLOUD-INIT NETPLAN FILE ===
echo -e "\033[0;36m[+] Removing default cloud-init netplan config...\033[0m"
sudo rm -f /etc/netplan/50-cloud-init.yaml

# === GET NEW IP INFO ===
read -p "Static IP (e.g., 192.168.1.100/24): " IPADDR

# === VALIDATE IP FORMAT ===
if [[ ! $IPADDR =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo -e "\033[0;31m[!] Error: IP address must include prefix length (e.g., 192.168.1.100/24)\033[0m"
    exit 1
fi

# === CREATE NEW NETPLAN CONFIG ===
echo -e "\033[0;36m[+] Creating new netplan config: 01-network-config.yaml...\033[0m"
sudo tee /etc/netplan/01-network-config.yaml > /dev/null <<EOF
network:
    version: 2
    ethernets:
        ens160:
            dhcp4: no
            addresses:
                - ${IPADDR}
            routes:
                - to: default
                  via: 192.168.1.1
            nameservers:
                addresses: [8.8.8.8, 1.1.1.1]
EOF

# === SET CORRECT PERMISSIONS ===
sudo chmod 600 /etc/netplan/01-network-config.yaml

# === APPLY NEW NETWORK CONFIG ===
echo -e "\033[0;36m[+] Applying netplan...\033[0m"
sudo netplan apply

echo -e "\033[0;32m[✓] Done! Static IP ${IPADDR} has been set on ens160.\033[0m"