# OpenVPN Server với OVPM

## Giới thiệu

OpenVPN server riêng là **bước quan trọng thứ tư** trong DevOps home lab journey. Thay vì expose từng service ra Internet (như Port Forwarding), VPN cho phép **secure tunnel** để truy cập toàn bộ internal network từ bất kỳ đâu - approach **an toàn hơn và professional hơn**.

### Tại sao VPN Server quan trọng cho DevOps?

**Security Best Practice**: VPN tunnel thay vì expose multiple ports ra Internet.

**Remote Development**: Access toàn bộ home lab environment từ xa một cách an toàn.

**Database Access**: Truy cập databases và internal services mà không cần port forwarding.

**Production Simulation**: Simulate enterprise network architecture với VPN gateway.

**Team Collaboration**: Chia sẻ secure access cho team members.

---

## PHẦN A: KIẾN THỨC CƠ BẢN

### A.1 OVPM là gì?

**OVPM** (OpenVPN Management) là tool quản lý OpenVPN server với:
- **Web UI**: Quản lý users, certificates, configs
- **Command Line**: Automation-friendly CLI tools
- **Database**: Centralized user/config management
- **Certificate Authority**: Tự động quản lý PKI

### A.2 Network Architecture:

```
Internet
    ↓ VPN Tunnel (UDP 1197)
VPN Server (192.168.1.210)
    ↓ Secure Access
Internal Network (192.168.1.0/24)
    ├── ESXi Server (192.168.1.50)
    ├── Database VMs (192.168.1.100-110)
    ├── Web Services (192.168.1.120-130)
    └── Development VMs (192.168.1.200+)
```

### A.3 Advantages vs Port Forwarding:

| Aspect | Port Forwarding | VPN Server |
|--------|----------------|------------|
| **Security** | Multiple exposed ports | Single VPN tunnel |
| **Access Control** | Router-level only | User-based authentication |
| **Encryption** | Depends on service | Full tunnel encryption |
| **Audit Trail** | Limited logging | Complete user tracking |
| **Scalability** | Manual port management | Centralized user management |

---

## PHẦN B: INFRASTRUCTURE SETUP

### B.1 Prerequisites:

```bash
# VM requirements for VPN server:
# - Ubuntu Server 20.04+ 
# - 2 CPU cores, 2GB RAM
# - Static IP: 192.168.1.210
# - Hostname: vpn-server
```

### B.2 DNS Setup (Dynamic DNS):

#### B.2.1 Configure Dynamic DNS:
```bash
# Example với NO-IP hoặc DuckDNS
# 1. Register domain: yourdomain.ddns.net
# 2. Create subdomain: vpn.yourdomain.ddns.net
# 3. Point subdomain to your public IP

# Test DNS resolution
nslookup vpn.yourdomain.ddns.net
dig vpn.yourdomain.ddns.net +short
```

#### B.2.2 Router Port Forwarding for VPN:
```
Service Name: OpenVPN-Server
External Port: 1197
Internal IP: 192.168.1.210
Internal Port: 1197
Protocol: UDP
Enable: Yes
```

---

## PHẦN C: OVPM INSTALLATION & SETUP

### C.1 Server Preparation:

```bash
# SSH vào VM designated cho VPN server
ssh root@192.168.1.210

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y curl wget gnupg2 software-properties-common

# Configure static IP (if not done)
cat > /etc/netplan/00-installer-config.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens160:  # Adjust interface name
      dhcp4: false
      addresses:
        - 192.168.1.210/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4, 192.168.1.1]
EOF

netplan apply
```

### C.2 OVPM Installation:

```bash
# Add OVPM repository
echo "deb [trusted=yes] https://cad.github.io/ovpm/deb/ ovpm main" | tee /etc/apt/sources.list.d/ovpm.list

# Update và install
apt update
apt install -y ovpm

# Enable and start service
systemctl enable ovpmd
systemctl start ovpmd

# Verify installation
systemctl status ovpmd
ovpm --version
```

