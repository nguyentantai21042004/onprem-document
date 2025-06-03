# Kiến thức Networking ESXi

## Giới thiệu

Tài liệu này sẽ cung cấp kiến thức chi tiết về lý thuyết networking trong môi trường VMware ESXi. Nội dung bao gồm các khái niệm cơ bản về virtual networking, cách thức hoạt động của virtual switches, port groups, VLAN configuration, cũng như các best practices để thiết kế và triển khai hạ tầng mạng ảo hóa hiệu quả và bảo mật.

Thông qua việc tìm hiểu sâu về networking architecture của ESXi, nắm được cách thức kết nối các virtual machines với nhau và với mạng vật lý, hiểu được các loại virtual switches khác nhau (Standard Switch và Distributed Switch), và biết cách cấu hình networking để đáp ứng các yêu cầu cụ thể của từng môi trường triển khai.

## 1. PHYSICAL NIC (vmnic) - ĐIỂM XUẤT PHÁT

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

### 📊 THÔNG TIN PHYSICAL NIC (vmnic)

| Tên NIC | Driver | Địa chỉ MAC | Auto-Negotiate | Tốc độ Link |
|---------|--------|-------------|----------------|-------------|
| vmnic0  | r8168  | 00:e0:25:30:50:7b | Enabled | 1000 Mbps, full duplex |


### 🎯 Thông số quan trọng:

• **Driver (r8168):** Phần mềm điều khiển hardware

• **MAC Address:** Địa chỉ vật lý duy nhất (00:e0:25:30:50:7b)

• **Speed:** Tốc độ truyền tải (1000 Mbps = 1 Gbps)

• **Auto-Negotiate:**
- Là cơ chế tự động đàm phán giữa card mạng và thiết bị đầu cuối
- Hai bên sẽ tự thỏa thuận về:
  + Tốc độ truyền tải (Speed)
  + Chế độ duplex (Half/Full)
- Giúp tối ưu hiệu suất kết nối
- Tránh xung đột cấu hình thủ công

• **Link Speed & Duplex:**
- Link Speed: Tốc độ truyền tải dữ liệu trên đường mạng
  + Thường gặp: 10/100/1000 Mbps
  + Card mạng hiện đại hỗ trợ 1Gbps trở lên
- Full duplex:
  + Cho phép truyền và nhận dữ liệu đồng thời
  + Hiệu suất cao hơn half duplex
  + Là chế độ phổ biến trong môi trường doanh nghiệp

## 2. VIRTUAL SWITCH (vSwitch) - CÔNG TẮC ÁO

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

### 🎯 Chức năng của vSwitch:

1. **Kết nối các VM với nhau** (internal communication)
2. **Kết nối VM ra ngoài** (thông qua uplink)
3. **Quản lý traffic** (filtering, VLAN tagging)

---

### 🏗️ vSWITCH - BỘ ĐIỀU PHỐI TRUNG TÂM

### 🔄 vSwitch hoạt động chi tiết:

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

### 🧠 vSwitch Processing Logic:

#### **Bước 1: Nhận Frame**
```python
# Giả sử VM1 gửi data đến VM2
Frame từ VM1 = {
    'src_mac': '00:50:56:xx:xx:01',  # MAC của VM1
    'dst_mac': '00:50:56:xx:xx:02',  # MAC của VM2
    'data': 'Hello VM2!'
}
```

#### **Bước 2: MAC Address Learning**
```python
# vSwitch học MAC address
MAC_Table = {
    'Port 1': '00:50:56:xx:xx:01',  # VM1 ở Port 1
    'Port 2': '00:50:56:xx:xx:02',  # VM2 ở Port 2
}
```

#### **Bước 3: Forwarding Decision**
```python
if dst_mac in MAC_Table:
    # Biết chính xác port đích
    forward_to_port(MAC_Table[dst_mac])
else:
    # Không biết, flood tất cả ports
    flood_to_all_ports()
```

### 🔗 **SỰ LIÊN KẾT GIỮA vSwitch và Physical NIC (vmnic)**

#### **1. Uplink Connection:**
- **vSwitch** kết nối với **vmnic0** thông qua **Uplink Port**
- Mọi traffic từ VM muốn ra ngoài Internet đều phải đi qua uplink này
- **vmnic0** là cầu nối duy nhất giữa thế giới ảo (vSwitch) và thế giới thật (mạng vật lý)

