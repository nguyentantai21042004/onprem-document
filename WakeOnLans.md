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
