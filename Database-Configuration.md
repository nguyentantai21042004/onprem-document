# Database Configuration - Hệ thống Database Tập trung

## Giới thiệu

Sau khi triển khai [OpenVPN Server](VPN-Server-OpenVPN.md) cho secure access, **Database Configuration** là bước tiếp theo quan trọng trong home lab DevOps infrastructure. Đây là **enterprise-grade database setup** với mạng riêng biệt, security cẩn thận và quản lý tập trung cho nhiều dự án.

### Tại sao Database Configuration quan trọng cho DevOps?

**Centralized Data Management**: Tập trung database cho tất cả dự án và ứng dụng.

**Security Isolation**: Mạng database riêng biệt, chỉ truy cập qua VPN.

**High Availability**: Database clustering và replication cho production-ready setup.

**Multi-Project Support**: Hỗ trợ nhiều loại database cho các technology stacks khác nhau.

---

## Mục đích và kiến trúc

Triển khai hệ thống database tập trung với các mục đích sau:

- **Database tập trung**: MongoDB và PostgreSQL cho tất cả dự án
- **Network isolation**: Mạng riêng biệt `10.0.1.0/24` cho database VMs
- **VPN-only access**: Truy cập database chỉ qua VPN tunnel
- **Authentication & Authorization**: User management và RBAC cho từng database
- **Backup & Recovery**: Automated backup và disaster recovery

**Kiến trúc Database Network:**
- **Database Network**: `10.0.1.0/24` (isolated network)
- **ESXi Gateway**: `10.0.1.1`
- **MongoDB Cluster**: `10.0.1.10-12`
- **PostgreSQL Cluster**: `10.0.1.20-22`
- **Access**: Chỉ qua VPN từ `192.168.1.210`

---

## Chuẩn bị

Trước khi bắt đầu, đảm bảo có:

1. **ESXi Server**: Đã cài đặt và cấu hình
2. **VPN Server**: Đã triển khai và hoạt động
3. **VM Resources**: Đủ CPU, RAM, Storage cho database VMs
4. **Network Planning**: IP addressing đã được lên kế hoạch
5. **OS Images**: Ubuntu Server ISO cho database VMs

---

## BƯỚC 1: CHUẨN BỊ ESXi VÀ TẠO NETWORK

### 1.1 TRUY CẬP GIAO DIỆN WEB CỦA ESXi

**Kết nối ESXi:**
- Mở trình duyệt và truy cập: `https://192.168.1.XXX`
- Đăng nhập với:
  + Username: `root`
  + Password: (mật khẩu ESXi)
- Chấp nhận cảnh báo chứng chỉ (certificate warning)

**🎯 Mục đích:**
Giao diện Web của ESXi là nơi quản trị toàn bộ hạ tầng ảo hóa.

**💡 Giải thích:**
- ESXi là hệ điều hành ảo hóa chạy trực tiếp trên phần cứng
- Truy cập Web UI giúp bạn quản lý máy ảo, mạng, lưu trữ

---

### 1.2 TẠO VIRTUAL SWITCH CHO MẠNG DATABASE

**Tạo vSwitch:**
- Vào: `Networking > Tab "Virtual switches"`
- Nhấn: `Add standard virtual switch`

**Cấu hình vSwitch:**
```
Name: vSwitch-Database
MTU: 1500
Uplink: (Để trống - mạng nội bộ)
Security:
    ✅ Promiscuous mode: Accept
    ✅ MAC address changes: Accept
    ✅ Forged transmits: Accept
```

**🎯 Mục đích:**
Tạo một switch ảo (vSwitch) để kết nối các máy ảo nội bộ với nhau.

**💡 Giải thích:**
- vSwitch là switch ảo, hoạt động như switch vật lý
- Không gắn uplink → mạng nội bộ không truy cập ra ngoài
- Security: Cho phép linh hoạt trong việc truyền/nhận gói tin (có thể cần cho clustering, HA)

---

### 1.3 TẠO PORT GROUP CHO DATABASE NETWORK

**Tạo Port Group:**
- Vào: `Tab "Port groups" > Add port group`

**Cấu hình Port Group:**
```
Name: Database-Network
Virtual switch: vSwitch-Database
VLAN ID: 0 (Không sử dụng VLAN)
Security: Inherit from vSwitch
```

**🎯 Mục đích:**
Tạo cổng mạng để VM có thể kết nối vào vSwitch này.

**💡 Giải thích:**
- Port Group giống như một nhóm VLAN logic cho VM
- Khi tạo VM, sẽ chọn Port Group để VM "nối dây" vào
- VLAN ID = 0 nghĩa là không phân chia VLAN

---

### 1.4 TẠO VMKERNEL NIC (GATEWAY CHO DATABASE NETWORK)

**Tạo VMkernel NIC:**
- Vào: `Tab "VMkernel NICs" > Add VMkernel NIC`

**Cấu hình VMkernel:**
```
Port Group: Database-Network
IPv4: Static
    IP Address: 10.0.1.1
    Subnet Mask: 255.255.255.0
Services: (Không chọn dịch vụ nào)
```

**🎯 Mục đích:**
Tạo một IP cho chính ESXi host trong mạng nội bộ này.

**💡 Giải thích:**
- VMkernel NIC là "card mạng" của chính ESXi host
- Cho phép ESXi giao tiếp với các VM trong mạng nội bộ
- Không bật dịch vụ → chỉ dùng để giao tiếp IP, không dùng để quản lý, vMotion

---

### 1.5 TỔNG QUAN KIẾN TRÚC MẠNG DATABASE

```
┌─────────────────────────────────────────────────────────┐
│                ESXi Network Architecture                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [MongoDB VM A: 10.0.1.10] ────┐                      │
│                                  │                      │
│  [MongoDB VM B: 10.0.1.11] ────┤                      │
│                                  ├─► (Database-Network) │
│  [PostgreSQL A: 10.0.1.20] ────┤     Port Group        │
│                                  │                      │
│  [PostgreSQL B: 10.0.1.21] ────┘                      │
│                                  │                      │
│                                  ▼                      │
│                        [vSwitch-Database]               │
│                                  │                      │
│                        [VMkernel: 10.0.1.1]            │
│                                                         │
└─────────────────────────────────────────────────────────┘
                                  ▲
                     ┌────────────┴────────────┐
                     │     VPN Tunnel Access   │
                     │   (192.168.1.210 VPN)  │
                     └─────────────────────────┘
```

**🔗 Ý nghĩa kết nối:**
- Các VM cùng port group sẽ giao tiếp qua vSwitch
- VMkernel NIC giúp ESXi cũng tham gia mạng này
- Có thể sử dụng `10.0.1.1` làm gateway nội bộ
- **Isolated network**: Chỉ truy cập qua VPN tunnel

---

## Kết quả Bước 1

✅ **Hoàn thành chuẩn bị ESXi network infrastructure:**
- vSwitch-Database: Isolated switch cho database VMs
- Database-Network Port Group: Kết nối cho VMs
- VMkernel NIC `10.0.1.1`: Gateway cho mạng database
- Security settings: Configured cho database clustering

**🚀 Bước tiếp theo:**
- Tạo Database VMs (MongoDB và PostgreSQL)
- Cấu hình static IP addressing
- Setup database clustering và replication