#### **2. Data Flow Integration:**
```
VM1 ──► vSwitch Port 1 ──► Switching Logic ──► Uplink Port ──► vmnic0 ──► Internet
```

#### **3. Traffic Direction:**
- **Inbound:** `Internet → vmnic0 → vSwitch → VM`
- **Outbound:** `VM → vSwitch → vmnic0 → Internet`
- **Internal:** `VM1 → vSwitch → VM2` (không cần vmnic0)

#### **4. Performance Dependency:**
- Hiệu suất của **toàn bộ vSwitch** phụ thuộc vào **vmnic0**
- Nếu vmnic0 = 1Gbps → tổng bandwidth ra ngoài = 1Gbps
- Nhiều VM chia sẻ bandwidth của vmnic0

#### **5. Fault Tolerance:**
- Nếu **vmnic0** bị lỗi → tất cả VM mất kết nối Internet
- Chỉ traffic nội bộ giữa các VM vẫn hoạt động
- Cần multiple vmnic để tạo redundancy

### 📊 **So sánh vSwitch vs Physical Switch:**

| Đặc điểm | Physical Switch | vSwitch |
|----------|----------------|---------|
| **Vị trí** | Hardware độc lập | Software trong ESXi |
| **Ports** | Cổng vật lý | Virtual ports |
| **MAC Table** | Hardware ASIC | Software memory |
| **Performance** | Wire speed | CPU dependent |
| **Uplink** | Nhiều cổng | 1 hoặc nhiều vmnic |
| **Management** | Web/CLI riêng | vSphere Client |

## 3. PORT GROUP - POLICY CONTAINER

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

### 🏢 **Ví dụ trong công ty:**

**Công ty có 3 phòng ban:**
```
🏢 XYZ Company
├── 👔 Phòng Quản lý (Management) - Mạng riêng biệt
├── 🏭 Phòng Sản xuất (Production) - Mạng bảo mật cao  
└── 🧪 Phòng Thí nghiệm (Test) - Mạng thử nghiệm
```

**Mỗi phòng = 1 Port Group với rule riêng:**

#### **Port Group "Production":**
```
├── VLAN ID: 19
├── Security: Strict
├── Bandwidth: High priority
└── VMs: Only production servers
```

#### **Port Group "Test":**
```
├── VLAN ID: 21
├── Security: Relaxed
├── Bandwidth: Normal
└── VMs: Development servers
```

### 📋 **Tại sao cần Port Group?**

#### **❌ Không có Port Group (Bad):**
```
vSwitch ─── VM1 ────┐
        ─── VM2 ────┼─── Tất cả VM cùng rule
        ─── VM3 ────┘     → Không kiểm soát được
```

**Vấn đề:**
- Tất cả VM cùng policy
- CEO VM và Test VM cùng security level ❌
- Dev VM và Analytics VM cùng bandwidth ❌
- Không thể kiểm soát riêng lẻ ❌

#### **✅ Có Port Group (Good):**
```
vSwitch ┬── Port Group A ─── VM1 (Production)
        │                   VM2 (Production)
        │
        └── Port Group B ─── VM3 (Test)
                             VM4 (Test)
```

### 🎯 **Tình huống thực tế - Tại sao cần Port Group:**

#### **Case 1: Công ty có nhiều phòng ban**

```
🏢 XYZ Company
├── 👔 Management (CEO, CFO) - Cần bảo mật cao
├── 💻 Development - Cần bandwidth cao cho git clone
├── 🧪 Testing - Có thể relaxed security cho debug
└── 📊 Analytics - Cần priority traffic cho big data
```

#### **❌ Không có Port Group (Bad):**
```
vSwitch0
├── All VMs cùng policy
├── CEO VM và Test VM cùng security level ❌
├── Dev VM và Analytics VM cùng bandwidth ❌
└── Không thể kiểm soát riêng lẻ ❌
```

