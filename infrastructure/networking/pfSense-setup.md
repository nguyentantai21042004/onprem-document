# Hướng dẫn tạo Subnet mới trong ESXi và cài đặt pfSense Router

## Tổng quan

Tài liệu này hướng dẫn chi tiết cách tạo network infrastructure cô lập trong ESXi sử dụng pfSense làm router/firewall để kết nối các subnet khác nhau. Phù hợp cho việc tạo môi trường production với network segmentation.

## Kiến trúc mục tiêu

```
Internet
    │
Router nhà (192.168.1.1)
    │
ESXi Host (192.168.1.100)
    │
┌─────────────────────────────────┐
│ vSwitch0 (vmnic0 - Physical)    │
│ └── VM Network (192.168.1.0/24) │
│     ├── pfSense WAN: 192.168.1.190
│     └── Management VMs          │
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ pfSense VM (Router/Firewall)    │
│ ├── WAN: vmx0 (192.168.1.190)   │
│ └── LAN: vmx1 (172.16.1.1)      │
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ vSwitch-DB (Isolated)           │
│ └── DB-Network (172.16.1.0/24)  │
│     ├── Gateway: 172.16.1.1     │
│     ├── DHCP: 172.16.1.10-50    │
│     └── Database VMs            │
└─────────────────────────────────┘
```

## Phase 1: Tạo Network Infrastructure

### 2.1 Tạo Virtual Switch mới - Bước chi tiết

#### Bước 1: Truy cập vSphere Client

**Thao tác:**
1. Mở trình duyệt → `https://[ESXi-IP]`
2. Login với root credentials
3. Chọn Host trong Navigator (panel bên trái)

**Giải thích:**
- vSphere Client là giao diện web để quản lý ESXi
- Host là máy chủ ESXi vật lý của bạn
- Phải login với tài khoản root mới có quyền tạo network

#### Bước 2: Tạo Virtual Switch

**Thao tác:**
1. Click "Networking" tab (bên trái màn hình)
2. Click "Virtual switches" tab (ở giữa)
3. Click "Add standard virtual switch" (nút xanh)

**Giải thích Virtual Switch:**
- Virtual Switch (vSwitch) giống như switch vật lý, nhưng hoạt động bằng software
- Standard vSwitch là loại switch cơ bản, chỉ hoạt động trên 1 ESXi host
- Distributed vSwitch cần vCenter, hoạt động trên nhiều ESXi hosts

**Tại sao cần tạo vSwitch mới?**
- vSwitch hiện tại (vSwitch0) kết nối với card mạng vật lý → ra internet
- vSwitch mới (vSwitch-DB) sẽ không kết nối với card mạng vật lý → network cô lập
- Database VMs chỉ có thể giao tiếp qua pfSense, không thể ra internet trực tiếp

#### Bước 3: Cấu hình Virtual Switch

Cửa sổ popup "Add standard virtual switch":

**Name (Tên):**
```
vSwitch Name: vSwitch-DB
```
- Giải thích: Tên để nhận diện switch, nên đặt có ý nghĩa (DB = Database)

**MTU (Maximum Transmission Unit):**
```
MTU: 1500 (default)
```
- Giải thích: MTU là kích thước packet lớn nhất có thể truyền
- 1500 bytes là standard cho Ethernet
- Không nên thay đổi trừ khi có yêu cầu đặc biệt

**Number of ports:**
```
Number of ports: 128 (default)
```
- Giải thích: Số port ảo tối đa mà switch có thể hỗ trợ
- 128 ports đủ cho hầu hết use cases nhỏ
- Mỗi VM sẽ dùng 1 port

**Security Settings:**
```
├── Promiscuous mode: Reject 
├── MAC address changes: Accept 
└── Forged transmits: Accept 
```

**Giải thích từng option:**
- **Promiscuous mode: Reject** - VM không thể "nghe lén" traffic của VMs khác (bảo mật)
- **MAC address changes: Accept** - VM có thể thay đổi MAC address (cần cho một số ứng dụng)
- **Forged transmits: Accept** - VM có thể gửi packets với MAC address khác (cần cho virtualization)

**⚠ QUAN TRỌNG NHẤT:**
```
"Add a physical network adapter" → KHÔNG TICK 
```
**Giải thích:**
- Physical network adapter là card mạng vật lý (vmnic0)
- KHÔNG tick = vSwitch này hoàn toàn isolated, không kết nối ra ngoài
- Đây là điểm then chốt tạo network cô lập cho database

#### Bước 4: Tạo Port Group

