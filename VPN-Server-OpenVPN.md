# OpenVPN Server với OVPM - Hướng Dẫn Chi Tiết

## 🎯 Giới thiệu OVPM

**OVPM (OpenVPN Management Server)** là công cụ quản lý OpenVPN server hiện đại với giao diện web và command line. OVPM giúp triển khai và quản lý VPN server một cách dễ dàng, phù hợp cho môi trường DevOps home lab.

### ✨ Tính năng chính của OVPM

- 🖥️ **Command Line Interface (CLI)** - Quản lý hoàn toàn qua terminal
- 🌐 **Web User Interface** - Giao diện web trực quan trên port 8080
- 👥 **User Management** - Tạo, xóa, cập nhật VPN users với quyền admin
- 🌍 **Network Management** - Quản lý mạng và routing cho VPN
- 📁 **Client Profile Generation** - Tự động tạo file .ovpn cho clients
- 🔄 **Import/Export/Backup** - Sao lưu và khôi phục cấu hình
- 📊 **API Support** - REST và gRPC APIs cho automation
- 📈 **Monitoring & Quota** - Giám sát và giới hạn băng thông (upcoming)

### 🏗️ Kiến trúc OVPM

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OVPM CLI      │    │  OVPM Web UI    │    │   OpenVPN       │
│  (ovpm command) │    │  (Port 8080)    │    │  (Port 1197)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   OVPMD Daemon  │
                    │  (Management)   │
                    └─────────────────┘
```

### 🎯 Tại sao chọn OVPM cho DevOps?

**🚀 Triển khai nhanh**: Setup VPN server trong vài phút thay vì hàng giờ cấu hình manual

**🎮 Quản lý dễ dàng**: Web interface + CLI cho mọi tác vụ quản lý

**🔐 Bảo mật enterprise**: PKI certificates, user authentication, network isolation

**📱 Multi-platform**: Tạo .ovpn profiles cho Windows, macOS, iOS, Android

**🔧 DevOps-friendly**: APIs để tích hợp vào automation workflows

---

## 📋 Yêu cầu hệ thống

### Phần cứng tối thiểu:
- **CPU**: 1 core (2 cores khuyến nghị)
- **RAM**: 512MB (1GB khuyến nghị) 
- **Disk**: 1GB free space
- **Network**: Static IP address

### Phần mềm:
- **OS**: Ubuntu 16.04+ / CentOS 7+ / Debian 9+
- **OpenVPN**: Version 2.3.3 trở lên
- **Dependencies**: iptables, systemd

### Mạng:
- **Server IP**: `192.168.1.210` (static)
- **VPN Subnet**: `10.9.0.0/24` (default)
- **LAN Access**: `192.168.1.0/24`
- **Ports**: 1197/UDP (VPN), 8080/TCP (Web UI)

---

## 🚀 Cài đặt OVPM

### Phương pháp 1: Cài đặt từ DEB Package (Ubuntu/Debian)

**✅ Khuyến nghị cho Ubuntu 16.04+**

```bash
# 1. Thêm OVPM Repository
sudo sh -c 'echo "deb [trusted=yes] https://cad.github.io/ovpm/deb/ ovpm main" >> /etc/apt/sources.list'

# 2. Cập nhật package list
sudo apt update

# 3. Cài đặt OVPM
sudo apt install ovpm

# 4. Enable và start OVPMD service
sudo systemctl start ovpmd
sudo systemctl enable ovpmd

# 5. Kiểm tra service status
sudo systemctl status ovpmd
```

### Phương pháp 2: Cài đặt từ RPM Package (CentOS/Fedora)

```bash
# 1. Cài đặt dependencies
sudo yum install yum-utils epel-release -y

# 2. Thêm OVPM Repository
sudo yum-config-manager --add-repo https://cad.github.io/ovpm/rpm/ovpm.repo

# 3. Cài đặt OVPM
sudo yum install ovpm