#### **✅ Có Port Group (Good):**
```
vSwitch0
├── Management-PG (High Security, VLAN 10)
│   ├── CEO-VM (Promiscuous: Reject)
│   └── CFO-VM (MAC Change: Reject)
│
├── Development-PG (Medium Security, VLAN 20)
│   ├── Dev-VM1 (Bandwidth: 500 Mbps)
│   └── Dev-VM2 (Bandwidth: 500 Mbps)
│
├── Testing-PG (Low Security, VLAN 30)
│   ├── Test-VM1 (Promiscuous: Accept)
│   └── Test-VM2 (Debug mode enabled)
│
└── Analytics-PG (High Priority, VLAN 40)
    ├── BigData-VM1 (Priority: High)
    └── BigData-VM2 (Burst: Unlimited)
```

### 🔗 **SỰ LIÊN KẾT với vSwitch và vmnic:**

#### **1. Hierarchy Connection:**
```
vmnic0 ──► vSwitch ──► Port Groups ──► Individual VMs
 (HW)      (Switch)    (Policies)     (Endpoints)
```

#### **2. Policy Inheritance:**
- **vmnic0** cung cấp physical connectivity
- **vSwitch** cung cấp switching functionality  
- **Port Group** cung cấp policy enforcement
- **VM** nhận policy từ Port Group mà nó kết nối

#### **3. Traffic Flow with Port Group:**
```
VM1 ──► Port Group A ──► vSwitch Logic ──► Port Group B ──► VM2
  (apply policies)      (switching)       (apply policies)
```

### 📊 **So sánh có/không có Port Group:**

| Tính năng | Không có Port Group | Có Port Group |
|-----------|-------------------|---------------|
| **Security Control** | Áp dụng cho tất cả VM | Riêng lẻ từng nhóm |
| **VLAN Isolation** | Không có | Có, theo từng group |
| **Bandwidth Control** | Chung cho tất cả | Riêng lẻ từng nhóm |
| **Management** | Khó quản lý | Dễ quản lý theo nhóm |
| **Scalability** | Kém | Tốt |
| **Compliance** | Khó đạt chuẩn | Dễ đạt chuẩn |

## 4. VMKERNEL NIC - GIAO DIỆN CỦA ESXi

### 🖥️ VMkernel hoạt động chi tiết:

**VMkernel NIC ≠ VM NIC**

```
┌─────────────────────────────────────────────────────────────────┐
│                       ESXi Architecture                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     User World                          │   │
│  │                                                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │   │
│  │  │   VM1   │  │   VM2   │  │   VM3   │                 │   │
│  │  │ (Guest  │  │ (Guest  │  │ (Guest  │                 │   │
│  │  │   OS)   │  │   OS)   │  │   OS)   │                 │   │
│  │  └─────────┘  └─────────┘  └─────────┘                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 VMkernel (ESXi OS)                      │   │
│  │                                                         │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐           │   │
│  │  │   vmk0    │  │   vmk1    │  │   vmk2    │           │   │
│  │  │(Management│  │(vMotion)  │  │(Storage)  │           │   │
│  │  │192.168.1.50│  │192.168.19.1│ │192.168.21.1│          │   │
│  │  └───────────┘  └───────────┘  └───────────┘           │   │
│  │                                                         │   │
│  │                    TCP/IP Stack                         │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │  Routing Table │ ARP Table │ Network Services  │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 🌊 **VMkernel Traffic Flow:**

#### **Khi bạn SSH vào ESXi:**
```
Your PC ──► SSH (port 22) ──► vmk0 (192.168.1.50) ──► ESXi SSH Service
```

#### **Khi ESXi cần tải ISO:**
```
ESXi ──► vmk0 ──► Internet ──► Download ISO ──► Datastore
```

#### **Khi VM migrate (vMotion):**
```
ESXi Host A ──► vmk1 ──► Network ──► vmk1 ──► ESXi Host B
                    (VM Memory & State transfer)
```

### 🔗 **SỰ LIÊN KẾT với các thành phần trước:**

#### **1. Complete Network Stack:**
```
vmnic0 ──► vSwitch ──► Port Group ──► VMkernel Interfaces
 (HW)      (Layer 2)   (Policies)     (Layer 3 Services)
```

#### **2. VMkernel vs VM Traffic:**

**VM Traffic (User World):**
```
VM ──► Port Group ──► vSwitch ──► vmnic0 ──► Internet
       (VM policies)  (switching)
