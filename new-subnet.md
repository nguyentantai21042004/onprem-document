Phase 1: Tạo Network Infrastructure
2.1 Tạo Virtual Switch mới - Bước chi tiết với giải thích
Bước 1: Truy cập vSphere Client
Thao tác:
1. Mở trình duyệt → https://[ESXi-IP]
2. Login với root credentials
3. Chọn Host trong Navigator (panel bên trái)
Giải thích:

vSphere Client là giao diện web để quản lý ESXi
Host là máy chủ ESXi vật lý của bạn
Phải login với tài khoản root mới có quyền tạo network


Bước 2: Tạo Virtual Switch
Thao tác:
1. Click "Networking" tab (bên trái màn hình)
2. Click "Virtual switches" tab (ở giữa)
3. Click "Add standard virtual switch" (nút xanh)
Giải thích Virtual Switch:

Virtual Switch (vSwitch) giống như switch vật lý, nhưng hoạt động bằng software
Standard vSwitch là loại switch cơ bản, chỉ hoạt động trên 1 ESXi host
Distributed vSwitch cần vCenter, hoạt động trên nhiều ESXi hosts

Tại sao cần tạo vSwitch mới?

vSwitch hiện tại (vSwitch0) kết nối với card mạng vật lý → ra internet
vSwitch mới (vSwitch-DB) sẽ không kết nối với card mạng vật lý → network cô lập
Database VMs chỉ có thể giao tiếp qua pfSense, không thể ra internet trực tiếp


Bước 3: Cấu hình Virtual Switch
Cửa sổ popup "Add standard virtual switch":
Name (Tên):
vSwitch Name: vSwitch-DB
Giải thích: Tên để nhận diện switch, nên đặt có ý nghĩa (DB = Database)
MTU (Maximum Transmission Unit):
MTU: 1500 (default)
Giải thích:

MTU là kích thước packet lớn nhất có thể truyền
1500 bytes là standard cho Ethernet
Không nên thay đổi trừ khi có yêu cầu đặc biệt

Number of ports:
Number of ports: 128 (default)
Giải thích:

Số port ảo tối đa mà switch có thể hỗ trợ
128 ports đủ cho hầu hết use cases nhỏ
Mỗi VM sẽ dùng 1 port

Security Settings:
├── Promiscuous mode: Reject ✅
├── MAC address changes: Accept ✅
└── Forged transmits: Accept ✅
Giải thích từng option:

Promiscuous mode: Reject - VM không thể "nghe lén" traffic của VMs khác (bảo mật)
MAC address changes: Accept - VM có thể thay đổi MAC address (cần cho một số ứng dụng)
Forged transmits: Accept - VM có thể gửi packets với MAC address khác (cần cho virtualization)

⚠️ QUAN TRỌNG NHẤT:
"Add a physical network adapter" → KHÔNG TICK ✅
Giải thích:

Physical network adapter là card mạng vật lý (vmnic0)
KHÔNG tick = vSwitch này hoàn toàn isolated, không kết nối ra ngoài
Đây là điểm then chốt tạo network cô lập cho database


Bước 4: Tạo Port Group
Thao tác:
1. Vẫn trong "Virtual switches" tab
2. Click vào vSwitch-DB vừa tạo (sẽ hiển thị details)
3. Click "Add port group" (nút xanh)
Giải thích Port Group:

Port Group là nhóm các ports có cùng cấu hình
Giống như VLAN trong switch vật lý
VMs sẽ kết nối vào Port Group, không phải trực tiếp vào vSwitch

Cấu hình Port Group:
├── Name: DB-Network
├── VLAN ID: 0 (None)
├── vSwitch: vSwitch-DB (auto-selected)
└── Security: Inherit from vSwitch
Giải thích từng field:

Name: DB-Network - Tên port group, VMs sẽ thấy tên này khi chọn network
VLAN ID: 0 - Không dùng VLAN tagging (None/untagged)
vSwitch: vSwitch-DB - Port group thuộc vSwitch nào
Security: Inherit - Dùng security settings từ vSwitch


2.2 Kiểm tra kết quả tạo network
Kiểm tra trong vSphere Client:
Networking → Virtual switches sẽ hiển thị:
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
Giải thích sự khác biệt:
vSwitch0 (Network hiện tại):

Physical adapter: vmnic0 → Có thể ra internet
Uplinks: 1 active → Kết nối vật lý hoạt động
VM Network → VMs hiện tại dùng network này

vSwitch-DB (Network mới):

Physical adapter: None → KHÔNG thể ra internet trực tiếp
Uplinks: 0 active → Không có kết nối vật lý
DB-Network → Database VMs sẽ dùng network này

