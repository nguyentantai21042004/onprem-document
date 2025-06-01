# OpenVPN Server với OVPM

## Giới thiệu

OpenVPN Server với OVPM là **bước advanced level** trong home lab DevOps journey. Sau khi đã có Port Forwarding để expose services, VPN Server mang lại **enterprise-grade security** và **centralized access control** cho toàn bộ infrastructure.

### Tại sao OpenVPN quan trọng cho DevOps?

**Enterprise Security**: PKI certificates, encryption, và authentication - standard trong production environments.

**Remote Development**: Secure access tới entire home lab từ bất kỳ đâu.

**Zero Trust Architecture**: User-based authentication thay vì network-based access.

**Audit & Compliance**: Complete logging và user tracking cho security requirements.

---

## PHẦN A: TỔNG QUAN OVPM

### A.1 OVPM là gì?

**OVPM** (OpenVPN Management) là web-based interface để quản lý OpenVPN server một cách dễ dàng. Thay vì configure OpenVPN manually với command line, OVPM cung cấp:

- **Web GUI**: Quản lý users, certificates, configurations
- **REST API**: Automation và integration
- **User Self-Service**: Users có thể download own configs
- **Monitoring**: Connection logs, bandwidth usage
- **PKI Management**: Automatic certificate generation và revocation

### A.2 So sánh với Port Forwarding:

| Aspect | Port Forwarding | OpenVPN Server |
|--------|----------------|----------------|
| **Security Model** | Router firewall rules | User-based authentication |
| **Access Control** | IP/Port based | Certificate + credential based |
| **Exposed Attack Surface** | Multiple ports | Single VPN port (1194) |
| **User Management** | Manual router config | Centralized web interface |
| **Audit Trail** | Router logs only | Complete user activity logs |
| **Scalability** | Manual per-service | Centralized user management |
| **Remote Development** | Limited to exposed services | Full network access |

---

## PHẦN B: INFRASTRUCTURE SETUP

### B.1 VM Preparation:

#### B.1.1 Tạo VM cho OpenVPN Server:
```bash
# SSH vào ESXi
ssh root@192.168.1.50

# VM specifications:
# - Name: ovpm-server
# - OS: Ubuntu 22.04 LTS
# - CPU: 2 cores
# - RAM: 2GB
# - Disk: 20GB
# - Network: VM Network (same as other VMs)
```

#### B.1.2 VM Network Configuration:
```bash
# Đặt static IP cho VPN server
# /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    ens160:
      dhcp4: false
      addresses:
        - 192.168.1.110/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

# Apply configuration
netplan apply
```

### B.2 Docker Installation:

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start Docker service
systemctl enable docker
systemctl start docker

# Verify installation
docker --version
docker-compose --version
```

---

## PHẦN C: OVPM INSTALLATION & CONFIGURATION

### C.1 OVPM Docker Setup:

#### C.1.1 Tạo directory structure:
```bash
mkdir -p /opt/ovpm
cd /opt/ovpm

# Create data directories
mkdir -p data/db data/pki data/openvpn data/logs
```

#### C.1.2 Docker Compose file:
```yaml
# /opt/ovpm/docker-compose.yml
version: '3.8'

services:
  ovpm:
    image: cad/ovpm:latest
    container_name: ovpm
    restart: unless-stopped
    environment:
      - OVPM_ADMIN_USERNAME=admin
      - OVPM_ADMIN_PASSWORD=YourSecurePassword123!
      - OVPM_DB_URL=sqlite:///data/ovpm.db
      - OVPM_HOSTNAME=192.168.1.110
      - OVPM_PORT=1194
      - OVPM_PROTOCOL=udp
      - OVPM_WEB_PORT=8080
    ports:
      - "1194:1194/udp"  # OpenVPN port
      - "8080:8080/tcp"  # Web interface
    volumes:
      - ./data/db:/data
      - ./data/pki:/etc/openvpn/pki
      - ./data/openvpn:/etc/openvpn
      - ./data/logs:/var/log/ovpm
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    networks:
      - ovpm-network