```

**VMkernel Traffic (ESXi OS):**
```
ESXi Service ──► VMkernel Interface ──► vSwitch ──► vmnic0 ──► Internet
                 (vmk0, vmk1, vmk2)    (no policy)
```

### 🎯 **Chi tiết từng VMkernel Interface:**

#### **vmk0 - Management Network:**
```
🔧 Chức năng:
├── ESXi Web UI (HTTPS - port 443)
├── SSH Access (port 22)  
├── vCenter Connection
├── ESXi API calls
└── Host monitoring

📡 Cấu hình:
├── IP: 192.168.1.50/24
├── Gateway: 192.168.1.1
├── VLAN: Management VLAN
└── Port Group: Management-PG
```

#### **vmk1 - vMotion Network:**
```
🔄 Chức năng:
├── VM Live Migration
├── Memory transfer giữa hosts
├── VM state synchronization
└── Zero downtime VM movement

📡 Cấu hình:
├── IP: 192.168.19.1/24
├── Dedicated network (tách biệt)
├── High bandwidth required
└── Port Group: vMotion-PG
```

#### **vmk2 - Storage Network:**
```
💾 Chức năng:
├── iSCSI connections
├── NFS datastore access
├── vSAN communication
└── Storage I/O

📡 Cấu hình:
├── IP: 192.168.21.1/24
├── Storage network isolation
├── Jumbo frames support
└── Port Group: Storage-PG
```

### 🚦 **Traffic Flow Examples:**

#### **Scenario 1: Admin SSH vào ESXi**
```
Admin PC (192.168.1.100) 
    ↓
SSH Client (port 22)
    ↓
Network Switch vật lý
    ↓  
vmnic0 (ESXi Physical NIC)
    ↓
vSwitch0
    ↓
Management Port Group
    ↓
vmk0 (192.168.1.50)
    ↓
ESXi SSH Daemon
```

#### **Scenario 2: VM Migration (vMotion)**
```
ESXi Host A                    ESXi Host B
VM running ────────────────── Destination prepared
    ↓                              ↑
vmk1 (vMotion)                vmk1 (vMotion)
    ↓                              ↑
vSwitch ───────────────────────── vSwitch
    ↓                              ↑
vmnic ─────► Network ─────────────► vmnic
         (VM Memory & State Transfer)
```

#### **Scenario 3: ESXi Download ISO**
```
ESXi Storage Service
    ↓
vmk0 (Management Interface)
    ↓
Management Port Group
    ↓
vSwitch0
    ↓
vmnic0
    ↓
Internet ──► Download ISO file ──► Local Datastore
```

### 📊 **So sánh VM NIC vs VMkernel NIC:**

| Đặc điểm | VM NIC | VMkernel NIC |
|----------|--------|--------------|
| **Mục đích** | Guest OS networking | ESXi host services |
| **Tầng OSI** | Guest OS manages | ESXi kernel manages |
| **IP Address** | Guest OS assigned | ESXi assigned |
| **Services** | Application traffic | Management, vMotion, Storage |
| **Port Group** | VM Port Groups | VMkernel Port Groups |
| **Driver** | Guest OS drivers | ESXi built-in |
| **Performance** | Shared resources | Dedicated kernel path |

### ⚡ **Performance Considerations:**

#### **1. Network Separation:**
- **Best Practice:** Tách các VMkernel interfaces ra các mạng vật lý khác nhau
- **Management:** Mạng quản trị
- **vMotion:** Mạng chuyển giao VM (cần bandwidth cao)
- **Storage:** Mạng lưu trữ (cần latency thấp)

#### **2. Bandwidth Planning:**
```
🏢 Enterprise Setup:
├── Management: 1Gbps (đủ cho quản trị)
├── vMotion: 10Gbps (migration nhanh)
├── Storage: 10Gbps+ (I/O performance)
└── VM Production: 10Gbps+ (user traffic)
```

#### **3. Fault Tolerance:**
- **Multiple vmnic:** Redundancy cho từng service
- **Link Aggregation:** Tăng bandwidth và availability
- **Network Isolation:** Tránh single point of failure

## 5. VLAN - TÁCH BIỆT LOGIC

### 🏠 VLAN Deep Dive:

**VLAN = Virtual LAN = Mạng ảo logic trên cùng một infrastructure vật lý**

### 🔄 **VLAN Tagging Process:**

```
┌─────────────────────────────────────────────────────────────────┐
│                         VLAN Tagging                            │
│                                                                 │
│  VM gửi frame:                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Ethernet Header │         Data Payload                  │   │
│  │ Dst│Src│Type│   │     "Hello Production Server"        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│                                                                 │
│  vSwitch thêm VLAN tag:                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Ethernet │ VLAN │         Data Payload                  │   │
│  │ Header   │  19  │     "Hello Production Server"        │   │
│  │ Dst│Src  │ Tag  │                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Physical switch nhận được:                                     │
│  if (VLAN_ID == 19):                                            │
│      forward_to_production_ports()                              │
│  elif (VLAN_ID == 21):                                          │
│      forward_to_test_ports()                                    │
│  else:                                                          │
│      drop_frame()                                               │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 **Tình huống thực tế:**