Xác nhận network isolation:
Test từ ESXi Host:
bash# SSH vào ESXi Host
esxcli network vswitch standard list
Kết quả mong muốn:
vSwitch0:
   Name: vSwitch0
   Physical adapters: vmnic0
   
vSwitch-DB:
   Name: vSwitch-DB
   Physical adapters: (empty) ← Isolated network

2.3 Hiểu rõ Network Topology sau khi tạo
Trước khi tạo vSwitch-DB:
Internet
    │
Router nhà (192.168.1.1)
    │
ESXi Host (192.168.1.100)
    │
vSwitch0 (vmnic0)
    │
VM Network (192.168.1.0/24)
    │
All VMs → Có thể ra internet
Sau khi tạo vSwitch-DB:
Internet
    │
Router nhà (192.168.1.1)
    │
ESXi Host (192.168.1.100)
    │
├── vSwitch0 (vmnic0) → VM Network (192.168.1.0/24)
│   │
│   └── App VMs, pfSense WAN → Có thể ra internet
│
└── vSwitch-DB (isolated) → DB-Network (172.16.1.0/24)
    │
    └── Database VMs → KHÔNG thể ra internet
Lợi ích của kiến trúc này:
Bảo mật:

Database VMs hoàn toàn isolated
Không thể browse web, download malware
Không thể bị tấn công trực tiếp từ internet

Kiểm soát:

Tất cả traffic ra/vào database phải qua pfSense
Có thể log, monitor, block theo ý muốn
Firewall rules chi tiết

Hiệu suất:

Traffic nội bộ giữa databases rất nhanh
Không cạnh tranh bandwidth với internet traffic


2.4 Troubleshooting & Common Issues
Nếu không thấy "Add standard virtual switch":
Nguyên nhân:

Không có quyền Admin
Đang ở sai view (VM view thay vì Host view)
Browser cache cũ

Giải pháp:
1. Kiểm tra đang login với tài khoản root
2. Click vào Host name (bên trái) thay vì VM
3. Refresh browser (Ctrl+F5)
4. Thử incognito/private mode
Nếu Port Group không xuất hiện:
Nguyên nhân:

vSwitch-DB chưa tạo thành công
Tên bị trùng lặp
Cache browser

Giải pháp:
1. Kiểm tra vSwitch-DB có trong danh sách không
2. Click vào vSwitch-DB để xem details
3. Refresh "Virtual switches" tab
4. Thử tên khác nếu bị trùng
Nếu không thể tạo vSwitch:
Nguyên nhân:

ESXi Host đang overloaded
Không đủ resources
Networking service lỗi

Giải pháp:
1. Kiểm tra ESXi Host health
2. Restart ESXi management agents:
   /etc/init.d/hostd restart
   /etc/init.d/vpxa restart
3. Reboot ESXi Host nếu cần

2.5 Verification Steps (Bước xác nhận)
Sau khi hoàn thành Phase 1:
Checklist:
✅ vSwitch-DB đã tạo thành công
✅ vSwitch-DB KHÔNG có physical adapter
✅ DB-Network port group đã tạo
✅ Port group thuộc vSwitch-DB
✅ Security settings đúng (Promiscuous: Reject)
✅ Status: Connected (cả vSwitch và port group)
Visual confirmation:
Networking → Virtual switches:
- Thấy 2 vSwitches: vSwitch0 và vSwitch-DB
- vSwitch0 có "Physical adapters: vmnic0"
- vSwitch-DB có "Physical adapters: -" (empty)
- DB-Network port group visible
Chuẩn bị cho Phase 2:
Những gì đã có:

✅ Network infrastructure sẵn sàng
✅ Isolated network cho database
✅ Port group cho database VMs

Những gì cần làm tiếp:

🔄 Tạo pfSense VM với 2 network interfaces
🔄 Kết nối pfSense làm gateway giữa 2 networks
🔄 Cấu hình routing và firewall

Kết quả Phase 1:
🎯 Network foundation hoàn thành - Đã có isolated network cho database, sẵn sàng triển khai pfSense router trong Phase 2!


Tóm tắt Phase 3: Tạo pfSense VM & Network Configuration
📋 Roadmap Phase 3 đã hoàn thành:
3.1 Download & Upload pfSense ISO
✅ Tải pfSense CE ISO từ pfsense.org
✅ Upload lên ESXi datastore via vSphere Client
✅ Path: /vmfs/volumes/datastore1/ISO-Images/pfSense-CE-x.x.x.iso
3.2 Tạo pfSense VM
✅ VM Name: pfSense-Router
✅ OS: FreeBSD 12 (64-bit)
✅ Resources: 1 vCPU, 2GB RAM, 20GB disk
✅ Network Adapter 1: VM Network (WAN - 192.168.1.0/24)
✅ Network Adapter 2: DB-Network (LAN - 172.16.1.0/24)
✅ CD/DVD: pfSense ISO
3.3 Cài đặt pfSense
✅ Boot từ ISO → Install pfSense
✅ Auto partitioning (UFS)
✅ Installation hoàn tất
✅ Remove ISO sau khi reboot
3.4 Interface Assignment
✅ WAN Interface: vmx0 (VM Network)
✅ LAN Interface: vmx1 (DB-Network)
✅ No VLAN configuration
3.5 IP Configuration
✅ WAN IP: 192.168.1.190/24 (static)
✅ WAN Gateway: 192.168.1.1 (router nhà)
✅ LAN IP: 172.16.1.1/24 (static)
✅ DHCP Pool: 172.16.1.10-50
✅ Web Protocol: HTTP enabled