# 4. Enable và start service
sudo systemctl start ovpmd
sudo systemctl enable ovpmd
```

### Phương pháp 3: Cài đặt từ Source Code

```bash
# 1. Cài đặt Go (nếu chưa có)
sudo apt install golang-go

# 2. Install OVPM từ source
go get -u github.com/cad/ovpm/...

# 3. Tạo users và groups cần thiết
sudo useradd nobody
sudo groupadd nogroup

# 4. Chạy OVPMD daemon
sudo ovpmd
```

### ✅ Xác minh cài đặt thành công

```bash
# Kiểm tra OVPM version
ovpm --version

# Kiểm tra OVPMD service
sudo systemctl status ovpmd

# Test OVPM command
ovpm --help
```

---

## ⚙️ Khởi tạo VPN Server

### Bước 1: Initialize VPN Server

```bash
# Khởi tạo VPN server với hostname tùy chỉnh
sudo ovpm vpn init --hostname vpn.yourdomain.com

# Output mong đợi:
# INFO[0004] ovpm server initialized
```

**Lệnh này sẽ:**
- Tạo Certificate Authority (CA)
- Generate server certificates
- Khởi tạo OpenVPN configuration
- Setup database để lưu users
- Tạo default VPN network (10.9.0.0/24)

### Bước 2: Cấu hình VPN Network và DNS

```bash
# Cấu hình để VPN clients truy cập LAN
sudo ovpm vpn update --net "10.9.0.0/24" --dns "192.168.1.1"

# Cập nhật port tùy chỉnh (nếu cần)
sudo ovpm vpn update --port 1197 --hostname vpn.yourdomain.com
```

### ⚠️ **Quan trọng: DNS Configuration trong OVPM**

**🚨 OVPM chỉ hỗ trợ MỘT DNS server duy nhất:**

```bash
# ✅ CÚ PHÁP ĐÚNG - Một DNS server
sudo ovpm vpn update --dns "192.168.1.1"
sudo ovpm vpn update --dns "8.8.8.8"

# ❌ CÚ PHÁP SAI - Multiple DNS servers
sudo ovpm vpn update --dns "192.168.1.1,8.8.8.8"
# Error: '192.168.1.1,8.8.8.8' is not an IPv4 address
```

**💡 Workaround cho Multiple DNS:**
Để có multiple DNS servers, bạn cần sửa file OpenVPN config sau khi OVPM generate:

```bash
# 1. Xem file config hiện tại
sudo cat /var/db/ovpm/server.conf | grep "push.*DNS"

# 2. Thêm DNS thứ hai manually (sau khi OVPM update)
echo 'push "dhcp-option DNS 8.8.8.8"' | sudo tee -a /var/db/ovpm/server.conf

# 3. Restart OpenVPN (không restart ovpmd để giữ config)
sudo systemctl restart openvpn@server
```

### Bước 3: Kiểm tra VPN Server Status

```bash
# Xem trạng thái VPN server
sudo ovpm vpn status
```

**Output sẽ hiển thị:**
```
VPN Server Status:
Hostname: vpn.yourdomain.com
Port: 1197/UDP  
Network: 10.9.0.0/24
DNS: 192.168.1.1
Status: Running
```

---

## 👥 Quản lý Users

### Tạo VPN Users

#### Tạo Admin User
```bash
# Tạo user với quyền admin
sudo ovpm user create -u admin -p AdminPassword123! --admin

# Tạo user thông thường
sudo ovpm user create -u joe -p verySecretPassword
```

#### Tạo Multiple Users cho Database Access
```bash
# Database Administrator
sudo ovpm user create -u dbadmin -p DbAdmin2024!

# Developer
sudo ovpm user create -u developer -p Dev2024!