#### **Case: Công ty có 2 tầng**

```
🏢 Building Layout:
┌─────────────────────────────────────────────────────┐
│                    Floor 2                          │
│                                                     │
│  ┌─────────────────┐      ┌─────────────────┐      │
│  │   Production    │      │    Finance      │      │
│  │    Servers      │      │    VLAN 10      │      │
│  │    VLAN 19      │      │    VLAN 10      │      │
│  └─────────────────┘      └─────────────────┘      │
└─────────────────────────────────────────────────────┘
                           │
                    Same Cable
                           │
┌─────────────────────────────────────────────────────┐
│                    Floor 1                          │
│                                                     │
│  ┌─────────────────┐      ┌─────────────────┐      │
│  │     Test        │      │       HR        │      │
│  │   Servers       │      │  Department     │      │
│  │   VLAN 21       │      │    VLAN 30      │      │
│  └─────────────────┘      └─────────────────┘      │
└─────────────────────────────────────────────────────┘
```

### 💡 **Một dây mạng, 4 mạng logic:**

```python
# Switch vật lý config:
VLAN_Table = {
    19: ['Port 1', 'Port 5'],     # Production servers
    21: ['Port 2', 'Port 6'],     # Test servers  
    10: ['Port 3', 'Port 7'],     # Finance PCs
    30: ['Port 4', 'Port 8']      # HR PCs
}

# Khi nhận frame với VLAN 19:
def process_frame(frame):
    vlan_id = frame.vlan_tag
    target_ports = VLAN_Table[vlan_id]
    for port in target_ports:
        forward_frame(port, frame)
```

### 🔗 **SỰ LIÊN KẾT với tất cả thành phần ESXi:**

#### **1. Complete VLAN Flow:**
```
VM (Production) 
    ↓
Port Group (VLAN 19) ←─── Assign VLAN Tag
    ↓
vSwitch ←─── Add VLAN header to frame
    ↓
vmnic0 ←─── Physical transmission
    ↓
Physical Switch ←─── Process VLAN tags
    ↓
Target Network (Production only)
```

#### **2. VLAN trong từng thành phần:**

**Physical NIC (vmnic):**
- Truyền frames có VLAN tags
- Không xử lý logic VLAN (transparent)
- Chỉ làm nhiệm vụ physical transmission

**vSwitch:**
- Thêm/bỏ VLAN tags dựa trên Port Group
- VLAN-aware switching
- Forward frames theo VLAN membership

**Port Group:**
- **Cấu hình VLAN ID** cho từng group
- **Access mode:** VM không biết về VLAN
- **Trunk mode:** Multiple VLANs trên một Port Group

**VMkernel:**
- Mỗi vmk có thể ở VLAN riêng
- Management vmk0 thường ở Management VLAN
- vMotion vmk1 thường ở dedicated VLAN

### 🚀 **VLAN Configuration Examples:**

#### **Scenario 1: Production vs Test Isolation**
```
ESXi Host Configuration:
├── vSwitch0
│   ├── Production-PG (VLAN 19)
│   │   ├── Prod-VM1 (Database)
│   │   └── Prod-VM2 (Web Server)
│   │
│   ├── Test-PG (VLAN 21) 
│   │   ├── Test-VM1 (Dev Database)
│   │   └── Test-VM2 (Dev Web Server)
│   │
│   └── Management-PG (VLAN 10)
│       └── vmk0 (192.168.1.50)
│
└── vmnic0 ─── Trunk to Physical Switch
```

