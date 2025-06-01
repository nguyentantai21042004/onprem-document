# OpenVPN Server với OVPM

## Giới thiệu

OpenVPN Server với OVPM là **bước advanced level** trong home lab DevOps journey. Sau khi đã có [Port Forwarding](Port-Forwarding.md) để expose services, VPN Server mang lại **enterprise-grade security** và **centralized access control** cho toàn bộ infrastructure.

### Tại sao OpenVPN quan trọng cho DevOps?

**Bảo mật doanh nghiệp**: PKI certificates, mã hóa, và xác thực - tiêu chuẩn trong môi trường production.

**Truy cập cơ sở dữ liệu**: Truy cập an toàn tới database VMs từ bất kỳ đâu.

**Kiến trúc Zero Trust**: Xác thực dựa trên người dùng thay vì truy cập dựa trên mạng.

**Quản lý tập trung**: Giao diện web để quản lý người dùng và cấu hình.

---

## Mục đích và cấu hình

Triển khai VPN Server riêng với các mục đích sau:

- **Truy cập mạng LAN từ xa**: Kết nối an toàn vào mạng nội bộ từ bất kỳ đâu
- **Truy cập các VM Database**: Kết nối trực tiếp đến các máy ảo đang chạy database trong mạng LAN  
- **Xuất file .ovpn**: Tạo file cấu hình VPN cho các thiết bị
- **Quản lý tập trung**: Sử dụng giao diện Web để quản lý người dùng và cấu hình

**Thông số server:**
- IP Server: `192.168.1.210`
- **Hostname VPN**: `vpn.yourdomain.com` (subdomain dành riêng cho VPN)
- Port OpenVPN: `1197/UDP`
- Port Web UI: `8080/TCP`
- Mạng LAN: `192.168.1.0/24`

---

## Chuẩn bị

Trước khi bắt đầu, đảm bảo bạn có:

1. **Hệ điều hành**: Ubuntu Server
2. **Quyền truy cập**: root (sudo)
3. **Phần mềm cần thiết**: `ufw`, `curl`, `systemd`, `iptables`
4. **Server IP**: 192.168.1.210 (đã cấu hình static)
5. **Domain và DNS**: Subdomain `vpn.yourdomain.com` đã trỏ về IP 192.168.1.210

---

## Bước 0: Cấu hình DNS cho VPN Subdomain

### Cấu hình DNS Record

Trước khi cài đặt OVPM, cần cấu hình DNS:

```bash
# Thêm một record vào NO-IP và đưa nó vào cấu hình của modem mạng:
# Sau đó tạo một record CNAME
# vpn.yourdomain.com -> 192.168.1.210
```

### Kiểm tra DNS resolution

```bash
# Test DNS từ server
nslookup vpn.yourdomain.com
dig vpn.yourdomain.com

# Test từ máy khác
ping vpn.yourdomain.com
```

---

## Bước 1: Cài đặt OVPM

### Thêm repository APT

```bash
# Add APT Repo
sudo sh -c 'echo "deb [trusted=yes] https://cad.github.io/ovpm/deb/ ovpm main" >> /etc/apt/sources.list'
sudo apt update

# Install OVPM
sudo apt install ovpm

# Enable and start ovpmd service
systemctl start ovpmd
systemctl enable ovpmd
```

### Kiểm tra service đã chạy

```bash
sudo systemctl status ovpmd
ovpm --help
```

---

## Bước 2: Khởi tạo VPN Server với cấu hình

### Khởi tạo VPN Server với subdomain và port tùy chỉnh

```bash
sudo ovpm vpn init --hostname vpn.yourdomain.com --port 1197
```

Lệnh này sẽ thực hiện:
- Tạo CA certificates
- Tạo server certificates cho subdomain `vpn.yourdomain.com`
- Khởi tạo OpenVPN server config với port 1197
- Setup database
- Cấu hình mạng cho truy cập LAN

### Cấu hình mạng LAN và routing

```bash
# Cấu hình để VPN client có thể truy cập mạng LAN
sudo ovpm vpn update --net "192.168.1.0/24" --dns "192.168.1.1,8.8.8.8"
```

---

## Bước 3: Kiểm tra VPN Server status

```bash
sudo ovpm vpn status
```

---

## Bước 4: Tạo user admin và users cho database access

### Tạo user admin

```bash
sudo ovpm user create -u admin -p AdminPassword123! --admin
```

### Tạo user cho Database Admin

```bash
sudo ovpm user create -u dbadmin -p DbAdmin123!
```

### Tạo user cho Developer

```bash
sudo ovpm user create -u developer -p Dev123!
```

### Liệt kê danh sách users đã tạo

```bash
sudo ovpm user list
```

---

## Bước 5: Tạo file .ovpn cho client

### Tạo file .ovpn cho database admin

```bash
sudo ovpm user genconfig -u dbadmin -o /home/$(whoami)/vpn-configs/
```

### Tạo file .ovpn cho developer

```bash
sudo ovpm user genconfig -u developer -o /home/$(whoami)/vpn-configs/
```

