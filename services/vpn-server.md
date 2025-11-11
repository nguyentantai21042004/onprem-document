# OpenVPN Server với OVPM

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
3. [Cài đặt OVPM](#cài-đặt-ovpm)
4. [Khởi tạo VPN Server](#khởi-tạo-vpn-server)
5. [Quản lý Users](#quản-lý-users)
6. [Monitoring và Troubleshooting](#monitoring-và-troubleshooting)

## Giới thiệu

**OVPM (OpenVPN Management Server)** là công cụ quản lý OpenVPN server hiện đại với giao diện web và command line. OVPM giúp triển khai và quản lý VPN server một cách dễ dàng, phù hợp cho môi trường DevOps home lab.

### ✨ Tính năng chính của OVPM

- 🖥️ **Command Line Interface (CLI)** - Quản lý hoàn toàn qua terminal
- 🌐 **Web User Interface** - Giao diện web trực quan trên port 8080
- 👥 **User Management** - Tạo, xóa, cập nhật VPN users với quyền admin
- 🌍 **Network Management** - Quản lý mạng và routing cho VPN
- 📁 **Client Profile Generation** - Tự động tạo file .ovpn cho clients
- 🔄 **Import/Export/Backup** - Sao lưu và khôi phục cấu hình
- 📊 **API Support** - REST và gRPC APIs cho automation
- 📈 **Monitoring & Quota** - Giám sát và giới hạn băng thông

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

- **🚀 Triển khai nhanh**: Setup VPN server trong vài phút thay vì hàng giờ cấu hình manual
- **🎮 Quản lý dễ dàng**: Web interface + CLI cho mọi tác vụ quản lý
- **🔐 Bảo mật enterprise**: PKI certificates, user authentication, network isolation
- **📱 Multi-platform**: Tạo .ovpn profiles cho Windows, macOS, iOS, Android
- **🔧 DevOps-friendly**: APIs để tích hợp vào automation workflows

---

## Yêu cầu hệ thống

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

## Cài đặt OVPM

### Phương pháp: Cài đặt từ DEB Package (Ubuntu/Debian)

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

### ✅ Xác minh cài đặt thành công

```bash
# Kiểm tra OVPM version
ovpm --version

# Kiểm tra OVPMD service
sudo systemctl status ovpmd

# Test OVPM command
ovpm --help
```

**Expected Output:**
```
ovpm version 0.2.7
OVPM - OpenVPN Management Server
Built with love by Mustafa Arici
```

---

## Khởi tạo VPN Server

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

## Quản lý Users

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
# Xóa user
sudo ovpm user delete -u username

# Xóa user với force (không confirm)
sudo ovpm user delete -u username --force
```

### Tạo Client Configuration Files

```bash
# Tạo .ovpn file cho client
sudo ovpm user genconfig -u dbadmin

# Save to file
sudo ovpm user genconfig -u dbadmin > dbadmin.ovpn

# Hoặc export cho tất cả users
sudo ovpm user export --all
```

---

## Network Configuration

### Cấu hình Advanced Network

#### LAN Access Configuration
```bash
# Cho phép VPN clients truy cập LAN
sudo ovpm vpn update --net "10.9.0.0/24" --dns "192.168.1.1"

# Add routing cho LAN subnet
sudo ovpm route add --net "192.168.1.0/24" --gw "192.168.1.1"
```

#### Port và Protocol
```bash
# Thay đổi port (default: 1194)
sudo ovpm vpn update --port 1197

# Thay đổi protocol (UDP/TCP)
sudo ovpm vpn update --proto udp
```

### Firewall Configuration

#### UFW Rules
```bash
# Allow VPN port
sudo ufw allow 1197/udp

# Allow Web UI
sudo ufw allow 8080/tcp

# Allow SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

#### iptables Rules for NAT
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# NAT rule for VPN traffic
sudo iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o eth0 -j MASQUERADE

# Save iptables rules
sudo netfilter-persistent save
```

---

## Web Management Interface

### Truy cập Web UI

#### Enable Web UI
```bash
# Start web server
sudo ovpm webui start

# Enable web UI để start cùng system
sudo systemctl enable ovpm-webui
```

#### Truy cập URL
```
http://server-ip:8080
```

**Login credentials:**
- **Username**: admin user đã tạo
- **Password**: password của admin user

### Web UI Features

#### Dashboard
- **Server Status**: Running/Stopped
- **Connected Users**: Real-time connections
- **Network Overview**: VPN subnet, DNS settings
- **Certificate Info**: CA và server certificate status

#### User Management
- **Create User**: Web form để tạo user mới
- **Edit User**: Update password, permissions
- **Download Config**: Tải .ovpn file cho users
- **Delete User**: Remove users

#### Network Configuration
- **VPN Settings**: Port, protocol, network range
- **DNS Configuration**: Primary DNS server
- **Routes**: LAN routing configuration

---

## Monitoring và Troubleshooting

### Monitoring Tools

#### OVPM Status Commands
```bash
# Check VPN server status
sudo ovpm vpn status

# Check connected users
sudo ovpm user list --connected

# Check server logs
sudo ovpm logs
```

#### System Monitoring
```bash
# Check OpenVPN process
sudo systemctl status openvpn

# Check OVPM daemon
sudo systemctl status ovpmd

# Check network interfaces
ip addr show

# Check VPN interface
ip addr show tun0
```

### Log Files

#### OVPM Logs
```bash
# OVPM daemon logs
sudo journalctl -u ovpmd -f

# OpenVPN server logs
sudo tail -f /var/log/openvpn/server.log

# System logs
sudo tail -f /var/log/syslog | grep ovpm
```

#### Log Analysis
```bash
# Connected users log
grep "CONNECTION" /var/log/openvpn/server.log

# Authentication logs
grep "AUTH" /var/log/openvpn/server.log

# Error logs
grep "ERROR" /var/log/openvpn/server.log
```

### Common Issues & Solutions

#### 1. VPN Server không start
```bash
# Check service status
sudo systemctl status ovpmd

# Check OpenVPN configuration
sudo openvpn --config /etc/openvpn/server.conf --verb 3

# Check firewall
sudo ufw status
```

#### 2. Clients không kết nối được
```bash
# Check port accessibility
sudo netstat -unl | grep 1197

# Check firewall rules
sudo iptables -L -n

# Test from client
telnet server-ip 1197
```

#### 3. Không truy cập được LAN
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Check NAT rules
sudo iptables -t nat -L

# Check routing
ip route show
```

#### 4. DNS resolution issues
```bash
# Check DNS configuration
sudo ovpm vpn status | grep DNS

# Test DNS from client
nslookup google.com

# Check DNS forwarding
sudo netstat -unl | grep :53
```

### Performance Monitoring

#### Network Statistics
```bash
# Monitor VPN interface
sudo iftop -i tun0

# Check bandwidth usage
sudo vnstat -i tun0

# Monitor connections
sudo netstat -i tun0
```

#### Resource Usage
```bash
# CPU usage
top -p $(pgrep ovpmd)

# Memory usage
ps aux | grep ovpmd

# Disk usage
df -h
```

---

## Backup và Restore

### Backup Configuration

```bash
# Backup OVPM database
sudo ovpm backup --output ovpm-backup.tar.gz

# Backup OpenVPN configuration
sudo tar -czf openvpn-backup.tar.gz /etc/openvpn/

# Backup certificates
sudo tar -czf certs-backup.tar.gz /etc/ovpm/pki/
```

### Restore Configuration

```bash
# Restore OVPM database
sudo ovpm restore --input ovpm-backup.tar.gz

# Restore OpenVPN configuration
sudo tar -xzf openvpn-backup.tar.gz -C /

# Restart services
sudo systemctl restart ovpmd
sudo systemctl restart openvpn
```

### Automated Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-ovpm.sh

BACKUP_DIR="/backup/ovpm"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ovpm-backup-${DATE}.tar.gz"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Backup OVPM
sudo ovpm backup --output ${BACKUP_DIR}/${BACKUP_FILE}

# Backup OpenVPN config
sudo tar -czf ${BACKUP_DIR}/openvpn-${DATE}.tar.gz /etc/openvpn/

# Cleanup old backups (keep last 7 days)
find ${BACKUP_DIR} -name "ovpm-backup-*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

---

## Security Best Practices

### Certificate Management

```bash
# Check certificate expiry
sudo ovpm pki show

# Renew certificates
sudo ovpm pki renew

# Revoke user certificate
sudo ovpm user revoke -u username
```

### Access Control

```bash
# Limit concurrent connections
sudo ovpm vpn update --max-clients 50

# Enable duplicate connection prevention
sudo ovpm vpn update --no-duplicate-cn

# Set session timeout
sudo ovpm vpn update --keepalive 10,120
```

### Network Security

```bash
# Enable client-to-client communication
sudo ovpm vpn update --client-to-client

# Disable client-to-client communication
sudo ovpm vpn update --no-client-to-client

# Enable compression
sudo ovpm vpn update --comp-lzo
```

---

## Integration với Other Services

### Jenkins Integration

```bash
# Create VPN user for Jenkins
sudo ovpm user create -u jenkins -p JenkinsVPN2024!

# Generate config for Jenkins
sudo ovpm user genconfig -u jenkins > jenkins-vpn.ovpn

# Use in Jenkins pipeline
```

### Monitoring Integration

```bash
# Export metrics for Prometheus
sudo ovpm metrics --prometheus

# Create monitoring user
sudo ovpm user create -u monitoring -p MonitorVPN2024!

# Setup health check endpoint
curl http://localhost:8080/health
```

---

## Next Steps

Sau khi hoàn thành VPN Server setup, bạn có thể tiến tới:

1. **[Database Setup](databases.md)** - MongoDB & PostgreSQL clusters
2. **[Harbor Registry](harbor.md)** - Container registry
3. **[Monitoring Setup](monitoring.md)** - Prometheus & Grafana

---

## Tham khảo

- [OVPM Documentation](https://github.com/cad/ovpm)
- [OpenVPN Documentation](https://openvpn.net/community-resources/)
- [OpenVPN Security Guide](https://openvpn.net/vpn-server-resources/openvpn-security-advisory/)
- [PKI Best Practices](https://openvpn.net/vpn-server-resources/advanced-option-settings-on-the-command-line/) 