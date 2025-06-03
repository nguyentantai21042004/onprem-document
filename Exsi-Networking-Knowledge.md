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
│  │                vSwitch Ports                            │   │
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