### C.3 VPN Server Initialization:

```bash
# Initialize VPN server
ovpm vpn init \
  --hostname vpn.yourdomain.ddns.net \
  --port 1197 \
  --ca-expire 3650 \
  --cert-expire 365

# Configure network settings
ovpm vpn update \
  --net "192.168.1.0/24" \
  --dns "192.168.1.1,8.8.8.8" \
  --push-route "192.168.1.0/24"

# Verify configuration
ovpm vpn status
```

---

## PHẦN D: USER MANAGEMENT & ACCESS CONTROL

### D.1 Create Admin Users:

```bash
# Create admin user
ovpm user create \
  --username admin \
  --password "AdminVPN$(date +%m%d)" \
  --admin

# Create database admin user
ovpm user create \
  --username dbadmin \
  --password "DbAdmin$(date +%m%d)" \
  --no-gw

# Create developer user
ovpm user create \
  --username developer \
  --password "Dev$(date +%m%d)"

# List users
ovpm user list
```

### D.2 Generate Client Configurations:

```bash
# Create config directory
mkdir -p /opt/vpn-configs

# Generate .ovpn files
ovpm user genconfig --username admin --output /opt/vpn-configs/
ovpm user genconfig --username dbadmin --output /opt/vpn-configs/
ovpm user genconfig --username developer --output /opt/vpn-configs/

# Set proper permissions
chmod 600 /opt/vpn-configs/*.ovpn
ls -la /opt/vpn-configs/
```

### D.3 Advanced User Management Script:

**Create `manage-vpn-users.sh`:**
```bash
#!/bin/bash

# VPN User Management Script
VPN_CONFIG_DIR="/opt/vpn-configs"
BACKUP_DIR="/opt/vpn-backups"

create_user() {
    local username=$1
    local role=${2:-user}
    local password="VPN${username}$(date +%m%d)"
    
    echo "[INFO] Creating VPN user: $username (role: $role)"
    
    case $role in
        "admin")
            ovpm user create --username "$username" --password "$password" --admin
            ;;
        "dbonly")
            ovpm user create --username "$username" --password "$password" --no-gw
            ;;
        "user"|*)
            ovpm user create --username "$username" --password "$password"
            ;;
    esac
    
    # Generate config
    ovpm user genconfig --username "$username" --output "$VPN_CONFIG_DIR/"
    
    echo "[SUCCESS] User $username created with password: $password"
    echo "[INFO] Config file: $VPN_CONFIG_DIR/$username.ovpn"
}

list_users() {
    echo "[INFO] Current VPN users:"
    ovpm user list
}

backup_configs() {
    local backup_file="$BACKUP_DIR/vpn-backup-$(date +%Y%m%d-%H%M).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$backup_file" \
        "$VPN_CONFIG_DIR" \
        /var/lib/ovpm/ovpm.db
    
    echo "[SUCCESS] Backup created: $backup_file"
}

# Main execution
case "$1" in
    "create")
        create_user "$2" "$3"
        ;;
    "list")
        list_users
        ;;
    "backup")
        backup_configs
        ;;
    *)
        echo "Usage: $0 {create|list|backup}"
        echo "Examples:"
        echo "  $0 create john admin"
        echo "  $0 create dbuser dbonly"
        echo "  $0 create developer user"
        echo "  $0 list"
        echo "  $0 backup"
        exit 1
        ;;
esac
```

---

## PHẦN E: NETWORK & SECURITY CONFIGURATION

### E.1 Firewall Setup:

```bash
# Configure UFW
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow OpenVPN
ufw allow 1197/udp comment "OpenVPN Server"

# Allow OVPM Web UI (local network only)
ufw allow from 192.168.1.0/24 to any port 8080 comment "OVPM Web UI"

# Allow VPN clients to access LAN
ufw allow from 10.8.0.0/24 to 192.168.1.0/24
ufw allow from 192.168.1.0/24 to 10.8.0.0/24

# Enable firewall
ufw --force enable
ufw status verbose
```

