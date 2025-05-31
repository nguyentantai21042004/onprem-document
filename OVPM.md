# Hướng dẫn triển khai OpenVPN Server với OVPM

## Chuẩn bị

Trước khi bắt đầu, đảm bảo bạn có:

1. **Hệ điều hành**: Ubuntu Server
2. **Quyền truy cập**: root (sudo)
3. **Phần mềm cần thiết**: `ufw`, `curl`, `systemd`, `iptables`

## Bước 0: Cài đặt OVPM

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

## Bước 1: Kiểm tra service đã chạy

```bash
sudo systemctl status ovpmd
sudo journalctl -u ovpmd -f
ovpm --help
```

## Bước 2: Khởi tạo VPN Server

```bash
sudo ovpm vpn init --hostname your-server-domain.com
```

Hoặc sử dụng IP:

```bash
sudo ovpm vpn init --hostname 192.168.1.100
```

Lệnh này sẽ thực hiện:
- Tạo CA certificates
- Tạo server certificates
- Khởi tạo OpenVPN server config
- Setup database

## Bước 3: Kiểm tra VPN Server status

```bash
sudo ovpm vpn status
```

## Bước 4: Tạo user admin đầu tiên

### Tạo user admin

```bash
sudo ovpm user create -u admin -p your-password --admin
```

### Tạo user thử nghiệm

```bash
sudo ovpm user create -u testuser -p testuser123
```

### Liệt kê danh sách users

```bash
sudo ovpm user list
```

## Bước 5: Tạo file .ovpn cho client

```bash
sudo ovpm user genconfig -u testuser
```

Hoặc xuất ra thư mục cụ thể:

```bash
sudo ovpm user genconfig -u testuser -o /home/youruser/
ls -la *.ovpn
```

## Bước 6: Cấu hình Firewall & Network

### Cấu hình UFW

```bash
sudo ufw allow 1194/udp
```

### Cấu hình iptables (tùy chọn)

```bash
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
```

### Enable IP Forwarding

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Kiểm tra IP Forwarding

```bash
cat /proc/sys/net/ipv4/ip_forward
```

## Bước 7: Kiểm tra OpenVPN server đã chạy

```bash
sudo ps aux | grep openvpn
sudo netstat -tulpn | grep 1194
sudo ss -tulpn | grep 1194
```

## Bước 8: Monitor & Troubleshooting

### Xem logs

```bash
sudo journalctl -u ovpmd -n 50
sudo tail -f /var/log/openvpn/server.log
```

### Quản lý users và server

```bash
sudo ovpm user list
sudo ovpm vpn restart
```

## Bước 9: Setup Web UI (Tùy chọn)

### Kiểm tra port Web UI

```bash
sudo netstat -tulpn | grep 8080
sudo ufw allow 8080/tcp
```

Truy cập Web UI tại: `http://your-server-ip:8080`

## Bước 10: Các cấu hình nâng cao

### Quản lý networks

```bash
# Xem danh sách networks
sudo ovpm net list

# Thêm route nội bộ
sudo ovpm net add --name "internal" --net "192.168.1.0/24" --via "192.168.1.1"
```

### Cập nhật DNS

```bash
sudo ovpm vpn update --dns "8.8.8.8,8.8.4.4"
```

### Xóa user

```bash
sudo ovpm user delete -u username
```

### Backup database

```bash
sudo cp /var/lib/ovpm/ovpm.db /backup/ovpm.db.$(date +%Y%m%d)
```

## Troubleshooting thường gặp

### 1. ovpmd không start

```bash
sudo journalctl -u ovpmd --no-pager -l
```

### 2. VPN client không connect được

```bash
sudo ufw status
sudo tail -f /var/log/openvpn/server.log
```

### 3. Không thể tạo user

```bash
sudo ovpm vpn status
```

## Kết luận

Bạn đã hoàn tất việc triển khai OpenVPN Server với OVPM! Server VPN của bạn giờ đây đã sẵn sàng để sử dụng với các tính năng:

- ✅ CA và certificates tự động
- ✅ Quản lý users dễ dàng
- ✅ Web UI để quản lý
- ✅ Cấu hình firewall và network
- ✅ Monitoring và troubleshooting

Chúc bạn triển khai thành công!