#### **Scenario 2: Multi-tenant Environment**
```
ESXi Hosting Provider:
├── Customer-A-PG (VLAN 100)
│   ├── CustomerA-VM1
│   └── CustomerA-VM2
│
├── Customer-B-PG (VLAN 200)  
│   ├── CustomerB-VM1
│   └── CustomerB-VM2
│
└── Provider-Mgmt-PG (VLAN 999)
    └── vmk0 (Management)
```

### 📊 **VLAN Benefits trong ESXi:**

| Lợi ích | Không có VLAN | Có VLAN |
|---------|---------------|---------|
| **Security** | Tất cả VM same broadcast domain | Isolation theo department |
| **Performance** | Broadcast storms affect all | Contained within VLAN |
| **Management** | Flat network structure | Hierarchical organization |
| **Compliance** | Khó meet regulation | Easy compliance segmentation |
| **Scalability** | Limited by physical ports | Logical separation unlimited |
| **Cost** | More physical infrastructure | Optimize physical resources |

### 🛠️ **VLAN Troubleshooting:**

#### **Common Issues:**

**1. VLAN Mismatch:**
```
Problem: VM không communicate được
Root Cause: Port Group VLAN ≠ Physical Switch VLAN
Solution: Verify VLAN IDs match end-to-end
```

**2. Trunk Configuration:**
```
Problem: Multiple VLANs not working
Root Cause: Physical switch port not trunked
Solution: Configure switch port as trunk
```

**3. Native VLAN Issues:**
```
Problem: Untagged traffic confusion
Root Cause: Native VLAN mismatch
Solution: Configure consistent native VLAN
```

### ⚡ **VLAN Performance Considerations:**

#### **1. VLAN Design Best Practices:**
- **Management VLAN:** Tách biệt hoàn toàn
- **Production VLANs:** Theo application tiers
- **Storage VLAN:** Dedicated cho storage traffic
- **vMotion VLAN:** Isolated migration network

#### **2. Physical Switch Requirements:**
- **802.1Q Support:** For VLAN tagging
- **Jumbo Frames:** For storage VLANs
- **QoS Support:** Traffic prioritization
- **VLAN Routing:** Inter-VLAN communication

#### **3. ESXi VLAN Limits:**
- **Standard Switch:** 4096 VLANs supported
- **Distributed Switch:** Enterprise scale
- **Port Groups:** No limit on VLAN assignment
- **Performance:** No overhead for VLAN processing

## 6. HƯỚNG DẪN SETUP VLAN TRÊN ESXi - THỰC HÀNH

### 🔧 **Hướng dẫn chi tiết từng bước + Cách kiểm tra**

---

### **PHASE 1: TẠO PORT GROUPS**

#### **Bước 1.1: Truy cập vSphere Client**
```
https://192.168.1.50 (IP ESXi của bạn)
Login → Host → Networking
```

#### **Bước 1.2: Tạo Production Port Group**

**Thực hiện:**
1. Click "**Virtual switches**" → **vSwitch0**
2. Click "**Add port group**"
3. Điền thông tin:
   - **Name:** `Production-Network`
   - **VLAN ID:** `19`
   - **Security:** Accept (mặc định)
4. Click "**Add**"

#### **Bước 1.3: Tạo Test Port Group**

**Thực hiện:**
1. Tiếp tục click "**Add port group**"
2. Điền thông tin:
   - **Name:** `Test-Network`
   - **VLAN ID:** `21`
   - **Virtual switch:** `vSwitch0`
3. Click "**Add**"

**✅ Kiểm tra thành công:**
```bash
# SSH vào ESXi, chạy:
esxcli network vswitch standard portgroup list

# Kết quả mong đợi:
Name                Virtual Switch  Active Clients  VLAN ID
------------------  --------------  --------------  -------
Management Network  vSwitch0                     1        0
Production Network  vSwitch0                     0       19
Test Network        vSwitch0                     0       21
VM Network          vSwitch0                     2        0
```

---

### **PHASE 2: TẠO VMKERNEL INTERFACES**

#### **Bước 2.1: Tạo Production VMkernel**

