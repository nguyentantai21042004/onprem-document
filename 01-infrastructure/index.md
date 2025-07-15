# Hướng Dẫn Triển Khai Infrastructure

## 📋 Tổng Quan

Phần này cung cấp tài liệu toàn diện để thiết lập tầng infrastructure nền tảng cho server on-premise của bạn. Các hướng dẫn bao gồm quản lý phần cứng, cấu hình mạng, và tự động hóa hệ thống.

## 🏗️ Tổng Quan Kiến Trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                    Tầng Infrastructure                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               Quản lý Nguồn từ xa                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │Wake-on-LAN  │  │   Scripts   │  │  Scheduling │     │   │
│  │  │Configuration│  │ Automation  │  │  & Cron     │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               Quản lý Máy Ảo ESXi                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │ VM Autostart│  │   systemd   │  │ Service     │     │   │
│  │  │Configuration│  │ Integration │  │ Management  │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  Cấu hình Mạng                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │ ESXi vSwitch│  │ Port Groups │  │   VLANs     │     │   │
│  │  │ Configuration│  │   Setup     │  │ Management  │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               Mở cổng và Định tuyến                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │ Router      │  │ Firewall    │  │ Service     │     │   │
│  │  │Configuration│  │    Rules    │  │ Exposure    │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 Cấu Trúc Tài Liệu

### 1. [Wake-on-LAN](wake-on-lan.md)
**Tầng Quản lý Nguồn - Bắt đầu từ đây**
- ✅ Cấu hình Wake-on-LAN cơ bản
- ✅ Scripts tự động hóa cho macOS/Windows  
- ✅ Quản lý nguồn từ xa và lập lịch
- ✅ Tích hợp với systemd và cron jobs
- ✅ Troubleshooting và debugging
- ✅ Best practices cho môi trường production

**Yêu cầu tiên quyết**: Phần cứng hỗ trợ WoL

### 2. [ESXi VM Autostart](esxi-vm-autostart.md)
**Tầng Quản lý VM - Tự động hóa Khởi động**
- ✅ Cấu hình VM autostart trên ESXi
- ✅ Tạo systemd services cho automation
- ✅ Templates và configuration files
- ✅ Monitoring và health checks
- ✅ Quản lý startup sequence
- ✅ Recovery procedures khi lỗi

**Yêu cầu tiên quyết**: ESXi server đã cài đặt và cấu hình

### 3. [ESXi pfSense Network Setup](ESXi-pfSense-Network-Setup.md)
**Tầng Mạng - Network Segmentation với pfSense**
- ✅ Tạo isolated virtual switches trong ESXi
- ✅ Cài đặt và cấu hình pfSense router/firewall
- ✅ Network segmentation và subnet isolation
- ✅ Firewall rules và security configuration
- ✅ Troubleshooting network connectivity
- ✅ Production security best practices

**Yêu cầu tiên quyết**: ESXi server và kiến thức networking cơ bản

### 4. [Networking](networking.md)
**Tầng Mạng - Kiến thức Nền tảng**
- ✅ Khái niệm ESXi networking (vmnic, vSwitch)
- ✅ Cấu hình port groups và VLANs
- ✅ Network adapters và teaming
- ✅ Traffic shaping và security policies
- ✅ Distributed switches cho advanced setup
- ✅ Performance tuning và optimization

**Yêu cầu tiên quyết**: Hiểu biết networking cơ bản

### 5. [Port Forwarding](port-forwarding.md)
**Tầng Dịch vụ - Truy cập Bên ngoài**
- ✅ Cấu hình router cho port forwarding
- ✅ Expose services ra internet an toàn
- ✅ Firewall rules và security practices
- ✅ Dynamic DNS và domain management
- ✅ SSL/TLS certificates và HTTPS
- ✅ Monitoring và access logging

**Yêu cầu tiên quyết**: Quyền truy cập router configuration

## 🎯 Lộ Trình Học Tập