### Tạo thư mục và kiểm tra file

```bash
mkdir -p /home/$(whoami)/vpn-configs/
ls -la /home/$(whoami)/vpn-configs/*.ovpn
```

---

## Bước 6: Cấu hình Firewall & Network cho truy cập LAN

### Cấu hình UFW cho VPN và Web UI

```bash
# Mở port OpenVPN tùy chỉnh
sudo ufw allow 1197/udp comment "OpenVPN Server"

# Mở port Web UI
sudo ufw allow 8080/tcp comment "OVPM Web Interface"

# Cho phép traffic giữa VPN và LAN
sudo ufw allow from 10.8.0.0/24 to 192.168.1.0/24
```

### Enable IP Forwarding cho routing LAN

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Cấu hình iptables cho NAT và routing

```bash
# Cấu hình NAT cho VPN clients truy cập LAN
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 192.168.1.0/24 -j MASQUERADE

# Cho phép forward traffic
sudo iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.1.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 192.168.1.0/24 -d 10.8.0.0/24 -j ACCEPT

# Lưu iptables rules
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
```

### Kiểm tra IP Forwarding

```bash
cat /proc/sys/net/ipv4/ip_forward
```

---

## Bước 7: Kiểm tra OpenVPN server đã chạy

```bash
sudo ps aux | grep openvpn
sudo netstat -tulpn | grep 1197
sudo ss -tulpn | grep 1197
```

---

## Bước 8: Cấu hình routes cho truy cập Database VMs

### Thêm routes cho database subnets

```bash
# Nếu database VMs ở subnet khác
sudo ovpm net add --name "database-subnet" --net "192.168.1.0/24" --via "192.168.1.1"

# Kiểm tra routes
sudo ovpm net list
```

### Cấu hình DNS cho resolve database hostnames

```bash
sudo ovpm vpn update --dns "192.168.1.1,8.8.8.8,8.8.4.4"
```

---

## Bước 9: Setup Web UI cho quản lý

### Kiểm tra Web UI đã chạy

```bash
sudo netstat -tulpn | grep 8080
```

### Truy cập Web UI

```bash
echo "Truy cập Web UI tại: http://vpn.yourdomain.com:8080"
echo "Hoặc sử dụng IP: http://192.168.1.210:8080"
echo "Username: admin"
echo "Password: AdminPassword123!"
```

---

## Bước 10: Test kết nối và truy cập Database

### Test ping từ VPN client đến LAN

```bash
# Sau khi connect VPN, test từ client:
# ping 192.168.1.1    # Gateway
# ping 192.168.1.210  # VPN Server
# ping 192.168.1.xxx  # Database VMs
```

### Test kết nối database ports

```bash
# Test MySQL/MariaDB
# telnet 192.168.1.xxx 3306

# Test PostgreSQL  
# telnet 192.168.1.xxx 5432

# Test MongoDB
# telnet 192.168.1.xxx 27017
```

---

## Bước 11: Monitor & Troubleshooting

### Xem logs VPN connections

```bash
sudo journalctl -u ovpmd -n 50
sudo tail -f /var/log/openvpn/server.log
```

### Monitor active connections

```bash
sudo ovpm user list
sudo ovpm vpn status
```

### Kiểm tra routing table

```bash
route -n
ip route show
```

---

## Bước 12: Các lệnh quản lý thường dùng

### Quản lý users

```bash
# Xem chi tiết user
sudo ovpm user show -u dbadmin

# Xóa user
sudo ovpm user delete -u username

# Thay đổi password
sudo ovpm user update -u dbadmin -p NewPassword123!
```

### Restart services

```bash
sudo ovpm vpn restart
sudo systemctl restart ovpmd
```

### Backup cấu hình

```bash
sudo cp /var/lib/ovpm/ovpm.db /backup/ovpm-$(date +%Y%m%d).db
sudo tar -czf /backup/ovpn-configs-$(date +%Y%m%d).tar.gz /home/$(whoami)/vpn-configs/
```

---

## Troubleshooting các vấn đề thường gặp

### 1. Không connect được VPN trên port 1197

```bash
sudo ufw status numbered
sudo netstat -tulpn | grep 1197
sudo journalctl -u ovpmd --no-pager -l
```

### 2. Connect được VPN nhưng không ping được LAN

```bash
# Kiểm tra IP forwarding
cat /proc/sys/net/ipv4/ip_forward

# Kiểm tra iptables rules
sudo iptables -L -v -n
sudo iptables -t nat -L -v -n
```

### 3. Không truy cập được database từ VPN

```bash
# Kiểm tra routes
ip route show table main
sudo ovpm net list

# Test từ VPN server
ping 192.168.1.xxx
telnet 192.168.1.xxx 3306
```

### 4. Web UI không accessible trên port 8080

```bash
sudo ufw status | grep 8080
sudo netstat -tulpn | grep 8080
curl -I http://vpn.yourdomain.com:8080
curl -I http://192.168.1.210:8080
```

---

## File .ovpn cho Database Access