**Thực hiện:**
1. **Networking** → **VMkernel NICs** → **Add VMkernel NIC**
2. **Select target device:** chọn "**Production-Network**"
3. **IPv4 settings:**
   - ☑️ **Use static IPv4 settings**
   - **IPv4 address:** `192.168.19.1`
   - **Subnet mask:** `255.255.255.0`
   - **Default gateway:** để trống
4. **Services:** Không check gì cả
5. Click "**Create**"

#### **Bước 2.2: Tạo Test VMkernel**

**Thực hiện:**
1. **Add VMkernel NIC** tiếp
2. **Select target device:** "**Test-Network**"
3. **IPv4 settings:**
   - ☑️ **Use static IPv4 settings**
   - **IPv4 address:** `192.168.21.1`
   - **Subnet mask:** `255.255.255.0`
4. Click "**Create**"

**✅ Kiểm tra thành công:**
```bash
# Check VMkernel interfaces
esxcli network ip interface list

# Kết quả thực tế từ system của bạn:
vmk0 - Management Network (192.168.1.50)
vmk1 - Production Network (192.168.19.1)
vmk2 - Test Network (192.168.21.1)
```

```bash
# Check IP addresses
esxcli network ip interface ipv4 get

# Kết quả thực tế:
Name  IPv4 Address  IPv4 Netmask   IPv4 Broadcast  Address Type  Gateway      DHCP DNS
----  ------------  -------------  --------------  ------------  -----------  --------
vmk0  192.168.1.50  255.255.255.0  192.168.1.255   STATIC        192.168.1.1     false
vmk1  192.168.19.1  255.255.255.0  192.168.19.255  STATIC        0.0.0.0         false
vmk2  192.168.21.1  255.255.255.0  192.168.21.255  STATIC        0.0.0.0         false
```

---

### **PHASE 3: TEST CONNECTIVITY**

#### **Bước 3.1: Test VMkernel ping**

```bash
# Test Production VMkernel (THÀNH CÔNG)
vmkping -I vmk1 -c 3 192.168.19.1

# Kết quả thực tế từ system:
PING 192.168.19.1 (192.168.19.1): 56 data bytes
64 bytes from 192.168.19.1: icmp_seq=0 ttl=64 time=0.043 ms
64 bytes from 192.168.19.1: icmp_seq=1 ttl=64 time=0.053 ms
64 bytes from 192.168.19.1: icmp_seq=2 ttl=64 time=0.050 ms
--- 192.168.19.1 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
```

```bash
# Test cross-VLAN ping (FAIL - Đúng như mong đợi)
vmkping -I vmk1 -c 3 192.168.21.1

# Kết quả thực tế:
PING 192.168.21.1 (192.168.21.1): 56 data bytes
sendto() failed (Network is unreachable)
```

**🎯 Giải thích kết quả:**
- **vmk1 ping 192.168.19.1:** ✅ **THÀNH CÔNG** - Ping trong cùng VLAN 19
- **vmk1 ping 192.168.21.1:** ❌ **THẤT BẠI** - Cross-VLAN (VLAN 19 → VLAN 21) bị chặn

**Đây chính là bằng chứng VLAN isolation hoạt động đúng!**

#### **Bước 3.2: Verify VLAN Configuration**

```bash
# Xem chi tiết port group VLAN
esxcli network vswitch standard portgroup list

# Kết quả thực tế từ system:
Name                Virtual Switch  Active Clients  VLAN ID
------------------  --------------  --------------  -------
Management Network  vSwitch0                     1        0
Production Network  vSwitch0                     1       19  ← vmk1 connected
Test Network        vSwitch0                     1       21  ← vmk2 connected
VM Network          vSwitch0                     2        0
```

---

### **PHASE 4: TEST VỚI VM**

#### **Bước 4.1: Tạo VM test Production**

**Thực hiện:**
1. Tạo VM mới
2. **Network:** chọn "**Production-Network**"
3. Boot VM, set IP tĩnh:
   - **IP:** `192.168.19.10`
   - **Subnet:** `255.255.255.0`
   - **Gateway:** `192.168.19.1`

**✅ Kiểm tra trong VM:**
```bash
# Từ trong VM ping ESXi VMkernel
ping 192.168.19.1
# Kết quả mong đợi: successful ping
```