### Lộ trình 1: Thiết lập Cơ bản (Cần thiết)
1. **Nguồn** → [wake-on-lan.md](wake-on-lan.md) - Quản lý nguồn từ xa
2. **VM** → [esxi-vm-autostart.md](esxi-vm-autostart.md) - Tự động khởi động
3. **Mạng** → [networking.md](networking.md) - Hiểu networking cơ bản
4. **Dịch vụ** → [port-forwarding.md](port-forwarding.md) - Expose services

**Thời gian ước tính**: 1-2 ngày
**Cấp độ kỹ năng**: Cơ bản đến Trung cấp

### Lộ trình 2: Sẵn sàng Production (Toàn diện)
1. **Nền tảng** → [wake-on-lan.md](wake-on-lan.md) - Advanced automation
2. **Quản lý** → [esxi-vm-autostart.md](esxi-vm-autostart.md) - Enterprise setup  
3. **Mạng** → [networking.md](networking.md) - Advanced networking
4. **Bảo mật** → [port-forwarding.md](port-forwarding.md) - Security hardening

**Thời gian ước tính**: 2-3 ngày
**Cấp độ kỹ năng**: Trung cấp đến Nâng cao

### Lộ trình 3: DevOps Focus (Tự động hóa)
1. **Automation** → [wake-on-lan.md](wake-on-lan.md) - Scripted power management
2. **Integration** → [esxi-vm-autostart.md](esxi-vm-autostart.md) - systemd integration
3. **Monitoring** → [networking.md](networking.md) - Network monitoring
4. **Security** → [port-forwarding.md](port-forwarding.md) - Automated security

**Thời gian ước tính**: 1-2 ngày
**Cấp độ kỹ năng**: Nâng cao

## 🚀 Tham Khảo Nhanh

### Các Lệnh Thiết Yếu
```bash
# Wake-on-LAN Management
wakeonlan 00:11:22:33:44:55
ping -c 4 192.168.1.100
ssh user@192.168.1.100

# ESXi VM Management
vim-cmd vmsvc/getallvms
vim-cmd vmsvc/power.on [vmid]
systemctl status vm-autostart

# Network Diagnostics
esxcli network nic list
esxcli network vswitch standard list
ping -c 4 gateway_ip

# Port Forwarding Tests
netstat -tuln | grep :80
iptables -L -n
curl -I http://your-domain.com
```

### Ví dụ Cấu hình
```bash
# Wake-on-LAN Configuration
# /etc/systemd/system/wake-servers.service
[Unit]
Description=Wake up servers at startup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/wakeonlan 00:11:22:33:44:55
User=wol
Group=wol

[Install]
WantedBy=multi-user.target

# VM Autostart Script
#!/bin/bash
VM_NAME="Ubuntu-Server"
VM_ID=$(vim-cmd vmsvc/getallvms | grep "$VM_NAME" | awk '{print $1}')
vim-cmd vmsvc/power.on $VM_ID

# Port Forward Rule (iptables)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.100:80
iptables -A FORWARD -p tcp -d 192.168.1.100 --dport 80 -j ACCEPT
```

## 🔧 Templates Cấu hình

### Wake-on-LAN Service Template
```systemd
[Unit]
Description=Wake-on-LAN Service for %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/wakeonlan %i
User=wol
Group=wol
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### VM Autostart Template
```bash
#!/bin/bash
# VM Autostart Template
# Usage: ./vm-autostart.sh <vm-name>

VM_NAME="$1"
MAX_RETRIES=3
RETRY_COUNT=0

start_vm() {
    VM_ID=$(vim-cmd vmsvc/getallvms | grep "$VM_NAME" | awk '{print $1}')
    if [ -n "$VM_ID" ]; then
        vim-cmd vmsvc/power.on $VM_ID
        return $?
    else
        echo "VM '$VM_NAME' not found"
        return 1
    fi
}

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if start_vm; then
        echo "VM '$VM_NAME' started successfully"
        exit 0
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Failed to start VM. Retry $RETRY_COUNT/$MAX_RETRIES"
        sleep 5
    fi
done