networks:
  ovpm-network:
    driver: bridge
```

#### C.1.3 Start OVPM:
```bash
cd /opt/ovpm

# Pull image và start
docker-compose pull
docker-compose up -d

# Check status
docker-compose ps
docker logs ovpm

# Wait for initialization (2-3 minutes)
sleep 180

# Test web interface
curl -I http://192.168.1.110:8080
```

### C.2 Initial Configuration:

#### C.2.1 Web Interface Access:
```
URL: http://192.168.1.110:8080
Username: admin
Password: YourSecurePassword123!
```

#### C.2.2 First-time Setup:
1. **Login** to OVPM web interface
2. **Create Server Certificate**: 
   - Server Name: `ovpm-homelab`
   - Server IP: `192.168.1.110`
   - VPN Network: `10.8.0.0/24`
3. **Network Settings**:
   - DNS Servers: `8.8.8.8, 8.8.4.4`
   - Routes: `192.168.1.0/24` (để access home network)

---

## PHẦN D: USER MANAGEMENT & CLIENT SETUP

### D.1 User Creation:

#### D.1.1 Via Web Interface:
1. Navigate to **Users** section
2. Click **Add User**
3. Configure user:
   ```
   Username: homelab-admin
   Password: UserSecurePass123!
   Admin: Yes (for first user)
   
   Network Access:
   - VPN Network: 10.8.0.0/24
   - LAN Routes: 192.168.1.0/24
   ```

#### D.1.2 Via Command Line:
```bash
# Access OVPM container
docker exec -it ovpm /bin/bash

# Create user với CLI
ovpm user create homelab-admin
ovpm user set homelab-admin --password "UserSecurePass123!"
ovpm user set homelab-admin --admin true

# List users
ovpm user list

# Download user config
ovpm user export homelab-admin > /tmp/homelab-admin.ovpn
```

### D.2 Client Configuration Download:

#### D.2.1 Via Web Interface:
1. Login to OVPM
2. Go to **Users** → **homelab-admin**
3. Click **Download Config**
4. Save `homelab-admin.ovpn` file

#### D.2.2 Via API:
```bash
# Get user config via API
curl -u admin:YourSecurePassword123! \
     http://192.168.1.110:8080/api/user/homelab-admin/config \
     -o homelab-admin.ovpn
```

---

## PHẦN E: CLIENT SETUP & CONNECTION

### E.1 macOS Client:

#### E.1.1 Install OpenVPN Connect:
```bash
# Via Homebrew
brew install --cask openvpn-connect

# Hoặc download từ OpenVPN website
# https://openvpn.net/client-connect-vpn-for-mac-os/
```

#### E.1.2 Import Configuration:
```bash
# Copy config file
cp homelab-admin.ovpn ~/Downloads/

# Import vào OpenVPN Connect:
# 1. Open OpenVPN Connect
# 2. Click "+" → "File"
# 3. Select homelab-admin.ovpn
# 4. Import
```

### E.2 iOS/iPhone Setup:

1. **Install App**: OpenVPN Connect từ App Store
2. **Transfer config**:
   - Email `homelab-admin.ovpn` tới iPhone
   - Hoặc AirDrop từ Mac
3. **Import**: Open file → "Copy to OpenVPN"
4. **Connect**: Tap profile → Connect

### E.3 Windows Client:

#### E.3.1 Install OpenVPN GUI:
```bash
# Download từ: https://openvpn.net/client-connect-vpn-for-windows/
# Hoặc use Chocolatey:
choco install openvpn
```

#### E.3.2 Import Configuration:
1. Copy `homelab-admin.ovpn` to `C:\Program Files\OpenVPN\config\`
2. Right-click OpenVPN GUI → "Import file"
3. Select config → Import

### E.4 Android Setup:

1. **Install**: OpenVPN for Android từ Google Play
2. **Import**: Share .ovpn file → Open with OpenVPN
3. **Import Profile** → **Connect**

---

## PHẦN F: ROUTER CONFIGURATION

### F.1 Port Forwarding for VPN:

#### F.1.1 Router Settings:
```
Service Name: OpenVPN-Server
External Port: 1194
Internal IP: 192.168.1.110
Internal Port: 1194
Protocol: UDP
Enable: Yes
```

#### F.1.2 Firewall Rules:
```bash
# VM firewall (Ubuntu)
ufw allow 1194/udp comment "OpenVPN"
ufw allow 8080/tcp comment "OVPM Web"
ufw allow from 192.168.1.0/24 to any port 22 comment "SSH from LAN"

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
```

### F.2 Testing Connection:

#### F.2.1 External Connectivity Test:
```bash
# From external network (mobile hotspot)
nmap -sU -p 1194 YOUR_PUBLIC_IP