🔥 Command quan trọng nhất: pfctl -d
Lệnh này làm gì:
bashEnter an option: 8  (Shell)
pfctl -d                 # Disable pfSense firewall
exit
Tại sao hiệu quả:
1. Firewall Blocking Issue:
❌ Problem: pfSense default firewall rules block WAN web access
❌ Symptom: Không thể truy cập http://192.168.1.190
❌ Root cause: Anti-lockout rule chưa configured properly
2. pfctl -d Solution:
✅ pfctl = Packet Filter Control (FreeBSD firewall)
✅ -d flag = Disable firewall rules temporarily
✅ Effect: Allow ALL traffic through (no filtering)
✅ Result: Web interface immediately accessible
Technical Details:
pfSense Firewall Architecture:
Internet → pfSense WAN → Firewall Rules → Services
Default Behavior:
- pfSense blocks WAN access to web interface by default
- Only LAN access allowed initially
- Anti-lockout protection prevents admin lockout
- Need proper rules hoặc disable firewall
pfctl -d Impact:
Before: WAN → [FIREWALL BLOCKS] → Web Interface ❌
After:  WAN → [NO FIREWALL] → Web Interface ✅

🛡️ Firewall States:
Enabled (Default):
bashpfctl -e    # Enable firewall
- Security rules active
- WAN access blocked
- LAN access allowed
- Proper production mode
Disabled (Troubleshooting):
bashpfctl -d    # Disable firewall  
- NO security rules
- ALL access allowed
- Easy troubleshooting
- NOT for production
Check Status:
bashpfctl -s info    # Show firewall status
pfctl -s rules   # Show active rules

🎯 Network Topology Final:
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
│     └── Your computer: 192.168.1.x
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ pfSense VM (Router/Firewall)    │
│ ├── WAN: vmx0 (192.168.1.190)   │
│ └── LAN: vmx1 (172.16.1.1)      │
│ Firewall: DISABLED (pfctl -d)   │
└─────────────────────────────────┘
    │
┌─────────────────────────────────┐
│ vSwitch-DB (Isolated)           │
│ └── DB-Network (172.16.1.0/24)  │
│     ├── Gateway: 172.16.1.1     │
│     ├── DHCP: 172.16.1.10-50    │
│     └── Database VMs: (future)  │
└─────────────────────────────────┘

✅ Access Methods:
Working Access:
✅ WAN Web Interface: http://192.168.1.190
   Login: admin/pfsense
   từ máy trong mạng 192.168.1.0/24

❌ LAN Web Interface: http://172.16.1.1
   Chỉ accessible từ VMs trong DB-Network
   Expected behavior (network isolation)
SSH Access (Available):
✅ SSH to pfSense: ssh admin@192.168.1.190
   Console access for advanced config
   Alternative to web interface

🔧 Troubleshooting Commands Used:
Network Testing:
bash# Từ pfSense console
Option 7: ping 192.168.1.1    # Router test ✅
Option 7: ping 8.8.8.8        # Internet test ✅  
Option 7: ping 172.16.1.1     # Self test ✅
Service Management:
bashOption 11: Restart GUI        # Web service restart
Option 14: Enable SSH         # Remote access
Option 8: Shell → pfctl -d    # Disable firewall ⭐

🎉 Phase 3 Achievements:
Infrastructure:
✅ pfSense VM operational
✅ Dual network interfaces configured  
✅ WAN connectivity to internet
✅ LAN subnet for database isolation
✅ DHCP server for automatic IP assignment
Security:
✅ Network segmentation (192.168.1.x ≠ 172.16.1.x)
✅ Firewall router between subnets
✅ Controlled access points
✅ Foundation for advanced security rules
Management:
✅ Web interface accessible
✅ SSH access available
✅ Console management functional
✅ Ready for production configuration

🚀 Ready for Phase 4:
Network foundation hoàn thiện, sẵn sàng cho:

Advanced firewall rules configuration
Database VM deployment
Security policy implementation
Production workload testing

pfctl -d command = Magic key để unlock web interface access! 🔑