**Thao tác:**
1. Vẫn trong "Virtual switches" tab
2. Click vào vSwitch-DB vừa tạo (sẽ hiển thị details)
3. Click "Add port group" (nút xanh)

**Giải thích Port Group:**
- Port Group là nhóm các ports có cùng cấu hình
- Giống như VLAN trong switch vật lý
- VMs sẽ kết nối vào Port Group, không phải trực tiếp vào vSwitch

**Cấu hình Port Group:**
```
├── Name: DB-Network
├── VLAN ID: 0 (None)
├── vSwitch: vSwitch-DB (auto-selected)
└── Security: Inherit from vSwitch
```

**Giải thích từng field:**
- **Name: DB-Network** - Tên port group, VMs sẽ thấy tên này khi chọn network
- **VLAN ID: 0** - Không dùng VLAN tagging (None/untagged)
- **vSwitch: vSwitch-DB** - Port group thuộc vSwitch nào
- **Security: Inherit** - Dùng security settings từ vSwitch

### 2.2 Kiểm tra kết quả tạo network

**Kiểm tra trong vSphere Client:**
Networking → Virtual switches sẽ hiển thị:

```
vSwitch0 (Management & VM Network)
├── Physical adapter: vmnic0 ← Kết nối card mạng vật lý
├── Uplinks: 1 active
├── Port groups:
│   ├── Management Network (ESXi management)
│   └── VM Network (VMs hiện tại - 192.168.1.0/24)
└── Status: Connected ← Có internet

vSwitch-DB (Database Network) ← MỚI TẠO
├── Physical adapter: None ← KHÔNG có card mạng vật lý
├── Uplinks: 0 active
├── Port groups:
│   └── DB-Network (Database VMs - 172.16.1.0/24)
└── Status: Connected ← Hoạt động nhưng isolated
```

**Giải thích sự khác biệt:**

**vSwitch0 (Network hiện tại):**
- Physical adapter: vmnic0 → Có thể ra internet
- Uplinks: 1 active → Kết nối vật lý hoạt động
- VM Network → VMs hiện tại dùng network này

**vSwitch-DB (Network mới):**
- Physical adapter: None → KHÔNG thể ra internet trực tiếp
- Uplinks: 0 active → Không có kết nối vật lý
- DB-Network → Database VMs sẽ dùng network này

**Xác nhận network isolation:**
```bash
# SSH vào ESXi Host
esxcli network vswitch standard list
```

Kết quả mong muốn:
```
vSwitch0:
   Name: vSwitch0
   Physical adapters: vmnic0
   
vSwitch-DB:
   Name: vSwitch-DB
   Physical adapters: (empty) ← Isolated network
```

## Phase 2: Cài đặt pfSense VM

### 3.1 Download & Upload pfSense ISO

#### Download pfSense ISO

1. Truy cập: https://www.pfsense.org/download/
2. Chọn:
   - Architecture: AMD64 (Intel/AMD 64-bit)
   - Installer: DVD Image (ISO)
   - Mirror: Gần nhất với location của bạn
3. Download file: `pfSense-CE-2.x.x-RELEASE-amd64.iso`

#### Upload ISO lên ESXi

**Thao tác:**
1. vSphere Client → Storage
2. Click vào datastore (thường là `datastore1`)
3. Click "Datastore browser"
4. Tạo folder: `ISO-Images` (nếu chưa có)
5. Click "Upload files" → Chọn pfSense ISO
6. Chờ upload hoàn tất

**Path sau khi upload:**
```
/vmfs/volumes/datastore1/ISO-Images/pfSense-CE-x.x.x.iso
```

### 3.2 Tạo pfSense VM

#### VM Creation Wizard

**Thao tác:**
1. vSphere Client → Virtual Machines
2. Click "Create/Register VM"
3. Select creation type: "Create a new virtual machine"

#### VM Configuration

**1. VM Name and Guest OS:**
```
Name: pfSense-Router
Compatibility: ESXi 6.7 and later (default)
Guest OS family: Other
Guest OS version: FreeBSD 12 (64-bit)
```

**2. Storage Selection:**
```
Datastore: datastore1 (default)
```

**3. VM Hardware:**
```
CPU: 1 vCPU (đủ cho pfSense)
Memory: 2048 MB (2GB RAM)
Hard disk 1: 20 GB, Thin provisioned
Network Adapter 1: VM Network (WAN connection)
Network Adapter 2: DB-Network (LAN connection)
CD/DVD Drive 1: Datastore ISO file → Browse → pfSense ISO
```