# Should show: 1194/udp open
```

#### F.2.2 VPN Connection Test:
```bash
# After connecting VPN from external location
ping 10.8.0.1          # VPN gateway
ping 192.168.1.110      # VPN server
ping 192.168.1.100      # Other home services

# Test access to home services
curl http://192.168.1.100:80     # Internal web server
ssh root@192.168.1.50            # ESXi server
```

---

## PHẦN G: SECURITY CONFIGURATION

### G.1 PKI Certificate Management:

#### G.1.1 Certificate Authority Security:
```bash
# Backup CA certificates
docker exec ovpm tar -czf /tmp/ovpm-pki-backup.tar.gz /etc/openvpn/pki
docker cp ovpm:/tmp/ovpm-pki-backup.tar.gz ./ovpm-pki-backup-$(date +%Y%m%d).tar.gz

# Secure backup location
chmod 600 ovpm-pki-backup-*.tar.gz
```

#### G.1.2 Certificate Revocation:
```bash
# Via Web Interface:
# Users → Select User → Revoke Certificate

# Via CLI:
docker exec -it ovpm ovpm user revoke username

# Generate new CRL
docker exec ovpm ovpm pki crl-gen
```

### G.2 Access Control Lists:

#### G.2.1 User-specific Routes:
```bash
# Different users có thể có different network access
# Admin user: Full access
ovpm user set admin-user --route "192.168.1.0/24,10.0.0.0/8"

# Regular user: Limited access
ovpm user set regular-user --route "192.168.1.100/32"  # Only web server

# Developer: Development network access
ovpm user set dev-user --route "192.168.1.0/24,172.16.0.0/16"
```

#### G.2.2 Time-based Access:
```bash
# OVPM có built-in time restrictions
# User Settings → Access Hours
# Ví dụ: 9:00-18:00, Monday-Friday
```

### G.3 Monitoring & Logging:

#### G.3.1 Connection Monitoring:
```bash
# Real-time connections
docker exec ovpm ovpm user list --connected

# Connection logs
docker logs ovpm | grep "CLIENT_CONNECT"
docker logs ovpm | grep "CLIENT_DISCONNECT"

# Bandwidth usage
docker exec ovpm cat /var/log/ovpm/bandwidth.log
```

#### G.3.2 Security Logs:
```bash
# Failed authentication attempts
docker logs ovpm | grep "AUTH_FAILED"

# Certificate issues
docker logs ovpm | grep "TLS_ERROR"

