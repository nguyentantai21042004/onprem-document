# Triển khai OpenVPN Server với OVPM - Hướng dẫn chi tiết

## Mục đích và cấu hình

Triển khai VPN Server riêng với các mục đích sau:

- **Truy cập mạng LAN từ xa**: Kết nối an toàn vào mạng nội bộ từ bất kỳ đâu
- **Truy cập các VM Database**: Kết nối trực tiếp đến các máy ảo đang chạy database trong mạng LAN  
- **Xuất file .ovpn**: Tạo file cấu hình VPN cho các devices
- **Quản lý tập trung**: Sử dụng Web interface để quản lý users và cấu hình

**Thông số server:**
- IP Server: `192.168.1.210`
- **Hostname VPN**: `vpn.yourdomain.com` (subdomain dành riêng cho VPN)
- Port OpenVPN: `1197/UDP`
- Port Web UI: `8080/TCP`
- Mạng LAN: `192.168.1.0/24`

## Chuẩn bị

Các yêu cầu:

1. **Hệ điều hành**: Ubuntu Server
2. **Quyền truy cập**: root (sudo)
3. **Phần mềm cần thiết**: `ufw`, `curl`, `systemd`, `iptables`
4. **Server IP**: 192.168.1.210 (đã cấu hình static)
5. **Domain và DNS**: Subdomain `vpn.yourdomain.com` đã trỏ về IP 192.168.1.210

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

## Bước 1: Cài đặt OVPM

### Thêm repository APT

```bash
sudo sh -c 'echo "deb [trusted=yes] https://cad.github.io/ovpm/deb/ ovpm main" >> /etc/apt/sources.list'
sudo apt update
```

### Cài đặt OVPM

```bash
sudo apt install ovpm
```

### Kích hoạt dịch vụ ovpmd

```bash
sudo systemctl start ovpmd
sudo systemctl enable ovpmd
```

## Bước 2: Kiểm tra service đã chạy

```bash
sudo systemctl status ovpmd
sudo journalctl -u ovpmd -f
ovpm --help
```

## Bước 3: Khởi tạo VPN Server với cấu hình

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

## Bước 4: Kiểm tra VPN Server status

```bash
sudo ovpm vpn status
```

## Bước 5: Tạo user admin và users cho database access

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

## Bước 6: Tạo file .ovpn cho client

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

## Bước 7: Cấu hình Firewall & Network cho truy cập LAN

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

## Bước 8: Kiểm tra OpenVPN server đã chạy

```bash
sudo ps aux | grep openvpn
sudo netstat -tulpn | grep 1197
sudo ss -tulpn | grep 1197
```

## Bước 9: Cấu hình routes cho truy cập Database VMs

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

## Bước 10: Setup Web UI cho quản lý

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

## Bước 11: Test kết nối và truy cập Database

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

## Bước 12: Monitor & Troubleshooting

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

## Bước 13: Các lệnh quản lý thường dùng

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
