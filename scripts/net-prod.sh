#!/bin/sh

# === DISABLE CLOUD-INIT NETWORK CONFIG ===
echo "\033[0;36m[+] Disabling cloud-init network config...\033[0m"
sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg >/dev/null

# === REMOVE CLOUD-INIT NETPLAN FILE ===
echo "\033[0;36m[+] Removing default cloud-init netplan config...\033[0m"
sudo rm -f /etc/netplan/50-cloud-init.yaml

# === GET NEW IP INFO ===
printf "Static IP (e.g., 192.168.1.100/24): "
read IPADDR

# === VALIDATE IP FORMAT ===
echo "$IPADDR" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'
if [ $? -ne 0 ]; then
    echo "\033[0;31m[!] Error: IP address must include prefix length (e.g., 192.168.1.100/24)\033[0m"
    exit 1
fi

# === CREATE NEW NETPLAN CONFIG ===
echo "\033[0;36m[+] Creating new netplan config: 01-network-config.yaml...\033[0m"
sudo sh -c "cat > /etc/netplan/01-network-config.yaml" <<EOF
network:
    version: 2
    ethernets:
        ens160:
            dhcp4: no
            addresses:
                - ${IPADDR}
            routes:
                - to: default
                  via: 172.16.21.1
            nameservers:
                addresses: [8.8.8.8, 1.1.1.1]
EOF

# === SET CORRECT PERMISSIONS ===
sudo chmod 600 /etc/netplan/01-network-config.yaml

# === APPLY NEW NETWORK CONFIG ===
echo "\033[0;36m[+] Applying netplan...\033[0m"
sudo netplan apply

echo "\033[0;32m[✓] Done! Static IP ${IPADDR} has been set on ens160.\033[0m"