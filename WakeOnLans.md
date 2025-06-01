# Wake On LAN - Bước đầu tiên trong hành trình DevOps

## Giới thiệu

Wake On LAN (WOL) là một trong những kỹ thuật cơ bản nhưng quan trọng khi bắt đầu học DevOps. Nó không chỉ giúp quản lý server từ xa mà còn mở ra nhiều khái niệm quan trọng trong việc quản lý hạ tầng.

### Tại sao Wake On LAN quan trọng?

**Automation Foundation**: WOL là bước đầu tiên để hiểu về remote control và automation - hai yếu tố cốt lõi của DevOps.

**Resource Management**: Học cách bật/tắt server từ xa giúp tối ưu hóa tài nguyên và chi phí vận hành.

**Network Understanding**: Việc cài đặt WOL đòi hỏi hiểu biết cơ bản về network protocols và infrastructure.

**Infrastructure as Code**: Scripts WOL là nền tảng đầu tiên cho việc quản lý infrastructure bằng code.

---

## Cài đặt Wake On LAN

### Yêu cầu hệ thống
- Motherboard và network adapter hỗ trợ WOL
- Network connection (Ethernet)
- Cấu hình BIOS/UEFI phù hợp

## PHẦN A: THIẾT LẬP TRÊN ESXi SERVER

### Bước 1: Kiểm tra và kích hoạt WoL trên ESXi

#### 1.1 SSH vào ESXi server:
```bash
ssh root@[IP_ESXi_server]
# Nhập mật khẩu root
```

#### 1.2 Kiểm tra card mạng và WoL:
```bash
# Liệt kê card mạng
esxcli network nic list

# Kiểm tra chi tiết card mạng chính (thường là vmnic0)
esxcli network nic get -n vmnic0

# Kiểm tra WoL support và status
ethtool vmnic0 | grep -i wake
```

**Kết quả mong đợi:**
```
Supports Wake-on: pumbg
Wake-on: g
```

#### 1.3 Kích hoạt WoL (nếu chưa có "Wake-on: g"):
```bash
ethtool -s vmnic0 wol g
```

#### 1.4 Ghi nhớ MAC Address:
```bash
esxcli network nic list | grep vmnic0
```
**Lưu lại MAC Address** (ví dụ: `00:e0:25:30:50:7b`)

### Bước 2: Tạo script tự động kích hoạt WoL

#### 2.1 Tạo script startup:
```bash
vi /etc/rc.local.d/local.sh
```

#### 2.2 Nhập nội dung sau:
```bash
#!/bin/sh
# Auto-enable Wake on LAN for vmnic0
/usr/lib/vmware/ethtool/bin/ethtool -s vmnic0 wol g
exit 0
```

**Mục đích:** 
- Tạo file script trong thư mục `/etc/rc.local.d/`
- **Tại sao ở đây?** ESXi tự động chạy tất cả script trong thư mục này khi khởi động
- **Tương tự:** Như "Startup Programs" trong Windows

Gõ `:wq` và ấn `Enter` để lưu

#### 2.3 Phân quyền cho script:
```bash
chmod +x /etc/rc.local.d/local.sh
```

#### 2.4 Test script:
```bash
# Chạy script để test
/etc/rc.local.d/local.sh

# Kiểm tra kết quả
ethtool vmnic0 | grep "Wake-on"
```

#### 2.5 Luồng hoạt động:
```
ESXi khởi động
    ↓
Chạy tất cả script trong /etc/rc.local.d/
    ↓
Chạy local.sh
    ↓
Thực thi: ethtool -s vmnic0 wol g
    ↓
Wake on LAN được bật tự động
    ↓
ESXi sẵn sàng nhận Magic Packet
```

### Bước 3: Cấu hình Power Management

**Tại sao cần bước này?**
- ESXi mặc định có thể sử dụng các chế độ tiết kiệm điện (P-States, C-States)
- Các chế độ này có thể làm network adapter "ngủ sâu" và không phản hồi Magic Packet
- Cấu hình High Performance đảm bảo network luôn sẵn sàng nhận WOL

#### 3.1 Cấu hình Power Policy:
```bash
# Set High Performance mode
esxcli system settings advanced set -o /Power/CpuPolicy -s "High Performance"

# Disable P-States (optional)
esxcli system settings advanced set -o /Power/UsePStates -i 0
```

#### 3.2 Kiểm tra cấu hình:
```bash
# Kiểm tra cấu hình
esxcli system settings advanced list -o /Power/CpuPolicy
esxcli system settings advanced list -o /Power/UsePStates
```

**Kết quả mong đợi:**
- CpuPolicy: "High Performance" 
- UsePStates: 0 (disabled)

**Lưu ý:** Cấu hình này sẽ tăng mức tiêu thụ điện nhưng đảm bảo WOL hoạt động ổn định 100%.

## 💡 Shutdown vs Standby - Hiểu đúng khái niệm

### **Shutdown (Tắt nguồn hoàn toàn):**
- **Power state**: S5 (Soft Off)
- **Đặc điểm**: Tắt hoàn toàn, chỉ giữ power tối thiểu cho network adapter
- **WOL**: Có thể wake up nếu network adapter được cấp nguồn
- **Tiêu thụ điện**: ~5-10W (chỉ PSU standby + network)
- **Khởi động**: Chậm (full boot process)

### **Standby (Chế độ ngủ):**
- **Power state**: S3 (Suspend to RAM) 
- **Đặc điểm**: RAM vẫn được cấp nguồn, CPU và storage ngủ
- **WOL**: Wake up rất nhanh vì RAM còn data
- **Tiêu thụ điện**: ~15-30W (RAM + essential components)
- **Khởi động**: Nhanh (resume từ RAM)

### **Lựa chọn nào cho ESXi?**
**ESXi không hỗ trợ standby (S3) mode**, chỉ có:
- **Running**: Hoạt động bình thường
- **Maintenance Mode**: Chuẩn bị shutdown
- **Shutdown**: Tắt hoàn toàn (S5)

**→ "Standby" trong ESXi = Shutdown với WOL enabled**

### Bước 4: Tạo script shutdown (standby) tiện lợi

**Mục đích**: Tạo script để gracefully shutdown ESXi và chuẩn bị cho Wake On LAN

#### 4.1 Tạo script shutdown:
```bash
vi /root/standby.sh
```

#### 4.2 Nội dung script:
```bash
#!/bin/sh
echo "Preparing server for Wake on LAN..."
echo "Entering maintenance mode..."
esxcli system maintenanceMode set -e true

echo "Waiting 5 seconds for services to stop..."
sleep 5

echo "Shutting down to standby mode..."
echo "Server will be ready for Wake on LAN"
esxcli system shutdown poweroff -d 10 -r "Standby for WoL - $(date)"
```

#### 4.3 Phân quyền:
```bash
chmod +x /root/standby.sh
```

#### 4.4 Sử dụng script:
```bash
# Chạy script để shutdown ESXi một cách an toàn
/root/standby.sh
```

**Workflow của script:**
1. **Maintenance mode**: Đảm bảo VMs được migrate/shutdown properly
2. **Delay 5s**: Cho các service dừng hoàn toàn
3. **Graceful shutdown**: Shutdown với message và delay 10s
4. **WOL ready**: Server sẵn sàng nhận Magic Packet