# QA Tester  
sudo ovpm user create -u qatester -p QA2024!
```

### Liệt kê và xem thông tin Users

```bash
# Liệt kê tất cả users
sudo ovpm user list
```

**Output:**
```
+---+-----------+--------------+--------------------------------+-----------+---------+
| # | USERNAME  |      IP      |           CREATED AT           | VALID CRT | PUSH GW |
+---+-----------+--------------+--------------------------------+-----------+---------+
| 1 | admin     | 10.9.0.2/24  | Wed Oct  4 10:21:29 +0300 2024 | true      | true    |
| 2 | dbadmin   | 10.9.0.3/24  | Wed Oct  4 10:22:15 +0300 2024 | true      | true    |
| 3 | developer | 10.9.0.4/24  | Wed Oct  4 10:23:01 +0300 2024 | true      | true    |
+---+-----------+--------------+--------------------------------+-----------+---------+
```

```bash
# Xem chi tiết một user
sudo ovpm user show -u dbadmin
```

### Cập nhật User Settings

#### Thay đổi Password
```bash
# Đổi password cho user
sudo ovpm user update -u joe --password NewPassword2024!
```

#### Cấp/Thu hồi quyền Admin
```bash
# Cấp quyền admin
sudo ovpm user update -u dbadmin --admin

# Thu hồi quyền admin
sudo ovpm user update -u dbadmin --no-admin
```

#### Cấu hình Static IP cho User
```bash
# Gán IP tĩnh cho user
sudo ovpm user update -u dbadmin --static 10.9.0.50

# Chuyển về dynamic IP
sudo ovpm user update -u dbadmin --no-static
```

#### Cấu hình Gateway Routing
```bash
# Push VPN server làm default gateway (route all traffic)
sudo ovpm user update -u developer --gw

# Chỉ route traffic đến VPN network (không route internet)
sudo ovpm user update -u developer --no-gw
```

### Xóa Users

```bash
# Xóa user (cẩn thận!)
sudo ovpm user delete -u username
```

---

## 📁 Tạo Client Profiles (.ovpn files)

### Generate .ovpn files cho Users

```bash
# Tạo thư mục lưu trữ configs
mkdir -p /home/$(whoami)/vpn-configs/

# Tạo .ovpn file cho database admin
sudo ovpm user genconfig -u dbadmin -o /home/$(whoami)/vpn-configs/

# Tạo .ovpn file cho developer
sudo ovpm user genconfig -u developer -o /home/$(whoami)/vpn-configs/