**⚠ QUAN TRỌNG - Network Adapters:**
- **Network Adapter 1**: VM Network (kết nối WAN - ra internet)
- **Network Adapter 2**: DB-Network (kết nối LAN - isolated network)
- Thứ tự này quan trọng cho interface assignment

#### Advanced Settings

```
Boot Options:
├── Firmware: BIOS (khuyến nghị cho pfSense)
└── Boot delay: 3000 milliseconds

VM Options:
└── VMware Tools: Không cần (pfSense không support)
```

### 3.3 Cài đặt pfSense

#### Boot và Install

1. **Power On VM:**
   - Right-click pfSense-Router → Power → Power On
   - Click "Launch Web Console" để xem

2. **pfSense Boot Menu:**
   ```
   >>> FreeBSD/i386 BOOT
   Default: 0:ad(0,a)/boot/loader
   boot: [enter] ← Nhấn Enter
   ```

3. **pfSense Installation:**
   ```
   Welcome to pfSense!
   
   1) Boot Multi User [Enter]
   2) Boot Single user
   3) Escape to loader prompt
   4) Reboot
   
   → Chọn 1 hoặc chờ auto boot
   ```

4. **Install Process:**
   ```
   pfSense installer
   
   Install pfSense → [OK]
   Accept → [Accept] ← Accept license
   Install → Quick/Easy Install → [OK]
   ```

5. **Disk Partitioning:**
   ```
   Partition → Auto (UFS) → [OK] ← Automatic partitioning
   Last Chance! → [OK] ← Confirm installation
   ```

6. **Installation Complete:**
   ```
   Installation Complete
   
   Reboot → [Reboot] ← Restart VM
   ```

#### Post-Installation

**Remove ISO:**
1. VM powering off → Edit VM settings
2. CD/DVD Drive 1 → Client Device → OK
3. Power on VM again

**First Boot:**
```
Welcome to pfSense 2.x.x-RELEASE...

VLANs setup:
Do you want to set up VLANs now [y|n]? → n ← Không dùng VLANs

Interface assignment:
Enter the WAN interface name: vmx0 ← First network adapter
Enter the LAN interface name: vmx1 ← Second network adapter
Do you want to proceed [y|n]? → y ← Confirm
```

### 3.4 Interface Assignment & IP Configuration

#### WAN Interface Setup

```
pfSense Console Menu:

*** Welcome to pfSense 2.x.x-RELEASE ***

1) Assign Interfaces
2) Set interface(s) IP address  ← Chọn option 2
3) Reset webConfigurator password
4) Reset to factory defaults
5) Reboot system
6) Halt system
7) Ping host
8) Shell
9) pfTop
10) Filter Logs
11) Restart webConfigurator
12) PHP shell + pfSense tools
13) Update from console
14) Disable Secure Shell (sshd)

Enter an option: 2
```

**WAN Configuration:**
```
1 - WAN (vmx0 - dhcp)
2 - LAN (vmx1 - static)

Enter the number of the interface you wish to configure: 1 ← WAN

Configure IPv4 address WAN interface via DHCP? [y|n] → n ← Static IP
IPv4 Address: 192.168.1.190 ← IP trong mạng nhà
Subnet bit count: 24 ← /24 subnet
IPv4 Gateway: 192.168.1.1 ← Router nhà

Configure IPv6 address WAN interface via DHCP6? [y|n] → n ← Không dùng IPv6

Do you want to revert to HTTP as the webConfigurator protocol? [y|n] → y ← Enable HTTP
```

#### LAN Interface Setup

```
Enter an option: 2 ← Set interface IP again

1 - WAN (vmx0 - static)
2 - LAN (vmx1 - static)

Enter the number of the interface you wish to configure: 2 ← LAN

IPv4 Address: 172.16.1.1 ← Gateway cho isolated network
Subnet bit count: 24 ← /24 subnet

IPv4 Gateway: [enter] ← Để trống (LAN không cần gateway)

Configure IPv6 address LAN interface? [y|n] → n ← Không dùng IPv6

Do you want to enable the DHCP server on LAN? [y|n] → y ← Enable DHCP
DHCP Start address: 172.16.1.10
DHCP End address: 172.16.1.50

Do you want to revert to HTTP as the webConfigurator protocol? [y|n] → y
```

### 3.5 Truy cập Web Interface

#### Disable Firewall để truy cập Web Interface

**⚠ Vấn đề phổ biến:** Không thể truy cập web interface từ WAN

**Nguyên nhân:**
- pfSense mặc định block WAN access tới web interface
- Anti-lockout rules chưa configured properly