### E.2 IP Forwarding & Routing:

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Configure iptables for NAT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 192.168.1.0/24 -j MASQUERADE
iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.1.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -d 10.8.0.0/24 -j ACCEPT

# Make iptables rules persistent
apt install -y iptables-persistent
iptables-save > /etc/iptables/rules.v4

# Verify routing
cat /proc/sys/net/ipv4/ip_forward
iptables -t nat -L -v -n
```

### E.3 Security Hardening:

```bash
# Strong OpenVPN settings
cat >> /etc/openvpn/server.conf << 'EOF'
# Security enhancements
cipher AES-256-GCM
auth SHA256
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
dh none
ecdh-curve prime256v1

# Additional security
remote-cert-tls client
verify-client-cert require
tls-auth ta.key 0
EOF

# Configure fail2ban for VPN
cat > /etc/fail2ban/jail.d/openvpn.conf << 'EOF'
[openvpn]
enabled = true
port = 1197
protocol = udp
filter = openvpn
logpath = /var/log/openvpn.log
maxretry = 3
bantime = 3600
findtime = 300
EOF

systemctl restart fail2ban
```

---

## PHẦN F: WEB UI & MANAGEMENT

### F.1 Web Interface Setup:

```bash
# Configure OVPM Web UI
ovpm web --port 8080 --host 0.0.0.0

# Create systemd service for Web UI
cat > /etc/systemd/system/ovpm-web.service << 'EOF'
[Unit]
Description=OVPM Web Interface
After=ovpmd.service
Requires=ovpmd.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ovpm web --port 8080 --host 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ovpm-web
systemctl start ovpm-web
systemctl status ovpm-web
```

### F.2 Access Web UI:

```bash
# Internal access
echo "Web UI: http://192.168.1.210:8080"

# External access (after VPN connection)
echo "Web UI via VPN: http://10.8.0.1:8080"

# Credentials
echo "Username: admin"
echo "Password: [created in user setup]"
```

---

## PHẦN G: CLIENT SETUP & TESTING

### G.1 Client Installation Examples:

#### G.1.1 macOS Client:
```bash
# Install via Homebrew
brew install --cask openvpn-connect

# Or download from: https://openvpn.net/vpn-client/
# Import .ovpn file từ /opt/vpn-configs/
```

#### G.1.2 Windows Client:
```powershell
# Download OpenVPN GUI from official website
# Install and import .ovpn configuration file
# Right-click system tray → Import file
```

#### G.1.3 Linux Client:
```bash
# Install OpenVPN client
apt install -y openvpn

# Copy .ovpn file
scp root@192.168.1.210:/opt/vpn-configs/developer.ovpn ./

# Connect
sudo openvpn --config developer.ovpn
```

### G.2 Connection Testing:

**Test script `test-vpn-connection.sh`:**
```bash
#!/bin/bash

# VPN Connection Test Script
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Testing VPN Connection & Access"
echo "================================="

# Test 1: VPN tunnel
echo -e "\n${YELLOW}Testing VPN tunnel...${NC}"
if ip route | grep -q "10.8.0"; then
    echo -e "${GREEN}✅ VPN tunnel active${NC}"
    VPN_IP=$(ip route | grep "10.8.0" | head -1 | awk '{print $9}')
    echo "VPN IP: $VPN_IP"
else
    echo -e "${RED}❌ VPN tunnel not active${NC}"
    exit 1
fi

# Test 2: VPN gateway
echo -e "\n${YELLOW}Testing VPN gateway...${NC}"
if ping -c 2 10.8.0.1 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ VPN gateway reachable${NC}"
else
    echo -e "${RED}❌ VPN gateway unreachable${NC}"
fi