# Tạo cho tất cả users
sudo ovpm user genconfig -u admin -o /home/$(whoami)/vpn-configs/
```

### Kiểm tra files đã tạo

```bash
# Liệt kê files .ovpn
ls -la /home/$(whoami)/vpn-configs/*.ovpn

# Xem nội dung file .ovpn
cat /home/$(whoami)/vpn-configs/dbadmin.ovpn
```

### Cấu trúc file .ovpn mẫu

```ini
client
dev tun
proto udp
remote vpn.yourdomain.com 1197
resolv-retry infinite
nobind
persist-key
persist-tun
ca [inline]
cert [inline]  
key [inline]
verb 3

# Routes để truy cập LAN (được tự động thêm)
route 192.168.1.0 255.255.255.0

# DNS settings
dhcp-option DNS 192.168.1.1
dhcp-option DNS 8.8.8.8
```

---

## 🌐 Web Interface Management

### Truy cập Web UI

#### Phương pháp 1: Truy cập trực tiếp
```bash
# Mở firewall cho port 8080
sudo ufw allow 8080/tcp comment "OVPM Web Interface"

# Truy cập qua browser:
# http://vpn.yourdomain.com:8080
# hoặc http://192.168.1.210:8080
```

#### Phương pháp 2: SSH Port Forwarding (Bảo mật)
```bash
# Từ máy local, tạo SSH tunnel
ssh user@192.168.1.210 -L 9000:127.0.0.1:8080

# Sau đó truy cập: http://localhost:9000
```

### Authentication trong Web UI

**🔐 Authorization Rules:**
- **External IP access**: Yêu cầu login với user/password
- **Loopback access (127.0.0.1)**: Bypass authentication (admin access)

**🚀 First-time Access:**
```bash
# Nếu chưa có admin user, tạo qua CLI
sudo ovpm user create -u webadmin -p WebAdmin2024! --admin

# Hoặc dùng SSH port forwarding để bypass authentication
ssh user@192.168.1.210 -L 9000:127.0.0.1:8080
# Browser: http://localhost:9000
```

### Các tính năng trong Web UI

**Dashboard:**
- VPN server status và thống kê
- Active connections real-time
- System resources monitoring

**User Management:**
- Tạo/xóa/sửa users graphically
- Download .ovpn files trực tiếp
- User activity monitoring

**Network Settings:**
- VPN network configuration
- Routes và DNS settings
- Firewall rules

**System Logs:**
- Connection logs
- Error troubleshooting
- Audit trail

---

## 🔧 Network Configuration

### Cấu hình mạng cho LAN Access

#### Enable IP Forwarding
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Kiểm tra
cat /proc/sys/net/ipv4/ip_forward  # Phải là 1
```

#### Cấu hình Firewall Rules

```bash
# Mở ports cho VPN
sudo ufw allow 1197/udp comment "OpenVPN Server"
sudo ufw allow 8080/tcp comment "OVPM Web Interface"

# Cho phép traffic giữa VPN và LAN
sudo ufw allow from 10.9.0.0/24 to 192.168.1.0/24
sudo ufw allow from 192.168.1.0/24 to 10.9.0.0/24
```

#### Setup NAT và Routing

```bash
# NAT cho VPN clients truy cập LAN
sudo iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -d 192.168.1.0/24 -j MASQUERADE

# Forward rules
sudo iptables -A FORWARD -s 10.9.0.0/24 -d 192.168.1.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.1.0/24 -d 10.9.0.0/24 -j ACCEPT

# Lưu iptables rules
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
```

### Network Management với OVPM

#### Thêm Custom Routes
```bash
# Thêm route cho database subnet
sudo ovpm net add --name "database-subnet" --net "192.168.1.0/24" --via "192.168.1.1"

# Add additional routes
sudo ovpm net add --name "server-subnet" --net "192.168.1.200/29" --via "192.168.1.1"

# Liệt kê routes
sudo ovpm net list
```

#### Cập nhật DNS Settings
```bash
# Update DNS server cho VPN clients (chỉ một DNS)
sudo ovpm vpn update --dns "192.168.1.1"

# Hoặc sử dụng public DNS
sudo ovpm vpn update --dns "8.8.8.8"
```

**🔧 Multiple DNS Servers:**
Vì OVPM limitation, để có multiple DNS:

```bash
# 1. Set primary DNS via OVPM
sudo ovpm vpn update --dns "192.168.1.1"

# 2. Add secondary DNS manually
echo 'push "dhcp-option DNS 8.8.8.8"' | sudo tee -a /var/db/ovpm/server.conf
echo 'push "dhcp-option DNS 8.8.4.4"' | sudo tee -a /var/db/ovpm/server.conf

# 3. Restart OpenVPN service only
sudo systemctl restart openvpn@server
```

---

## 🔍 Monitoring và Troubleshooting

### Kiểm tra VPN Server Status

```bash
# OVPM server status
sudo ovpm vpn status

# OVPMD daemon status
sudo systemctl status ovpmd

# OpenVPN processes
sudo ps aux | grep openvpn

# Network ports listening
sudo netstat -tulpn | grep -E "(1197|8080)"
sudo ss -tulpn | grep -E "(1197|8080)"
```

### Xem Logs và Debug

```bash
# OVPMD daemon logs
sudo journalctl -u ovpmd -n 50 -f

# OpenVPN server logs
sudo tail -f /var/log/openvpn/server.log

# System logs
sudo tail -f /var/log/syslog | grep ovpm
```

### Monitor Active Connections

```bash
# Xem connected users
sudo ovpm user list

# Chi tiết connections
sudo cat /var/log/openvpn/openvpn-status.log

# Real-time connection monitoring
watch "sudo ovpm user list"
```

### Common Troubleshooting Commands

```bash
# Test DNS resolution
nslookup vpn.yourdomain.com
dig vpn.yourdomain.com

# Test VPN port connectivity
sudo netstat -tulpn | grep 1197
sudo lsof -i :1197

# Test routing
ip route show
route -n

# Test iptables rules
sudo iptables -L -v -n
sudo iptables -t nat -L -v -n
```

### 🔧 DNS Issues trong VPN:
```bash
# Kiểm tra DNS settings trong VPN config
sudo grep -i dns /var/db/ovpm/server.conf

# Fix DNS nếu cần multiple servers
sudo ovpm vpn update --dns "192.168.1.1"  # Primary
echo 'push "dhcp-option DNS 8.8.8.8"' | sudo tee -a /var/db/ovpm/server.conf
sudo systemctl restart openvpn@server
```

---

## 🛠️ Advanced Configuration

### Custom OpenVPN Settings

#### Cấu hình via OVPM commands:

```bash
# Update server settings
sudo ovpm vpn update --port 1197 --proto udp
sudo ovpm vpn update --net "10.9.0.0/24" --dns "192.168.1.1"

# Enable/disable compression (deprecated trong newer versions)
sudo ovpm vpn update --enable-use-lzo  # Not recommended
```

**⚠️ DNS Limitation Fix:**
```bash
# Sau khi set primary DNS qua OVPM
sudo ovpm vpn update --dns "192.168.1.1"

# Thêm secondary DNS servers manually
sudo cat >> /var/db/ovpm/server.conf << 'EOF'
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
EOF

# Restart OpenVPN để apply
sudo systemctl restart openvpn@server
```

### Backup và Restore

#### Backup OVPM Configuration
```bash
# Backup database và certificates
sudo tar -czf /backup/ovpm-config-$(date +%Y%m%d).tar.gz /var/db/ovpm/

# Backup individual components
sudo cp /var/db/ovpm/db.sqlite3 /backup/ovpm-users-$(date +%Y%m%d).db
sudo cp -r /var/db/ovpm/pki/ /backup/ovpm-pki-$(date +%Y%m%d)/
```

#### Export/Import Users
```bash
# Export tất cả user configs
for user in $(sudo ovpm user list --json | jq -r '.[].username'); do
    sudo ovpm user genconfig -u $user -o /backup/user-configs/
done

# Backup script
cat > /home/$(whoami)/backup-ovpm.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/ovpm-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup database và config
sudo cp -r /var/db/ovpm/ $BACKUP_DIR/
sudo ovpm user list > $BACKUP_DIR/users-list.txt

# Generate all user configs
mkdir -p $BACKUP_DIR/user-configs
for user in $(sudo ovpm user list --format json | jq -r '.[].username'); do
    sudo ovpm user genconfig -u $user -o $BACKUP_DIR/user-configs/
done

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x /home/$(whoami)/backup-ovpm.sh
```

### Performance Tuning

#### Optimize cho nhiều concurrent connections:

```bash
# Increase file descriptor limits
echo "ovpm soft nofile 4096" | sudo tee -a /etc/security/limits.conf
echo "ovpm hard nofile 8192" | sudo tee -a /etc/security/limits.conf

# Systemd service limits
sudo mkdir -p /etc/systemd/system/ovpmd.service.d/
cat > /tmp/limits.conf << 'EOF'
[Service]
LimitNOFILE=8192
EOF
sudo mv /tmp/limits.conf /etc/systemd/system/ovpmd.service.d/

# Reload systemd và restart
sudo systemctl daemon-reload
sudo systemctl restart ovpmd
```

---

## 🔐 Security Best Practices

### Certificate Management

```bash
# Xem certificate details
sudo ovpm vpn show-ca
sudo ovpm vpn show-cert

# Revoke user certificate (nếu user bị compromise)
sudo ovpm user revoke -u compromised-user

# Generate new CA (extreme cases)
# sudo ovpm vpn reinit --hostname vpn.yourdomain.com
```

### Access Control

```bash
# Restrict Web UI access
sudo ufw delete allow 8080/tcp
sudo ufw allow from 192.168.1.0/24 to any port 8080

# VPN port security
sudo ufw allow from any to any port 1197 proto udp

# SSH access hardening
sudo ufw allow from 192.168.1.0/24 to any port 22
```

### Audit và Monitoring

```bash
# Enable detailed logging
sudo ovpm vpn update --log-level debug

# Log rotation setup
cat > /etc/logrotate.d/ovpm << 'EOF'
/var/log/openvpn/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload ovpmd > /dev/null 2>&1 || true
    endscript
}
EOF
```

---

## 🚨 Troubleshooting Guide

### Vấn đề thường gặp và cách khắc phục

#### 1. Clients không connect được VPN

**Triệu chứng:**
```
Connection timeout hoặc authentication failed
```

**Khắc phục:**
```bash
# Kiểm tra VPN server đang chạy
sudo systemctl status ovpmd
sudo ovpm vpn status

# Kiểm tra port listening
sudo netstat -tulpn | grep 1197

# Kiểm tra firewall
sudo ufw status
sudo iptables -L -v -n

# Test từ client
telnet vpn.yourdomain.com 1197
```

#### 2. Connect VPN thành công nhưng không truy cập được LAN

**Triệu chứng:**
```
VPN connected, assigned IP 10.9.0.x
Không ping được 192.168.1.x
```

**Khắc phục:**
```bash
# Kiểm tra IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Phải = 1

# Kiểm tra routes
sudo ovpm net list
ip route show

# Kiểm tra iptables NAT rules
sudo iptables -t nat -L -v -n | grep MASQUERADE

# Fix NAT rules
sudo iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -d 192.168.1.0/24 -j MASQUERADE
```

**🔧 DNS Issues trong VPN:**
```bash
# Kiểm tra DNS settings trong VPN config
sudo grep -i dns /var/db/ovpm/server.conf

# Fix DNS nếu cần multiple servers
sudo ovpm vpn update --dns "192.168.1.1"  # Primary
echo 'push "dhcp-option DNS 8.8.8.8"' | sudo tee -a /var/db/ovpm/server.conf
sudo systemctl restart openvpn@server
```

#### 3. Web UI không accessible

**Triệu chứng:**
```
Connection refused trên port 8080
```

**Khắc phục:**
```bash
# Kiểm tra OVPMD running
sudo systemctl status ovpmd

# Kiểm tra port 8080
sudo netstat -tulpn | grep 8080
sudo lsof -i :8080

# Kiểm tra firewall
sudo ufw allow 8080/tcp

# Test local access
curl -I http://127.0.0.1:8080
curl -I http://192.168.1.210:8080
```

#### 4. OVPM commands không hoạt động

**Triệu chứng:**
```bash
$ ovpm user list
FATA[0000] rpc error: code = Unavailable desc = connection error
```

**Khắc phục:**
```bash
# Restart OVPMD daemon
sudo systemctl restart ovpmd
sudo systemctl status ovpmd

# Kiểm tra logs
sudo journalctl -u ovpmd -n 20

# Check permissions
ls -la /var/db/ovpm/
sudo chown -R ovpm:ovpm /var/db/ovpm/
```

#### 5. Certificate errors

**Triệu chứng:**
```
TLS handshake failed
Certificate verification error  
```

**Khắc phục:**
```bash
# Kiểm tra certificates
sudo ovpm vpn show-ca
sudo ovpm vpn show-cert

# Regenerate user certificate
sudo ovpm user delete -u problematic-user
sudo ovpm user create -u problematic-user -p newpassword

# Regenerate .ovpn file
sudo ovpm user genconfig -u problematic-user -o /home/$(whoami)/vpn-configs/
```

---

# 🏥 OVPM Health Checker

Comprehensive health monitoring system cho OpenVPN server với OVPM, kèm Discord webhook integration và detailed logging.

## 🎯 Features

- **Comprehensive Health Checks**: OVPM service, network connectivity, system resources
- **Discord Notifications**: Real-time alerts và hourly status reports
- **Vietnam Timezone Logging**: Logs với múi giờ Việt Nam (+7)
- **Automatic Scheduling**: Health checks mỗi tiếng tự động
- **Systemd Integration**: Chạy như system service với auto-start
- **Configurable Thresholds**: Custom warning levels cho các resources

## 📋 Health Check Items

### 🔧 Service Monitoring
- `ovpmd` service status với systemctl
- OpenVPN process monitoring với psutil
- Process CPU & memory usage chi tiết

### 🌐 Network Connectivity
- OpenVPN port (1197/UDP) listening check
- Web UI port (8080/TCP) response time monitoring
- DNS resolution cho VPN hostname

### 👥 VPN Status
- Total users configured trong OVPM
- Active VPN connections tracking
- User connection details và activity

### 💻 System Resources
- CPU usage với configurable thresholds
- Memory usage với warnings
- Disk usage cho system directories
- System uptime tracking

### 📊 Discord Notifications
- Real-time critical alerts với color coding
- Hourly status summaries với detailed embeds
- Color-coded status (🟢 Green/🟡 Yellow/🔴 Red)
- Rich embed messages với icons và metrics

## 🚀 Quick Start

### 1. Chuẩn bị Files

Từ thư mục project chứa folder `ovpm-healthcheck`:

```bash
# Copy files lên OVPM server
scp -r ovpm-healthcheck/ root@192.168.1.210:/home/tantai/healthcheck/

# Hoặc copy từng file
scp ovpm-healthcheck/* root@192.168.1.210:/home/tantai/healthcheck/
```

### 2. SSH vào Server và Setup

```bash
# SSH vào OVPM server
ssh root@192.168.1.210

# Di chuyển đến thư mục
cd /home/tantai/healthcheck

# Chạy automated setup script
chmod +x setup.sh
./setup.sh
```

### 3. Configure Discord Webhook

```bash
# Edit config file
nano ovpm_config.json

# Cập nhật Discord webhook URL:
{
    "discord_webhook": "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL",
    "ovpm_hostname": "vpn.yourdomain.com"
}
```

### 4. Service đã tự động được start

Setup script sẽ tự động:
- Cài đặt Python dependencies
- Tạo virtual environment
- Install systemd service
- Enable và start service

```bash
# Check service status
sudo systemctl status ovpm-health-checker

# View logs
sudo journalctl -u ovpm-health-checker -f
```

## ⚙️ Configuration

### Sample `ovpm_config.json`:

```json
{
    "discord_webhook": "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL",
    "ovpm_server_ip": "192.168.1.210",
    "ovpm_hostname": "vpn.yourdomain.com",
    "ovpm_port": 1197,
    "web_ui_port": 8080,
    "log_file": "/var/log/ovpm_health.log",
    "alert_thresholds": {
        "cpu_percent": 80,
        "memory_percent": 85,
        "disk_percent": 90,
        "response_time_ms": 5000
    },
    "notifications": {
        "send_hourly_status": true,
        "send_only_errors": false
    }
}
```

### Configuration Options:

| Setting | Description | Default |
|---------|-------------|---------|
| `discord_webhook` | Discord webhook URL cho notifications | Required |
| `ovpm_server_ip` | IP address của OVPM server | 192.168.1.210 |
| `ovpm_hostname` | Domain name cho VPN server | vpn.yourdomain.com |
| `ovpm_port` | OpenVPN port | 1197 |
| `web_ui_port` | OVPM Web UI port | 8080 |
| `log_file` | Path to health check log file | /var/log/ovpm_health.log |
| `alert_thresholds` | Warning thresholds cho resources | See above |
| `send_hourly_status` | Send status reports mỗi tiếng | true |
| `send_only_errors` | Chỉ send khi có errors | false |

## 📊 Discord Notifications

### Healthy Status Message:
```
🟢 OVPM Health Check - HEALTHY
🔧 Service Status: ✅ Running (2 OpenVPN processes)
👥 VPN Users: Total: 3, Active: 1
💻 CPU Usage: 15.3%
🌐 Network: OpenVPN: ✅ Listening, Web UI: ✅ Responding (120ms)
💾 Memory: 2.1GB/4GB (52.5%)
💽 Disk: 0.45GB/20GB (2.3%)
⏰ Uptime: 7d 14h 23m
🕐 Check Time: 2024-01-15 14:30:15 ICT+07
```

### Critical Alert:
```
🔴 OVPM Health Check - CRITICAL
🚨 Critical Issues Found:
- ❌ OVPMD service not running
- ❌ OpenVPN port not listening
- ⚠️ High CPU usage: 85.2%

💻 System Status:
- Memory: 3.4GB/4GB (85%)
- Web UI: ❌ Not responding
```

## 🔍 Monitoring & Troubleshooting

### Service Management:
```bash
# Check service status
sudo systemctl status ovpm-health-checker

# View real-time service logs
sudo journalctl -u ovpm-health-checker -f

# View health check logs với Vietnam timezone
tail -f /var/log/ovpm_health.log
```

### Manual Testing:
```bash
# Manual test run
cd /home/tantai/healthcheck
./venv/bin/python3 ovpm_health_checker.py

# One-time check without scheduling
python3 ovpm_health_checker.py --single-run
```

### Service Controls:
```bash
# Stop service
sudo systemctl stop ovpm-health-checker

# Restart service
sudo systemctl restart ovpm-health-checker

# Disable auto-start
sudo systemctl disable ovpm-health-checker

# Re-enable auto-start
sudo systemctl enable ovpm-health-checker
```

## 📁 File Structure

```
/home/tantai/healthcheck/
├── ovpm_health_checker.py     # Main health check script
├── ovpm_config.json           # Configuration file
├── requirements.txt           # Python dependencies
├── setup.sh                   # Automated setup script
├── ovpm-health-checker.service # Systemd service file
├── venv/                      # Python virtual environment
└── SETUP-GUIDE.md             # Detailed setup guide

/etc/systemd/system/
└── ovpm-health-checker.service   # Installed service file

/var/log/
└── ovpm_health.log            # Health check logs với Vietnam timezone
```

## 🛠️ Advanced Configuration

### Modify Alert Thresholds:
```json
{
    "alert_thresholds": {
        "cpu_percent": 70,        # Lower CPU threshold
        "memory_percent": 90,     # Higher memory threshold
        "disk_percent": 95,       # Higher disk threshold
        "response_time_ms": 3000  # Lower response time threshold
    }
}
```

### Change Check Frequency:
Edit trong `ovpm_health_checker.py`:
```python
# Change from hourly to every 30 minutes
schedule.every(30).minutes.do(run_health_check)
```
### Định dạng Discord Tùy chỉnh:
Script sử dụng rich embeds với:
- Mã màu dựa trên trạng thái sức khỏe
- Hiển thị múi giờ Việt Nam
- Số liệu chi tiết với các biểu tượng
- Thông tin giám sát tiến trình

## 🚨 Common Issues & Solutions

### 1. Service won't start:
```bash
# Check Python environment
cd /home/tantai/healthcheck
./venv/bin/python3 -c "import requests, psutil, schedule; print('All modules OK')"

# Check permissions
ls -la ovpm_health_checker.py
chmod +x ovpm_health_checker.py
```

### 2. Discord notifications not working:
```bash
# Test webhook manually
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message from OVPM server"}'

# Verify webhook URL trong config
grep discord_webhook ovpm_config.json
```

### 3. OVPM commands fail:
```