**Giải pháp nhanh - Disable Firewall:**
```bash
Enter an option: 8  ← Shell
pfctl -d            ← Disable pfSense firewall
exit
```

**Giải thích lệnh `pfctl -d`:**
- `pfctl` = Packet Filter Control (FreeBSD firewall)
- `-d` flag = Disable firewall rules temporarily
- Effect: Allow ALL traffic through (no filtering)
- Result: Web interface immediately accessible

#### Truy cập Web Interface

**Từ máy tính trong mạng 192.168.1.0/24:**
```
URL: http://192.168.1.190
Username: admin
Password: pfsense
```

**Lần đầu truy cập - Setup Wizard:**
1. **Welcome:** Next
2. **General Information:**
   ```
   Hostname: pfSense
   Domain: localdomain
   Primary DNS Server: 8.8.8.8
   Secondary DNS Server: 8.8.4.4
   ```
3. **Time Zone:** Chọn timezone phù hợp
4. **WAN Interface:** Confirm current settings
5. **LAN Interface:** Confirm current settings
6. **Admin Password:** Đổi password mặc định
7. **Reload Configuration:** Finish

## Phase 3: Firewall Configuration

### 4.1 Hiểu về pfSense Firewall States

#### Firewall Architecture
```
Internet → pfSense WAN → Firewall Rules → Internal Services
```

#### Default Behavior
- pfSense blocks WAN access to web interface by default
- Only LAN access allowed initially
- Anti-lockout protection prevents admin lockout
- Need proper rules hoặc disable firewall temporarily

#### Firewall States

**Enabled (Default Production Mode):**
```bash
pfctl -e    # Enable firewall
```
- Security rules active
- WAN access blocked by default
- LAN access allowed
- Proper production mode

**Disabled (Troubleshooting Mode):**
```bash
pfctl -d    # Disable firewall  
```
- NO security rules active
- ALL access allowed from everywhere
- Easy troubleshooting và initial setup
- NOT for production use

**Check Status:**
```bash
pfctl -s info    # Show firewall status
pfctl -s rules   # Show active rules
```

### 4.2 Mở lại Firewall và cấu hình Production Rules

#### Bước 1: Enable lại Firewall

**Từ pfSense Console:**
```bash
Enter an option: 8  ← Shell
pfctl -e            ← Enable firewall
exit
```

**Hoặc từ Web Interface:**
1. Status → Filter Reload
2. Firewall → Rules
3. Enable/Disable → Enable

#### Bước 2: Tạo WAN Access Rules (Nếu cần)

**⚠ Cảnh báo:** Chỉ làm nếu thực sự cần truy cập WAN, không khuyến nghị cho production

**Từ Web Interface:**
1. **Firewall → Rules → WAN**
2. **Add Rule (↑ button):**
   ```
   Action: Pass
   Interface: WAN
   Address Family: IPv4
   Protocol: TCP
   Source: Any (hoặc specific IP range)
   Destination: WAN address
   Destination Port Range: HTTP (80) và HTTPS (443)
   Description: Web Interface Access from WAN
   ```
3. **Save → Apply Changes**

#### Bước 3: Cấu hình LAN to WAN Rules

**Default LAN Rules:**
1. **Firewall → Rules → LAN**
2. **Kiểm tra có rule:**
   ```
    Default allow LAN to any rule
   Action: Pass
   Source: LAN net
   Destination: Any
   ```

**Nếu không có, tạo rule:**
```
Action: Pass
Interface: LAN
Address Family: IPv4
Protocol: Any
Source: LAN net
Destination: Any
Description: Allow LAN to Any
```

#### Bước 4: Cấu hình Inter-VLAN Routing

**Cho phép DB-Network access internet qua pfSense:**
1. **Firewall → Rules → LAN**
2. **Add specific rules nếu cần:**
   ```
   Rule 1: Database to Internet
   ├── Action: Pass
   ├── Source: LAN net (172.16.1.0/24)
   ├── Destination: !LAN net (not local)
   └── Description: Database VMs internet access
   
   Rule 2: Database Internal Communication
   ├── Action: Pass
   ├── Source: LAN net
   ├── Destination: LAN net
   └── Description: Database internal traffic
   ```

### 4.3 Advanced Security Configuration

#### NAT Configuration

**Outbound NAT:**
1. **Firewall → NAT → Outbound**
2. **Mode: Automatic** (recommended)
3. **Verify rule exists:**
   ```
   Interface: WAN
   Source: 172.16.1.0/24
   Translation: WAN address
   ```

#### Logging và Monitoring

