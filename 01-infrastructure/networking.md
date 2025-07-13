# ESXi Networking Knowledge

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Physical NIC (vmnic)](#physical-nic-vmnic)
3. [Virtual Switch (vSwitch)](#virtual-switch-vswitch)
4. [Port Groups](#port-groups)
5. [Network Configuration](#network-configuration)
6. [Troubleshooting](#troubleshooting)

## Giới thiệu

Tài liệu này cung cấp kiến thức chi tiết về lý thuyết networking trong môi trường VMware ESXi. Nội dung bao gồm các khái niệm cơ bản về virtual networking, cách thức hoạt động của virtual switches, port groups, VLAN configuration, cũng như các best practices để thiết kế và triển khai hạ tầng mạng ảo hóa hiệu quả và bảo mật.

### Tại sao cần hiểu ESXi Networking?

- **Infrastructure Foundation**: Networking là nền tảng cho tất cả services trong ESXi
- **Security**: Hiểu cách isolate và protect network traffic
- **Performance**: Optimize network performance cho VMs
- **Troubleshooting**: Giải quyết network issues hiệu quả

---

## Physical NIC (vmnic)

### 🔹 vmnic là gì và hoạt động ra sao?

**vmnic = Physical Network Interface Card = Card mạng vật lý**

```
┌─────────────────────────────────────────────────────────────┐
│                    Server Hardware                          │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │   CPU    │    │  Memory  │    │ vmnic0   │──────────────┼──► Dây mạng vật lý
│  │          │    │          │    │ r8168    │              │    (RJ45 cable)
│  └──────────┘    └──────────┘    │ driver   │              │
│                                  └──────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### 🔹 Cách vmnic xử lý data:

**Khi nhận data từ mạng vật lý:**
```
Internet ──► Switch vật lý ──► vmnic0 ──► ESXi kernel ──► Phân phối đến VM
```

**Khi gửi data ra ngoài:**
```
VM ──► vSwitch ──► ESXi kernel ──► vmnic0 ──► Switch vật lý ──► Internet
```

### 📊 Thông tin Physical NIC (vmnic)

#### Xem thông tin vmnic:
```bash
# SSH vào ESXi
ssh root@esxi-ip

# Xem danh sách network adapters
esxcli network nic list

# Xem chi tiết một NIC
esxcli network nic get -n vmnic0

# Xem driver information
ethtool vmnic0
```

#### Ví dụ output:
```
Name    PCI Device    Driver  Link  Speed  MAC Address
vmnic0  0000:02:00.0  r8168   Up    1000   00:e0:25:30:50:7b
```

### 🎯 Thông số quan trọng:

- **Driver (r8168)**: Phần mềm điều khiển hardware
- **MAC Address**: Địa chỉ vật lý duy nhất (00:e0:25:30:50:7b)
- **Speed**: Tốc độ truyền tải (1000 Mbps = 1 Gbps)
- **Link State**: Up/Down status

#### Auto-Negotiate:
- Là cơ chế tự động đàm phán giữa card mạng và thiết bị đầu cuối
- Hai bên sẽ tự thỏa thuận về:
  - Tốc độ truyền tải (Speed)
  - Chế độ duplex (Half/Full)
- Giúp tối ưu hiệu suất kết nối
- Tránh xung đột cấu hình thủ công

#### Link Speed & Duplex:
- **Link Speed**: Tốc độ truyền tải dữ liệu (10/100/1000 Mbps)
- **Full duplex**: Cho phép truyền và nhận dữ liệu đồng thời
- **Half duplex**: Chỉ truyền hoặc nhận tại một thời điểm

---

## Virtual Switch (vSwitch)

### 🔄 vSwitch hoạt động như thế nào?

**vSwitch = Switch ảo bên trong ESXi**, hoạt động giống switch vật lý:

```
┌─────────────────────────────────────────────────────────────────┐
│                           ESXi Host                             │
│                                                                 │
│  ┌─────┐     ┌───────────────┐                                  │
│  │ VM1 │─────┤               │     ┌─────────────┐              │
│  └─────┘     │               │─────┤   Switch    │              │
│              │   vSwitch     │     │   vật lý    │              │
│  ┌─────┐     │               │     └─────────────┘              │
│  │ VM2 │─────┤               │                                  │
│  └─────┘     └───────┬───────┘                                  │
│                      │                                          │
│                      ▲                                          │
│                 vmkernel                                        │
│               (Management)                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 🏗️ vSwitch Architecture chi tiết:

```
┌─────────────────────────────────────────────────────────────────┐
│                     vSwitch Architecture                        │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌───────────┐                    │
│  │   VM1    │   │   VM2    │   │   vmk0    │                    │
│  │ (eth0)   │   │ (eth0)   │   │(Management│                    │
│  └────┬─────┘   └────┬─────┘   └────┬──────┘                    │
│       │              │              │                          │
│       ▼              ▼              ▼                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                vSwitch Ports                              │   │
│  │   Port 1     Port 2     Port 3    ...Port N             │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │                                       │
│                        ▼                                       │
│  ┌─────────────────────────────────┐  ◄──── MAC Address Table │
│  │        Switching Logic          │       Learning & Forward │
│  │        - Flooding               │                          │
│  │        - Learning               │                          │
│  │        - Forwarding             │                          │
│  └─────────────────────┬───────────┘                          │
│                        │                                       │
│                        ▼                                       │
│  ┌─────────────────────────────────┐                          │
│  │        Uplink Port              │──────────────────────────┼──► vmnic0
│  │        (vmnic0)                 │                          │
│  └─────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 Chức năng của vSwitch:

1. **Kết nối các VM với nhau** (internal communication)
2. **Kết nối VM ra ngoài** (thông qua uplink)
3. **Quản lý traffic** (filtering, VLAN tagging)
4. **Load balancing** (với multiple uplinks)
5. **Security** (port security, VLAN isolation)

### 🧠 vSwitch Processing Logic:

#### Bước 1: Nhận Frame
```python
# Giả sử VM1 gửi data đến VM2
Frame từ VM1 = {
    'src_mac': '00:50:56:xx:xx:01',  # MAC của VM1
    'dst_mac': '00:50:56:xx:xx:02',  # MAC của VM2
    'data': 'Hello VM2!'
}
```

#### Bước 2: MAC Address Learning
```python
# vSwitch học MAC address
MAC_Table = {
    'Port 1': '00:50:56:xx:xx:01',  # VM1 ở Port 1
    'Port 2': '00:50:56:xx:xx:02',  # VM2 ở Port 2
}
```

#### Bước 3: Forwarding Decision
```python
if dst_mac in MAC_Table:
    # Biết chính xác port đích
    forward_to_port(MAC_Table[dst_mac])
else:
    # Không biết, flood tất cả ports
    flood_to_all_ports()
```

### 🔗 Sự liên kết giữa vSwitch và Physical NIC (vmnic)

#### 1. Uplink Connection:
- **vSwitch** kết nối với **vmnic0** thông qua **Uplink Port**
- Mọi traffic từ VM muốn ra ngoài Internet đều phải đi qua uplink này
- **vmnic0** là cầu nối duy nhất giữa thế giới ảo (vSwitch) và thế giới thật (mạng vật lý)

#### 2. Data Flow Integration:
```
VM1 ──► vSwitch Port 1 ──► Switching Logic ──► Uplink Port ──► vmnic0 ──► Internet
```

#### 3. Traffic Direction:
- **Inbound**: `Internet → vmnic0 → vSwitch → VM`
- **Outbound**: `VM → vSwitch → vmnic0 → Internet`
- **Internal**: `VM1 → vSwitch → VM2` (không cần vmnic0)

---

## Port Groups

### 🏷️ Port Group là gì?

**Port Group = Container chứa các policy cho một nhóm ports**

```
┌─────────────────────────────────────────────────────────────────┐
│                          Port Group                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Network Policies                      │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  Security   │  │   Traffic   │  │    VLAN     │     │   │
│  │  │   Policy    │  │   Shaping   │  │   Tagging   │     │   │
│  │  │             │  │             │  │             │     │   │
│  │  │- Promiscuous│  │- Bandwidth  │  │- VLAN ID    │     │   │
│  │  │- MAC Change │  │- Burst Size │  │- Trunk/Access│     │   │
│  │  │- Forged TX  │  │- Peak Rate  │  │             │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                        Ports                            │   │
│  │   Port A     Port B     Port C     Port D              │   │
│  │      │          │          │          │                │   │
│  │      ▼          ▼          ▼          ▼                │   │
│  │     VM1        VM2        VM3       vmk1               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 🏢 Ví dụ thực tế trong công ty:

**Công ty có 3 phòng ban:**
```
🏢 XYZ Company
├── 👔 Phòng Quản lý (Management) - Mạng riêng biệt
├── 🏭 Phòng Sản xuất (Production) - Mạng bảo mật cao  
└── 🧪 Phòng Thí nghiệm (Test) - Mạng thử nghiệm
```

**Tạo Port Groups tương ứng:**
```
vSwitch0
├── Management-PG (VLAN 10)
│   ├── VM-Manager-01
│   ├── VM-Manager-02
│   └── vmk0 (ESXi Management)
├── Production-PG (VLAN 20)
│   ├── VM-Web-Server
│   ├── VM-Database
│   └── VM-App-Server
└── Test-PG (VLAN 30)
    ├── VM-Test-01
    ├── VM-Test-02
    └── VM-Dev-Environment
```

### 🔧 Cấu hình Port Groups:

#### 1. Tạo Port Group qua ESXi Web UI:
```
Networking → Virtual Switches → vSwitch0 → Port Groups → Add port group
```

#### 2. Tạo Port Group qua CLI:
```bash
# Tạo port group
esxcli network vswitch standard portgroup add -p "Production-PG" -v "vSwitch0"

# Set VLAN ID
esxcli network vswitch standard portgroup set -p "Production-PG" -v 20

# Xem danh sách port groups
esxcli network vswitch standard portgroup list
```

### 🛡️ Security Policies trong Port Groups:

#### 1. Promiscuous Mode:
- **Accept**: VM có thể nhận tất cả traffic trên network segment
- **Reject**: VM chỉ nhận traffic được gửi đến nó
- **Inherit**: Sử dụng setting từ vSwitch level

#### 2. MAC Address Changes:
- **Accept**: VM có thể thay đổi MAC address của virtual NIC
- **Reject**: VM không thể thay đổi MAC address
- **Inherit**: Sử dụng setting từ vSwitch level

#### 3. Forged Transmits:
- **Accept**: VM có thể gửi frames với MAC address khác
- **Reject**: VM không thể gửi frames với MAC address khác
- **Inherit**: Sử dụng setting từ vSwitch level

---

## Network Configuration

### 🔧 Cấu hình cơ bản

#### 1. Tạo vSwitch mới:
```bash
# Tạo vSwitch
esxcli network vswitch standard add -v "vSwitch1"

# Thêm uplink (vmnic)
esxcli network vswitch standard uplink add -u "vmnic1" -v "vSwitch1"

# Xem cấu hình
esxcli network vswitch standard list
```

#### 2. Cấu hình VMkernel Interface:
```bash
# Tạo VMkernel interface cho management
esxcli network ip interface add -i "vmk1" -p "Management"

# Set IP address
esxcli network ip interface ipv4 set -i "vmk1" -I "192.168.1.100" -N "255.255.255.0" -t static

# Enable management traffic
esxcli network ip interface tag add -i "vmk1" -t Management
```

#### 3. Cấu hình VLAN:
```bash
# Tạo VLAN tagged port group
esxcli network vswitch standard portgroup add -p "VLAN-100" -v "vSwitch0"
esxcli network vswitch standard portgroup set -p "VLAN-100" -v 100

# Tạo VLAN trunk port group (4095 = trunk all VLANs)
esxcli network vswitch standard portgroup set -p "Trunk-PG" -v 4095
```

### 📊 Network Monitoring

#### 1. Xem network statistics:
```bash
# Network interface stats
esxcli network ip interface list
esxcli network ip interface ipv4 get

# vSwitch stats
esxcli network vswitch standard list

# Port group stats
esxcli network vswitch standard portgroup list
```

#### 2. Network troubleshooting:
```bash
# Test connectivity
vmkping -I vmk0 192.168.1.1

# Check routing table
esxcli network ip route ipv4 list

# Check ARP table
esxcli network ip neighbor list
```

### 🌐 Advanced Network Features

#### 1. Load Balancing:
```bash
# Set load balancing policy
esxcli network vswitch standard policy failover set -v "vSwitch0" -l "portid"

# Options:
# - portid: Based on originating port ID
# - iphash: Based on IP hash
# - mac: Based on source MAC address
# - explicit: Use explicit failover order
```

#### 2. Network Failover:
```bash
# Set failover policy
esxcli network vswitch standard policy failover set -v "vSwitch0" -f true

# Set active/standby uplinks
esxcli network vswitch standard policy failover set -v "vSwitch0" -a "vmnic0" -s "vmnic1"
```

---

## Troubleshooting

### 🔍 Common Network Issues

#### 1. VM không kết nối được network:
```bash
# Check port group assignment
esxcli network vswitch standard portgroup list

# Check vSwitch uplinks
esxcli network vswitch standard list

# Check vmnic status
esxcli network nic list
```

#### 2. Slow network performance:
```bash
# Check for duplex mismatches
ethtool vmnic0

# Check for packet drops
esxcli network nic stats get -n vmnic0

# Check vSwitch load balancing
esxcli network vswitch standard policy failover get -v "vSwitch0"
```

#### 3. VLAN connectivity issues:
```bash
# Check VLAN configuration
esxcli network vswitch standard portgroup list

# Test VLAN connectivity
vmkping -I vmk0 -S vlan192.168.1.1 192.168.1.100

# Check physical switch configuration
# (This needs to be done on physical switch)
```

### 🛠️ Network Diagnostic Tools

#### 1. ESXi built-in tools:
```bash
# Packet capture
pktcap-uw --uplink vmnic0 --capture UplinkSnd,UplinkRcv

# Network I/O stats
esxtop (press 'n' for network view)

# Check network queues
esxcli network nic queue stats get -n vmnic0
```

#### 2. Log file locations:
```bash
# Network logs
tail -f /var/log/vmkernel.log | grep -i network

# VMware Tools logs
tail -f /var/log/vmware-vmsvc.log
```

### 📋 Best Practices

1. **Redundancy**: Use multiple uplinks for vSwitch
2. **VLAN Segmentation**: Separate traffic types với VLANs
3. **Security**: Apply appropriate security policies
4. **Monitoring**: Regular monitoring of network performance
5. **Documentation**: Maintain network topology documentation

---

## Next Steps

Sau khi hoàn thành Networking configuration, bạn có thể tiến tới:

1. **[Port Forwarding](port-forwarding.md)** - Expose services ra internet
2. **[VPN Server Setup](../02-services/vpn-server.md)** - Secure remote access
3. **[Monitoring Setup](../02-services/monitoring.md)** - Network monitoring

---

## Tham khảo

- [VMware vSphere Networking Guide](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [ESXi Networking Best Practices](https://docs.vmware.com/en/VMware-vSphere/7.0/vsphere-esxi-vcenter-server-703-networking-guide.pdf)
- [Virtual Switch Configuration](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.networking.doc/GUID-35B40B0B-0C13-43B2-BC85-18C9C91BE2D4.html) 