# Export logs for analysis
docker logs ovpm > ovpm-logs-$(date +%Y%m%d).log
```

---

## PHẦN H: ADVANCED AUTOMATION

### H.1 Tích hợp với Infrastructure Automation:

#### H.1.1 Enhanced Wake-Server Function:
**Thêm vào `~/.zshrc`:**
```bash
# Complete automation: WOL → VPN → Services
wake-and-connect-vpn() {
    echo "[INFO] Starting complete home lab connection..."
    
    # 1. Wake server
    wake-server
    
    # 2. Wait for VPN server
    echo "[INFO] Waiting for VPN server startup..."
    sleep 90
    
    # 3. Test VPN server accessibility
    VPN_SERVER="YOUR_PUBLIC_IP"
    if nc -uz $VPN_SERVER 1194; then
        echo "[SUCCESS] VPN server accessible"
        
        # 4. Connect VPN (macOS)
        osascript -e 'tell application "OpenVPN Connect" to connect "homelab-admin"'
        echo "[INFO] VPN connection initiated"
        
        # 5. Wait for VPN connection
        sleep 15
        
        # 6. Test internal services via VPN
        if ping -c 2 192.168.1.100 > /dev/null 2>&1; then
            echo "[SUCCESS] Home lab accessible via VPN!"
            echo "[INFO] Available services:"
            echo "  ESXi: https://192.168.1.50"
            echo "  Web Server: http://192.168.1.100"
            echo "  OVPM: http://192.168.1.110:8080"
        else
            echo "[WARNING] VPN connected but services not accessible"
        fi
    else
        echo "[ERROR] VPN server not accessible"
    fi
}

# Disconnect function
disconnect-vpn() {
    osascript -e 'tell application "OpenVPN Connect" to disconnect "homelab-admin"'
    echo "[INFO] VPN disconnected"
}
```

#### H.1.2 User Management Automation:
```bash
#!/bin/bash
# ovpm-user-manager.sh

OVPM_HOST="192.168.1.110:8080"
OVPM_USER="admin"
OVPM_PASS="YourSecurePassword123!"

# Function to create user
create_vpn_user() {
    local username=$1
    local password=$2
    local admin=${3:-false}
    
    echo "Creating VPN user: $username"
    
    # Create user via API
    curl -u "$OVPM_USER:$OVPM_PASS" \
         -X POST \
         -H "Content-Type: application/json" \
         -d "{
             \"username\": \"$username\",
             \"password\": \"$password\",
             \"admin\": $admin
         }" \
         "http://$OVPM_HOST/api/user"
    
    # Download config
    curl -u "$OVPM_USER:$OVPM_PASS" \
         "http://$OVPM_HOST/api/user/$username/config" \
         -o "${username}.ovpn"
    
    echo "Config file saved: ${username}.ovpn"
}

# Function to revoke user
revoke_vpn_user() {
    local username=$1
    
    echo "Revoking VPN user: $username"
    
    curl -u "$OVPM_USER:$OVPM_PASS" \
         -X DELETE \
         "http://$OVPM_HOST/api/user/$username"
}

# Usage examples:
# create_vpn_user "john-doe" "SecurePass123!" false
# revoke_vpn_user "john-doe"
```

### H.2 Monitoring & Alerting:

#### H.2.1 VPN Health Check:
```bash
#!/bin/bash
# vpn-health-check.sh

VPN_SERVER="192.168.1.110"
PUBLIC_IP="YOUR_PUBLIC_IP"
LOG_FILE="/var/log/vpn-health.log"

# Check internal VPN server
check_internal() {
    if curl -s --connect-timeout 5 http://$VPN_SERVER:8080/health > /dev/null; then
        echo "$(date): ✅ VPN internal health - OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): ❌ VPN internal health - FAILED" >> $LOG_FILE
        return 1
    fi
}

# Check external VPN port
check_external() {
    if nc -uz $PUBLIC_IP 1194 2>/dev/null; then
        echo "$(date): ✅ VPN external port - OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): ❌ VPN external port - FAILED" >> $LOG_FILE
        return 1
    fi
}

# Check connected users
check_users() {
    local user_count=$(docker exec ovpm ovpm user list --connected | wc -l)
    echo "$(date): 📊 Connected users: $user_count" >> $LOG_FILE
}

# Main health check
main() {
    echo "$(date): Starting VPN health check" >> $LOG_FILE
    
    check_internal
    check_external
    check_users
    
    echo "$(date): Health check completed" >> $LOG_FILE
}