# Test 3: LAN access
echo -e "\n${YELLOW}Testing LAN access...${NC}"
LAN_HOSTS=("192.168.1.1" "192.168.1.50" "192.168.1.210")

for host in "${LAN_HOSTS[@]}"; do
    if ping -c 1 -W 3 "$host" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $host reachable${NC}"
    else
        echo -e "${RED}❌ $host unreachable${NC}"
    fi
done

# Test 4: DNS resolution
echo -e "\n${YELLOW}Testing DNS resolution...${NC}"
if nslookup google.com > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DNS working${NC}"
else
    echo -e "${RED}❌ DNS not working${NC}"
fi

# Test 5: Internet access
echo -e "\n${YELLOW}Testing Internet access...${NC}"
if curl -s --connect-timeout 5 http://httpbin.org/ip > /dev/null; then
    echo -e "${GREEN}✅ Internet access working${NC}"
else
    echo -e "${RED}❌ Internet access blocked${NC}"
fi

echo -e "\n🎯 VPN connection test completed!"
```

---

## PHẦN H: AUTOMATION & INTEGRATION

### H.1 Integration với Wake On LAN Workflow:

**Enhanced server management trong `~/.zshrc`:**
```bash
# Complete server management với VPN
wake-server-complete() {
    SERVER_IP="192.168.1.50"
    VPN_SERVER="192.168.1.210"
    
    echo "[INFO] Starting complete server workflow..."
    
    # 1. Wake server
    wake-server
    
    # 2. Wait and check VPN server
    sleep 30
    echo "[INFO] Checking VPN server..."
    if ping -c 2 $VPN_SERVER > /dev/null; then
        echo "[SUCCESS] VPN server online"
    else
        echo "[ERROR] VPN server not accessible"
        return 1
    fi
    
    # 3. Test services through VPN (if connected)
    if ip route | grep -q "10.8.0"; then
        echo "[INFO] Testing services via VPN..."
        test-vpn-connection.sh
    else
        echo "[INFO] VPN not connected - skipping VPN tests"
    fi
}

# VPN connection helpers
vpn-connect() {
    local config=${1:-developer}
    echo "[INFO] Connecting to VPN with config: $config"
    sudo openvpn --config ~/vpn-configs/$config.ovpn --daemon
}

vpn-disconnect() {
    echo "[INFO] Disconnecting VPN..."
    sudo pkill openvpn
}

vpn-status() {
    if ip route | grep -q "10.8.0"; then
        echo "[INFO] VPN: Connected"
        ip route | grep "10.8.0"
    else
        echo "[INFO] VPN: Disconnected"
    fi
}
```

### H.2 Monitoring & Alerting:

**VPN monitoring script `monitor-vpn.sh`:**
```bash
#!/bin/bash

# VPN Server Monitoring Script
LOG_FILE="/var/log/vpn-monitor.log"
ALERT_EMAIL="admin@yourdomain.com"
VPN_LOG="/var/log/openvpn.log"

check_vpn_service() {
    if systemctl is-active --quiet ovpmd; then
        echo "$(date): ✅ OVPM service running" >> $LOG_FILE
        return 0
    else
        echo "$(date): ❌ OVPM service down" >> $LOG_FILE
        systemctl restart ovpmd
        return 1
    fi
}

check_active_connections() {
    local conn_count=$(ovpm user list | grep -c "Connected")
    echo "$(date): Active VPN connections: $conn_count" >> $LOG_FILE
    
    if [ $conn_count -gt 10 ]; then
        echo "$(date): ⚠️  High connection count: $conn_count" >> $LOG_FILE
    fi
}

check_certificate_expiry() {
    local days_left=$(openssl x509 -in /var/lib/ovpm/pki/ca.crt -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d {} +%s)
    local current_time=$(date +%s)
    local days_remaining=$(( (days_left - current_time) / 86400 ))
    
    echo "$(date): CA certificate expires in $days_remaining days" >> $LOG_FILE
    
    if [ $days_remaining -lt 30 ]; then
        echo "$(date): ⚠️  CA certificate expiring soon: $days_remaining days" >> $LOG_FILE
    fi
}