**Enable Firewall Logging:**
1. **Status → System Logs → Firewall**
2. **Settings:**
   ```
    Log firewall default blocks
    Log packets matched by pflog
   Log Level: Informational
   ```

**Real-time Monitoring:**
```
Status → System Logs → Firewall (Live View)
Diagnostics → pfTop (real-time states)
Diagnostics → States Summary
```

### 4.4 Production Security Best Practices

#### Firewall Rules Order
```
1. Block bogon networks (anti-spoofing)
2. Allow established/related connections
3. Allow specific required services
4. Log and block everything else (default deny)
```

#### Security Hardening
```
System → Advanced → Admin Access:
├── Protocol: HTTPS only
├── Port: Custom port (not 443)
├── Login Protection: Enable
└── Anti-lockout: Enable

System → Advanced → Networking:
├── Block private networks: Enable on WAN
├── Block bogon networks: Enable on WAN
└── Hardware Checksum Offloading: Disable (for VMs)
```

#### Backup Configuration
```
Diagnostics → Backup & Restore:
├── Download config: XML file
├── Schedule automatic backups
└── Test restore procedure
```

## Network Topology Final

```
Internet
    │
Router nhà (192.168.1.1)
    │
ESXi Host (192.168.1.100)
    │
┌─────────────────────────────────┐
│ vSwitch0 (vmnic0 - Physical)    │
│ └── VM Network (192.168.1.0/24) │
│     ├── pfSense WAN: 192.168.1.190
│     └── Management VMs          │
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ pfSense VM (Router/Firewall)    │
│ ├── WAN: vmx0 (192.168.1.190)   │
│ └── LAN: vmx1 (172.16.1.1)      │
│ Firewall: ENABLED (Production)  │
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ vSwitch-DB (Isolated)           │
│ └── DB-Network (172.16.1.0/24)  │
│     ├── Gateway: 172.16.1.1     │
│     ├── DHCP: 172.16.1.10-50    │
│     └── Database VMs            │
└─────────────────────────────────┘
```

## Troubleshooting Common Issues

### Không thể truy cập Web Interface

**Triệu chứng:** Timeout khi access http://192.168.1.190

**Nguyên nhân & Giải pháp:**
1. **Firewall blocking:**
   ```bash
   # Temporary disable
   pfctl -d
   
   # Permanent solution: Create WAN access rule
   Firewall → Rules → WAN → Add rule
   ```

2. **Network connectivity:**
   ```bash
   # Test from pfSense console
   Option 7: ping 192.168.1.1    # Router test
   Option 7: ping 8.8.8.8        # Internet test
   ```

3. **Service not running:**
   ```bash
   Option 11: Restart GUI         # Restart web service
   ```

### VMs trong DB-Network không có internet

**Triệu chứng:** Database VMs không thể ping ra ngoài

**Kiểm tra:**
1. **DHCP assignment:**
   ```
   Status → DHCP Leases
   → Verify VMs có IP 172.16.1.x
   ```

2. **Gateway setting trên VMs:**
   ```bash
   # Linux VMs
   ip route show
   # Should see: default via 172.16.1.1
   ```

3. **Firewall rules:**
   ```
   Firewall → Rules → LAN
   → Verify "allow LAN to any" rule exists
   ```

### pfSense VM không boot

**Triệu chứng:** VM stuck ở BIOS hoặc boot loop

**Giải pháp:**
1. **BIOS settings:**
   ```
   VM Settings → VM Options → Boot Options
   ├── Firmware: BIOS (not UEFI)
   └── Boot delay: 3000ms
   ```

2. **ISO mounting:**
   ```
   Verify ISO path:
   /vmfs/volumes/datastore1/ISO-Images/pfSense-xxx.iso
   ```

3. **Hardware compatibility:**
   ```
   VM Settings → Compatibility
   → ESXi 6.7 and later
   ```

## Kết luận

### Achievements
 **Network Infrastructure:**
- Isolated subnet cho database (172.16.1.0/24)
- pfSense router kết nối các networks
- Firewall protection giữa subnets
- DHCP server cho automatic IP assignment

 **Security:**
- Network segmentation và isolation
- Controlled access giữa subnets
- Firewall rules cho traffic filtering
- Anti-lockout protection

 **Management:**
- Web interface accessible
- SSH access available
- Console management functional
- Production-ready configuration

### Next Steps
- Deploy database VMs vào DB-Network
- Configure specific firewall rules cho requirements
- Set up monitoring và logging
- Implement backup procedures
- Test disaster recovery scenarios

**pfSense + ESXi network segmentation = Foundation hoàn thiện cho production infrastructure! ** 