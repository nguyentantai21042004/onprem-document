 # ESXi VM Autostart & Service Automation

## Giới thiệu

Sau khi Wake On LAN thành công, bước tiếp theo là đảm bảo các VM và services quan trọng tự động khởi động. Điều này tạo ra complete automation chain cho home lab/development environment.

## 🎯 Mục tiêu

Khi bật server ESXi bằng Wake-on-LAN, cần đảm bảo:

1. **Các máy ảo quan trọng** (VD: VPN server, web server...) được khởi động tự động
2. **Bên trong mỗi máy ảo**, các dịch vụ cần thiết được kích hoạt tự động (thay vì phải chạy alias thủ công)

---

## 🔧 Giải pháp tổng thể

### ✅ 1. Tự động khởi động VM trong ESXi

**Thực hiện trong giao diện quản lý ESXi Web:**

#### Bước 1: Truy cập ESXi
```
https://<IP-server>
```

#### Bước 2: Vào mục Autostart
```
Host → Manage → System → Autostart
```

#### Bước 3: Nhấn "Edit Settings"

#### Bước 4: Thiết lập
- **Enable Autostart**: Bật tính năng này
- **Chọn các VM cần khởi động tự động**
- **(Tùy chọn)** Thiết lập thời gian trễ giữa các VM để tránh quá tải tài nguyên

#### Bước 5: Nhấn Save

**🎯 Kết quả:** Khi ESXi khởi động, các VM được chọn sẽ bật tự động.

---

### ✅ 2. Tự động chạy lệnh alias trong mỗi VM

> **Lý do:** Vì alias thường chỉ tồn tại trong phiên shell người dùng, nên cần chuyển nội dung alias thành **script thực thi** rồi chạy script đó tự động khi VM khởi động.

Bạn có 2 cách phổ biến để làm điều này:

### 🔨 Cách 1: Dùng file rc.local (cách truyền thống, dễ thiết lập)

#### 1. Mở terminal trong VM

#### 2. Chạy:
```bash
sudo nano /etc/rc.local
```

#### 3. Thêm các lệnh bạn muốn chạy, ví dụ:
```bash
/home/username/startvpn.sh
```
*(Script này chứa nội dung alias mà bạn thường dùng)*

#### 4. Đảm bảo file có quyền thực thi:
```bash
sudo chmod +x /etc/rc.local
```

### ⚙️ Cách 2: Tạo service với systemd (hiện đại, ổn định hơn)

#### 1. Tạo một script để chạy lệnh alias:
```bash
sudo nano /usr/local/bin/start_services.sh
```

**Nội dung ví dụ:**
```bash
#!/bin/bash
/path/to/your/real_command_1
/path/to/your/real_command_2
```

#### Sau đó cấp quyền thực thi:
```bash
sudo chmod +x /usr/local/bin/start_services.sh
```

#### 2. Tạo file service:
```bash
sudo nano /etc/systemd/system/startup-tasks.service
```

**Nội dung:**
```ini
[Unit]
Description=Start necessary services at boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start_services.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

#### 3. Bật service để chạy khi khởi động:
```bash
sudo systemctl enable startup-tasks.service
```

**🎯 Kết quả:** Mỗi lần VM khởi động, các lệnh quan trọng của bạn sẽ được chạy tự động.

---

## 📋 Tóm tắt

| **Mục tiêu** | **Giải pháp** |
|--------------|---------------|
| VM bật khi server bật | Bật tính năng **Autostart** trong ESXi |
| Dịch vụ trong VM tự chạy | Dùng **rc.local** hoặc tạo **service** với **systemd** |

---

## 🚀 Complete Automation Workflow

```
Wake On LAN
    ↓
ESXi Server Boot
    ↓
VM Autostart (ESXi feature)
    ↓
Service Autostart (rc.local/systemd)
    ↓
All services ready!
```

---

## 💡 Các Phương Pháp Hay Nhất

### 🔧 Tự Động Khởi Động VM
- **Phân tầng khởi động**: VM quan trọng khởi động trước, VM hỗ trợ khởi động sau
- **Độ trễ giữa các VM**: Tránh tranh chấp tài nguyên
- **Giám sát tài nguyên**: Theo dõi CPU/RAM tăng đột biến khi khởi động

### 📜 Tự Động Hóa Dịch Vụ
- **Ưu tiên systemd hơn rc.local**: Hiện đại, đáng tin cậy, ghi log tốt hơn
- **Thêm xử lý lỗi**: Dịch vụ có thể bị lỗi
- **Ghi log hoạt động khởi động**: Dễ gỡ lỗi
- **Kiểm tra kỹ lưỡng**: Mô phỏng các tình huống khởi động lại

### 🔍 Giám Sát
- **Xác minh tự động khởi động**: Kiểm tra chu kỳ nguồn thực tế
- **Kiểm tra phụ thuộc dịch vụ**: Một số dịch vụ cần khởi động trước
- **Theo dõi thời gian khởi động**: Tối ưu hóa trình tự khởi động

---

## 🔧 Xử Lý Sự Cố

### ❌ VM không tự động khởi động
- Kiểm tra Autostart ESXi đã bật
- Xác minh VM trong danh sách tự động khởi động
- Kiểm tra yêu cầu tài nguyên VM
- Xem lại nhật ký ESXi

### ❌ Dịch vụ không khởi động
- Kiểm tra quyền script: `ls -la /path/to/script`
- Chạy thử script thủ công: `/path/to/script`
- Xem nhật ký hệ thống: `journalctl -u your-service`
- Xác minh phụ thuộc dịch vụ

---

## 🎓 Giá Trị Học Tập DevOps

**Tự động hóa hạ tầng**: Tự động hóa hoàn chỉnh từ phần cứng đến ứng dụng  
**Điều phối dịch vụ**: Hiểu về trình tự khởi động và phụ thuộc  
**Quản trị hệ thống**: Dịch vụ Linux, systemd, quy trình khởi động  
**Kỹ thuật độ tin cậy**: Đảm bảo dịch vụ hoạt động sau khi khởi động lại  
**Giám sát & Ghi log**: Quan sát cho quy trình tự động  

---

## 🔗 Chủ Đề Liên Quan

- [Cài đặt Wake On LAN](WakeOnLans.md) - Tự động hóa tầng phần cứng
- Container Orchestration - Modern alternative với Docker/K8s
- Configuration Management - Ansible/Terraform cho enterprise setups
- Service Mesh - Advanced service networking và management

---

## 🚀 Bước Tiếp Theo: Network Service Exposure

Sau khi đã có **complete automation** cho Wake On LAN → VM Autostart → Service Autostart, bước tiếp theo là **expose services ra external network** để có thể truy cập từ bất kỳ đâu.

**📋 Current capability**: 
```
WOL → ESXi Boot → Auto VMs → Auto Services (internal only)
```

**🎯 Next level capability**: 
```
WOL → ESXi Boot → Auto VMs → Auto Services → External Access Ready!
```

### 🌐 Recommended Next Guide: [Port Forwarding & Network Services](ForwardPort.md)

**What you'll learn**:
- ✅ **Service Exposure**: Router configuration để expose internal services
- ✅ **Network Security**: Firewall, authentication, SSL best practices  
- ✅ **Production Deployment**: Reverse proxy, load balancing concepts
- ✅ **DevOps Networking**: Service discovery, monitoring, automation integration

**Perfect progression**: Infrastructure automation → Application automation → Network automation → Complete DevOps workflow! 🌐 