# Run checks
check_vpn_service
check_active_connections
check_certificate_expiry

# Cleanup old logs
find /var/log -name "vpn-monitor.log*" -mtime +30 -delete
```

**Setup cron job:**
```bash
# Add to crontab
echo "*/5 * * * * /opt/scripts/monitor-vpn.sh" | crontab -
```

---

## PHẦN I: TROUBLESHOOTING

### I.1 Common Issues & Solutions:

**❌ VPN clients không connect được:**
```bash
# Check 1: Service running?
systemctl status ovpmd
systemctl status openvpn@server

# Check 2: Port accessible?
netstat -tulpn | grep 1197
ufw status | grep 1197

# Check 3: Router port forwarding?
# Verify UDP 1197 forwarded to 192.168.1.210

# Check 4: DNS resolution?
nslookup vpn.yourdomain.ddns.net
```

**❌ Connected nhưng không truy cập được LAN:**
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Check iptables rules
iptables -t nat -L -v -n
iptables -L FORWARD -v -n

# Check routes
ip route show
ovpm vpn status
```

**❌ Web UI không accessible:**
```bash
# Check service
systemctl status ovpm-web

# Check port
netstat -tulpn | grep 8080

# Check from VPN client
curl -I http://10.8.0.1:8080
```

### I.2 Certificate Management:

```bash
# Regenerate CA (nếu cần)
ovpm pki ca-regen --expire 3650

# Regenerate server cert
ovpm pki server-regen --expire 365

# Revoke user certificate
ovpm user revoke --username username

# Generate CRL
ovpm pki crl-gen
```

---

## 🎯 TÓM TẮT & BEST PRACTICES

### ✅ DevOps Learning Outcomes:

**Network Security**: Deep understanding về VPN, PKI, encryption  
**Service Management**: systemd, process monitoring, log management  
**Infrastructure as Code**: Scripted deployment, configuration management  
**Remote Access Patterns**: Secure remote development workflows  
**Certificate Management**: PKI, certificate rotation, security lifecycle  

### 📋 Production-Ready Checklist:

- [ ] **VPN Server**: OVPM service running và stable
- [ ] **Network**: IP forwarding, iptables, firewall configured
- [ ] **DNS**: Dynamic DNS setup và working
- [ ] **Certificates**: Valid certificates với proper expiry
- [ ] **Users**: Role-based access control
- [ ] **Monitoring**: Health checks và alerting
- [ ] **Backup**: Regular backup của configs và database
- [ ] **Documentation**: User guides và troubleshooting procedures

### 🔐 Security Best Practices:

```bash
# Recommended configuration:
# - Strong encryption: AES-256-GCM
# - Certificate-based auth only
# - fail2ban protection
# - Regular certificate rotation
# - Network segmentation với firewall rules
# - Audit logging enabled
```

---

## 🔗 Next Steps: Advanced Infrastructure

VPN Server hoàn thiện **secure remote access foundation**. Bước tiếp theo là **advanced service orchestration**:

### 🚀 Recommended Learning Path:

**📋 Current capability**: 
```
WOL → Auto VMs → Services → Port Forward → Secure VPN Access
```

**🎯 Next level capabilities**: 
```
→ Container Orchestration → Service Mesh → Infrastructure as Code
```

### Upcoming guides:
- **Container & Kubernetes**: Modern application deployment
- **Infrastructure as Code**: Terraform, Ansible automation  
- **Monitoring & Observability**: Prometheus, Grafana, logging
- **CI/CD Pipelines**: GitLab, Jenkins, automated deployments

**Perfect foundation**: Secure networking → Modern orchestration → Complete DevOps automation! 🔒