echo "Failed to start VM after $MAX_RETRIES attempts"
exit 1
```

### Network Configuration Template
```bash
# ESXi vSwitch Configuration
esxcli network vswitch standard add -v vSwitch1
esxcli network vswitch standard uplink add -v vSwitch1 -u vmnic1
esxcli network vswitch standard portgroup add -v vSwitch1 -p "VM Network 1"
esxcli network vswitch standard portgroup set -v vSwitch1 -p "VM Network 1" --vlan-id 100
```

## 🏆 Checklist Validation

### Thiết lập Wake-on-LAN
- [ ] BIOS/UEFI đã enable Wake-on-LAN
- [ ] Network card hỗ trợ WoL
- [ ] Scripts automation hoạt động
- [ ] systemd services configured
- [ ] Logging và monitoring setup
- [ ] Remote access tested

### Quản lý VM ESXi
- [ ] ESXi autostart policies configured
- [ ] systemd services for automation
- [ ] VM startup sequence defined
- [ ] Health check scripts working
- [ ] Recovery procedures documented
- [ ] Monitoring alerts setup

### Cấu hình Networking
- [ ] vSwitches properly configured
- [ ] Port groups và VLANs setup
- [ ] Network connectivity verified
- [ ] Performance optimized
- [ ] Security policies applied
- [ ] Documentation updated

### Port Forwarding
- [ ] Router rules configured correctly
- [ ] Firewall rules secure
- [ ] Services accessible externally
- [ ] SSL certificates valid
- [ ] Access logging enabled
- [ ] Security monitoring active

## 🔗 Điểm Tích hợp

### Với Tầng Services
- Network configuration cho database connections
- Port forwarding cho web services
- VM management cho service containers
- Power management cho service availability

### Với Tầng Kubernetes
- Network setup cho cluster communication
- VM automation cho node management
- Storage configuration cho persistent volumes
- Security setup cho cluster access

### Với Tầng Monitoring
- Network monitoring cho performance
- VM health monitoring
- Service availability monitoring
- Security event monitoring

## 📈 Tối Ưu Performance

### Quản lý Tài nguyên
- Configure VM resource limits appropriately
- Optimize network bandwidth allocation
- Set up proper storage I/O controls
- Monitor resource usage patterns

### Network Optimization
- Enable jumbo frames where appropriate
- Configure proper VLAN segmentation
- Optimize vSwitch configurations
- Monitor network performance metrics

### Automation Efficiency
- Minimize startup times with parallel execution
- Optimize script performance
- Implement proper error handling
- Monitor automation success rates

## 🔐 Best Practices Bảo mật

### Network Security
- Implement proper VLAN segmentation
- Configure firewall rules restrictively
- Use strong authentication mechanisms
- Monitor network traffic for anomalies

### Access Control
- Limit administrative access
- Use SSH keys instead of passwords
- Implement proper user permissions
- Regular security audits

### Monitoring và Logging
- Enable comprehensive logging
- Set up security alerts
- Monitor for suspicious activities
- Regular log analysis

## 📞 Hỗ trợ và Troubleshooting

### Vấn đề Thường gặp
- Wake-on-LAN không hoạt động
- VM không tự động khởi động
- Network connectivity issues
- Port forwarding failures
- Performance problems

### Tài nguyên Debug
- System logs và event monitoring
- Network diagnostic tools
- ESXi logs và performance metrics
- Router configuration verification
- Security audit tools

## 🎯 Bước Tiếp theo

Sau khi hoàn thành phần Infrastructure này, tiếp tục với:
1. **[02-Services](../02-services/index.md)** - Deploy core services
2. **[03-Kubernetes](../03-kubernetes/index.md)** - Container orchestration
3. **[04-CI/CD](../04-cicd/index.md)** - Automation pipelines

---

**Lưu ý**: Infrastructure là nền tảng của toàn bộ hệ thống. Hãy đảm bảo tất cả components hoạt động ổn định trước khi tiếp tục các tầng tiếp theo.

**Triết lý**: **Nền tảng vững chắc → Dịch vụ ổn định → Tự động hóa toàn diện** 