Sau khi tạo user và export config, file .ovpn có dạng:

```
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
# Routes để truy cập LAN
route 192.168.1.0 255.255.255.0
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
```bash
# Test OVPM access
ovpm --version
ovpm vpn status
sudo systemctl status ovpmd

# Check if user has proper permissions
which ovpm
```

### 4. Timezone issues:
Script tự động sử dụng Vietnam timezone (+7). Logs sẽ hiển thị:
```
2024-01-15 14:30:15 ICT+07 [INFO] Health check started
## ✅ Danh sách kiểm tra sẵn sàng cho Production

- [ ] Các gói phụ thuộc Python đã được cài đặt trong môi trường ảo
- [ ] Các lệnh OVPM có thể truy cập và hoạt động
- [ ] Webhook Discord đã được cấu hình và kiểm tra
- [ ] Dịch vụ đã được kích hoạt với tự động khởi động khi boot
- [ ] Đã thiết lập xoay vòng log cho `/var/log/ovpm_health.log`
- [ ] Đã xác minh kết nối mạng
- [ ] Ngưỡng cảnh báo đã được điều chỉnh cho môi trường
- [ ] Đã sao lưu các file cấu hình

## 🔒 Các vấn đề về bảo mật

- Script chạy với quyền người dùng phù hợp
- Không lưu trữ thông tin đăng nhập nhạy cảm trong logs
- URL webhook Discord được bảo vệ
- File logs có quyền truy cập phù hợp
- Cô lập dịch vụ với systemd

## 🎯 Tích hợp với Hạ tầng OVPM

Health checker hoàn hảo cho triển khai OVPM production:
- Giám sát máy chủ VPN trên `192.168.1.210:1197`
- Theo dõi khả năng truy cập Web UI trên cổng `8080`
- Xác minh phân giải DNS cho hostname
- Báo cáo hoạt động người dùng và trạng thái kết nối
- Cung cấp cảnh báo sớm cho các vấn đề về tài nguyên

## 📞 Hỗ trợ & Xử lý sự cố

Nếu gặp vấn đề:
1. **Kiểm tra logs dịch vụ**: `sudo journalctl -u ovpm-health-checker -f`
2. **Chạy kiểm tra thủ công**: `cd /home/tantai/healthcheck && ./venv/bin/python3 ovpm_health_checker.py`
3. **Xác minh OVPM**: `sudo ovpm vpn status`
4. **Kiểm tra Discord**: Xác minh URL webhook và kết nối mạng
5. **Xem hướng dẫn cài đặt**: Xem `SETUP-GUIDE.md` trong thư mục để biết hướng dẫn chi tiết

---

## Kết quả triển khai

Hoàn tất việc triển khai OpenVPN Server với OVPM cho mục đích truy cập mạng LAN và Database VMs! 

**Những gì đã đạt được:**
- ✅ VPN Server chạy trên IP `192.168.1.210` port `1197/UDP`
- ✅ Web UI quản lý trên port `8080/TCP`
- ✅ Có thể truy cập mạng LAN `192.168.1.0/24` từ VPN clients
- ✅ File `.ovpn` để cấu hình clients
- ✅ Routing cho truy cập Database VMs
- ✅ Firewall và security đã được cấu hình
- ✅ Monitoring và troubleshooting tools

**Các bước tiếp theo:**
1. Download file `.ovpn` từ `/home/$(whoami)/vpn-configs/`
2. Import vào OpenVPN client (Windows/Mac/Mobile)
3. Connect và test truy cập database VMs
4. Sử dụng Web UI tại `http://vpn.yourdomain.com:8080` để quản lý

VPN server đã hoạt động hoàn hảo cho Database Infrastructure!

---

## 🔗 Tích hợp vào Quy trình DevOps Hoàn Chỉnh

OpenVPN Server đã hoàn thiện **truy cập từ xa an toàn** cho hạ tầng home lab. Đây là bước tiến hóa từ việc mở port cơ bản sang bảo mật cấp doanh nghiệp.

### 🚀 Hành Trình Tự Động Hoá Toàn Diện:

**Cấp 1: Tự động hoá phần cứng**
- ✅ [Wake On LAN](Wake-On-LAN.md) - Quản lý bật/tắt server từ xa

**Cấp 2: Tự động hoá ứng dụng**  
- ✅ [ESXi VM Autostart](ESXi-VM-Autostart.md) - Khởi động dịch vụ tự động

**Cấp 3: Mở dịch vụ ra mạng**
- ✅ [Port Forwarding](Port-Forwarding.md) - Mở dịch vụ cơ bản ra ngoài

**Cấp 4: Bảo mật doanh nghiệp** (Hiện tại)
- ✅ **OpenVPN Server** - Truy cập an toàn vào database và LAN

**Cấp 5: Điều phối container** (Sắp tới)
- 🎯 **Kubernetes/Docker Swarm** - Mô hình triển khai hiện đại

### 🔒 Tiến hoá bảo mật:

**📋 Cách tiếp cận cũ:** 