# Run health check
main
```

#### H.2.2 Certificate Expiry Monitoring:
```bash
#!/bin/bash
# cert-expiry-check.sh

WARN_DAYS=30
CRIT_DAYS=7

# Check server certificate
check_server_cert() {
    local cert_file="/opt/ovpm/data/pki/issued/server.crt"
    
    if [ -f "$cert_file" ]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ $days_until_expiry -lt $CRIT_DAYS ]; then
            echo "🚨 CRITICAL: Server certificate expires in $days_until_expiry days!"
        elif [ $days_until_expiry -lt $WARN_DAYS ]; then
            echo "⚠️  WARNING: Server certificate expires in $days_until_expiry days"
        else
            echo "✅ Server certificate valid for $days_until_expiry days"
        fi
    fi
}

check_server_cert
```

---

## 🎯 TÓM TẮT & BEST PRACTICES

### ✅ DevOps Learning Outcomes:

**Enterprise Security**: PKI infrastructure, certificate management, authentication  
**Network Architecture**: VPN tunneling, routing, network segmentation  
**User Management**: RBAC, access control, audit trails  
**Infrastructure as Code**: API automation, configuration management  
**Monitoring & Observability**: Health checks, logging, alerting  
**Production Operations**: Backup, disaster recovery, security hardening  

### 📋 Production-Ready Checklist:

- [ ] **PKI Security**: CA certificates backed up securely
- [ ] **User Management**: Clear RBAC policies, regular access reviews
- [ ] **Network Security**: Firewall rules, network segmentation
- [ ] **Monitoring**: Health checks, log aggregation, alerting
- [ ] **Backup**: Regular config and certificate backups
- [ ] **Documentation**: Network topology, user guides, procedures
- [ ] **Incident Response**: Revocation procedures, emergency access
- [ ] **Compliance**: Log retention, access audit trails

### 🔒 Security Best Practices:

```bash
# Recommended network architecture:
# Public Internet
#     ↓ (Port 1194/UDP only)
# Router with VPN port forwarding
#     ↓
# VPN Server (192.168.1.110)
#     ↓ (Encrypted tunnel)
# All internal services (192.168.1.x)
```

### 🚀 Complete Automation Journey:

**Level 1: Hardware Automation**
- ✅ [Wake On LAN](Wake-On-LAN.md) - Remote server power management

**Level 2: Application Automation**  
- ✅ [ESXi VM Autostart](ESXi-VM-Autostart.md) - Automatic service startup

**Level 3: Network Exposure**
- ✅ [Port Forwarding](Port-Forwarding.md) - Basic service exposure

**Level 4: Enterprise Security** (Current)
- ✅ **OpenVPN Server** - Secure remote access

**Level 5: Container Orchestration** (Next)
- 🎯 **Kubernetes/Docker Swarm** - Modern deployment patterns

---

## 🔗 Next Steps: Modern Infrastructure

VPN Server mang lại **enterprise-grade security** cho home lab. Bước tiếp theo trong DevOps evolution là **containerization và orchestration** cho modern deployment patterns.

### 🎯 Recommended Next Learning:

#### **Container Orchestration với Kubernetes**
**Current state**: 
```
WOL → Auto VMs → Services → Secure VPN Access
```

**Next level**: 
```
WOL → Auto VMs → Container Orchestration → Secure DevOps Platform
```

**What you'll learn**:
- ✅ **Kubernetes Fundamentals**: Pods, Services, Deployments
- ✅ **GitOps Workflows**: Infrastructure as Code, CI/CD pipelines  
- ✅ **Service Mesh**: Advanced networking, observability, security
- ✅ **Cloud-Native Patterns**: Microservices, scaling, resilience

#### **Alternative Path: Infrastructure as Code**
- **Terraform**: Infrastructure provisioning và management
- **Ansible**: Configuration management và automation
- **GitLab CI/CD**: Complete DevOps platform integration

**Perfect progression**: Manual infrastructure → Secure access → Automated infrastructure → Cloud-native DevOps! 🚀 