**✅ Kiểm tra từ ESXi:**
```bash
# Từ ESXi ping VM
vmkping -I vmk1 -c 3 192.168.19.10
# Kết quả mong đợi: successful ping
```

#### **Bước 4.2: Test VLAN Isolation**

**Tạo VM test trên Test-Network:**
- **IP:** `192.168.21.10`
- **Gateway:** `192.168.21.1`

**✅ Test isolation:**
```bash
# Từ Production VM (192.168.19.10) ping Test VM (192.168.21.10)
ping 192.168.21.10

# Kết quả mong đợi: FAIL (không ping được)
# Đây là dấu hiệu VLAN isolation hoạt động đúng
```

---

### **PHASE 5: FINAL VERIFICATION**

#### **Tổng quan kiểm tra cuối cùng:**

```bash
# 1. Port groups với VLAN IDs
esxcli network vswitch standard portgroup list

# 2. VMkernel interfaces details
esxcli network ip interface list

# 3. IP addresses assignment
esxcli network ip interface ipv4 get

# 4. Test VLAN connectivity
vmkping -I vmk1 192.168.19.1  # Same VLAN - SUCCESS
vmkping -I vmk2 192.168.21.1  # Same VLAN - SUCCESS  
vmkping -I vmk1 192.168.21.1  # Cross VLAN - FAIL (Good!)

# 5. Physical infrastructure
esxcli network nic list
esxcli network vswitch standard list
```

---

### **🔍 PHÂN TÍCH KẾT QUẢ THỰC TẾ**

#### **✅ Những gì THÀNH CÔNG:**

**1. Port Groups tạo đúng:**
```
Production Network - VLAN 19 - Active Clients: 1
Test Network       - VLAN 21 - Active Clients: 1
```

**2. VMkernel Interfaces hoạt động:**
```
vmk1: 192.168.19.1 (Production VLAN)
vmk2: 192.168.21.1 (Test VLAN)
```

**3. Same-VLAN connectivity:**
```bash
vmkping -I vmk1 192.168.19.1 → SUCCESS (0% packet loss)
```

**4. Cross-VLAN isolation:**
```bash
vmkping -I vmk1 192.168.21.1 → FAIL (Network unreachable)
```

#### **🎯 Ý nghĩa kết quả:**

**"Network is unreachable" = THÀNH CÔNG!**
- Đây **KHÔNG phải lỗi**, mà là **bằng chứng** VLAN isolation hoạt động
- vmk1 (VLAN 19) **không thể** ping vmk2 (VLAN 21) 
- Các VLAN được **tách biệt hoàn toàn** về mặt logic

---

### **❌ TROUBLESHOOTING**

#### **Nếu vmkping cùng VLAN cũng fail:**

```bash
# Check routing table
esxcli network ip route ipv4 list

# Check firewall
esxcli network firewall get

# Check port group assignment
esxcli network vswitch standard portgroup list
```

#### **Nếu VM không ping được VMkernel:**

1. **Kiểm tra VM network adapter:** Đã chọn đúng port group chưa
2. **Kiểm tra IP config trong VM:** Static IP đúng subnet chưa  
3. **Kiểm tra physical switch:** Có hỗ trợ VLAN trunk không

#### **Common Issues:**

**VLAN Mismatch:**
```
Problem: VM không communicate
Root Cause: Port Group VLAN ≠ Physical Switch VLAN
Solution: Verify VLAN IDs end-to-end
```

**Trunk Configuration:**
```
Problem: Multiple VLANs not working  
Root Cause: Physical switch port not trunked
Solution: Configure switch port as trunk
```

---

### **🏆 KẾT LUẬN**

**Setup của bạn HOÀN TOÀN THÀNH CÔNG!**

✅ **VLAN 19 (Production):** vmk1 + Production VMs
✅ **VLAN 21 (Test):** vmk2 + Test VMs  
✅ **VLAN Isolation:** Cross-VLAN traffic blocked
✅ **Same-VLAN Communication:** Working perfectly

**Điều này chứng minh:**
- **vmnic0** → **vSwitch0** → **Port Groups** → **VMkernel/VMs** 
- **VLAN tagging** hoạt động đúng
- **Network isolation** theo thiết kế
- **ESXi networking stack** cấu hình chính xác

**Bạn đã thành công triển khai VLAN trên ESXi!** 🎉
