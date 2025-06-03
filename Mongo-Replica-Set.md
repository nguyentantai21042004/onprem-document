# Hướng dẫn cài đặt MongoDB Replica Set

## Giới thiệu

File này cung cấp hướng dẫn chi tiết từng bước để cài đặt và cấu hình MongoDB Replica Set. Bạn sẽ học cách thiết lập một cụm MongoDB với khả năng sao chép dữ liệu, đảm bảo tính sẵn sàng cao (High Availability) và khả năng chịu lỗi (Fault Tolerance) cho hệ thống database của mình.

## 1. MongoDB Replica Set là gì?

MongoDB Replica Set là một nhóm các MongoDB instance (mongod processes) duy trì cùng một tập dữ liệu. Replica Set cung cấp tính dự phòng và khả năng sẵn sàng cao, là nền tảng cho tất cả các triển khai production của MongoDB.

### Thành phần chính:

- **Primary Node**: Node chính nhận tất cả các thao tác ghi (write operations)
- **Secondary Nodes**: Các node phụ sao chép dữ liệu từ Primary node
- **Arbiter** (tùy chọn): Node không chứa dữ liệu, chỉ tham gia bình chọn trong quá trình election

### Lợi ích của Replica Set:

1. **High Availability (Tính sẵn sàng cao)**
   - Tự động failover khi Primary node gặp sự cố
   - Ứng dụng có thể tiếp tục hoạt động mà không bị gián đoạn

2. **Data Redundancy (Dự phòng dữ liệu)**
   - Dữ liệu được sao chép trên nhiều server
   - Bảo vệ khỏi mất mất dữ liệu do hardware failure

3. **Read Scalability (Khả năng mở rộng đọc)**
   - Có thể đọc dữ liệu từ Secondary nodes
   - Phân tán load đọc trên nhiều node

4. **Disaster Recovery (Khôi phục thảm họa)**
   - Backup tự động thông qua replication
   - Có thể restore từ bất kỳ Secondary node nào

### Cách hoạt động:

- **Oplog (Operations Log)**: Primary ghi tất cả các thay đổi vào oplog
- **Replication**: Secondary nodes đọc và áp dúng các operations từ oplog
- **Election**: Khi Primary down, các Secondary sẽ bầu chọn Primary mới
- **Heartbeat**: Các node liên tục gửi heartbeat để kiểm tra tình trạng

---

# Hướng Dẫn MongoDB Replica Set Từ A-Z Cho DevOps

## Tổng Quan

Hướng dẫn này sẽ giúp bạn thiết lập một MongoDB Replica Set gồm 3 nodes (1 Primary + 2 Secondary) trên Ubuntu 22.04, cùng với việc kết nối và quản lý thông qua NoSQLBooster.

## PHẦN 1: CHUẨN BỊ HẠ TẦNG

### 1.1 Yêu Cầu Hệ Thống

Tạo 3 máy ảo với cấu hình:
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 4GB mỗi VM
- **CPU**: 2 cores mỗi VM
- **Disk**: 50GB mỗi VM
- **Network**: Bridge Adapter (để có IP thật)

**Thông tin các nodes:**

| Node | IP Address | Role |
|------|------------|------|
| VM1 | 192.168.1.20 | Primary Node |
| VM2 | 192.168.1.21 | Secondary Node |
| VM3 | 192.168.1.22 | Secondary Node |

### 1.2 Cấu Hình Network

**Bước 1: Kiểm tra IP hiện tại**
```bash
ip addr show
```

**Bước 2: Cấu hình static IP (nếu cần)**
```bash
sudo nano /etc/netplan/01-network-manager-all.yaml
```

Nội dung file cấu hình:
```yaml
network:
  version: 2
  ethernets:
    enp0s3:  # Tên interface của bạn
      dhcp4: no
      addresses:
        - 192.168.1.20/24  # Thay đổi cho từng VM: 192.168.1.21, 192.168.1.22
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

**Bước 3: Apply cấu hình**
```bash
sudo netplan apply
ping 8.8.8.8  # Test kết nối
```

## PHẦN 2: CÀI ĐẶT MONGODB

### 2.1 Script Cài Đặt Tự Động

Tạo file `install-mongodb.sh` (chạy trên cả 3 VMs):
```bash
#!/bin/bash
echo "Starting MongoDB installation..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget gnupg lsb-release

# Import MongoDB public key
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package list
sudo apt update

# Install MongoDB
sudo apt install -y mongodb-org

# Pin package version (prevent auto updates)
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections

# Create directories and set permissions
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown mongodb:mongodb /var/lib/mongodb
sudo chown mongodb:mongodb /var/log/mongodb

# Enable service
sudo systemctl enable mongod

echo "MongoDB installation completed!"
```

Chạy script:
```bash
chmod +x install-mongodb.sh
./install-mongodb.sh
```

### 2.2 Cấu Hình MongoDB

Tạo file cấu hình `/etc/mongod.conf` (giống nhau trên cả 3 VMs):
```yaml
# Storage configuration  
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2  # 50% of available RAM
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy

# System log configuration
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

# Network configuration
net:
  port: 27017
  bindIp: 0.0.0.0  # Listen on all interfaces
  maxIncomingConnections: 100

# Process management
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

# Replication configuration
replication:
  replSetName: "learningRS"
  oplogSizeMB: 1024  # 1GB oplog

# Operation profiling
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
```

### 2.3 Khởi Động MongoDB

```bash
# Trên cả 3 VMs
sudo systemctl start mongod
sudo systemctl status mongod

# Kiểm tra log
sudo tail /var/log/mongodb/mongod.log

# Test kết nối local
mongosh --port 27017
```

## PHẦN 3: THIẾT LẬP REPLICA SET

### 3.1 Khởi Tạo Replica Set (Chỉ trên VM1 - Primary)

Kết nối vào MongoDB trên Primary node:
```bash
mongosh --host 192.168.1.20 --port 27017
```

Trong MongoDB Shell, chạy lệnh khởi tạo:
```javascript
// Khởi tạo replica set
rs.initiate({
  _id: "learningRS",
  members: [
    { 
      _id: 0, 
      host: "192.168.1.20:27017",
      priority: 2  // Ưu tiên cao nhất làm Primary
    },
    { 
      _id: 1, 
      host: "192.168.1.21:27017",
      priority: 1  // Có thể làm Primary
    },
    { 
      _id: 2, 
      host: "192.168.1.22:27017", 
      priority: 1  // Có thể làm Primary
    }
  ]
})

// Chờ khoảng 30 giây để replica set khởi tạo
// Sau đó kiểm tra trạng thái
rs.status()
```

### 3.2 Script Tự Động Setup (Tùy chọn)

Tạo file `setup-replica-set.sh` trên VM1:
```bash
#!/bin/bash
echo "Setting up MongoDB Replica Set..."

# Kiểm tra MongoDB đang chạy trên tất cả nodes
for ip in 192.168.1.20 192.168.1.21 192.168.1.22; do
    echo "Checking MongoDB on $ip..."
    mongosh --host $ip --port 27017 --eval "db.runCommand('ping')" --quiet
    if [ $? -eq 0 ]; then
        echo "✓ $ip is accessible"
    else
        echo "✗ Cannot connect to $ip"
        exit 1
    fi
done

# Khởi tạo replica set
echo "Initializing replica set..."
mongosh --host 192.168.1.20 --port 27017 --eval '
rs.initiate({
  _id: "learningRS",
  members: [
    { _id: 0, host: "192.168.1.20:27017", priority: 2 },
    { _id: 1, host: "192.168.1.21:27017", priority: 1 },
    { _id: 2, host: "192.168.1.22:27017", priority: 1 }
  ]
})
'

echo "Waiting for replica set to initialize..."
sleep 30

echo "Checking replica set status..."
mongosh --host 192.168.1.20 --port 27017 --eval 'rs.status()' --quiet

echo "Replica set setup completed!"
```

## PHẦN 4: KIỂM TRA VÀ TEST

### 4.1 Kiểm Tra Trạng Thái Cluster

```javascript
// Kết nối vào Primary node
mongosh --host 192.168.1.20 --port 27017

// Xem trạng thái replica set
rs.status()

// Xem cấu hình
rs.conf()

// Kiểm tra ai là Primary
rs.isMaster()

// Kiểm tra replication lag
rs.printSecondaryReplicationInfo()
```

### 4.2 Test Write và Read

**Test ghi dữ liệu trên Primary:**
```javascript
// Kết nối vào Primary
mongosh --host 192.168.1.20 --port 27017

// Tạo database và collection
use testdb
db.users.insertOne({
  name: "John Doe",
  email: "john@example.com", 
  age: 30,
  created: new Date()
})

// Insert nhiều documents
db.users.insertMany([
  {name: "Alice", email: "alice@example.com", age: 25},
  {name: "Bob", email: "bob@example.com", age: 35},
  {name: "Carol", email: "carol@example.com", age: 28}
])

// Đọc dữ liệu
db.users.find().pretty()
```

**Test đọc từ Secondary:**
```javascript
// Kết nối vào Secondary node
mongosh --host 192.168.1.21 --port 27017

// Enable read từ secondary
rs.secondaryOk()
// Hoặc dùng lệnh mới
db.getMongo().setReadPref('secondary')

// Đọc dữ liệu từ secondary
use testdb
db.users.find().pretty()
```

### 4.3 Test Failover

```javascript
// Trên Primary node, force step down
rs.stepDown(60)  // Step down trong 60 giây

// Xem node nào trở thành Primary mới
rs.status()

// Test write trên Primary mới
db.users.insertOne({name: "Test Failover", timestamp: new Date()})
```

## PHẦN 5: KẾT NỐI NOSQLBOOSTER

### 5.1 Cấu Hình Connection String

Trong NoSQLBooster, tạo connection mới với thông tin:
- **Connection Name**: MongoDB Learning Cluster
- **Connection Type**: MongoDB
- **Host**: 192.168.1.20,192.168.1.21,192.168.1.22
- **Port**: 27017
- ☑ **This is a replica set connection**
- **Replica Set Name**: learningRS
- **Database**: admin
- **Authentication**: None

Hoặc dùng URI format:
```
mongodb://192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017/admin?replicaSet=learningRS
```

### 5.2 Advanced Settings

- **Read Preference**: secondaryPreferred
- **Read Concern**: majority
- **Write Concern**: majority
- **Connection Timeout**: 30000 ms
- **Socket Timeout**: 300000 ms
- **Max Pool Size**: 100

### 5.3 Test Connection

Trong NoSQLBooster Query Editor:
```javascript
// 1. Kiểm tra connection info
db.runCommand("hello")

// 2. Kiểm tra replica set status  
rs.status()

// 3. Xem databases
show dbs

// 4. Test query
use testdb
db.users.find()

// 5. Test insert
db.products.insertOne({
  name: "Test Product",
  price: 100,
  created: new Date()
})
```

## PHẦN 6: SCRIPT MONITORING

### 6.1 Health Check Script

Tạo file `monitor-cluster.sh`:
```bash
#!/bin/bash
echo "=== MongoDB Replica Set Health Check ==="
echo "Time: $(date)"
echo

# Function to check individual node
check_node() {
    local ip=$1
    local name=$2
    
    echo "Checking $name ($ip)..."
    
    if mongosh --host $ip --port 27017 --eval "db.runCommand('ping')" --quiet > /dev/null 2>&1; then
        role=$(mongosh --host $ip --port 27017 --eval "
            try {
                var status = rs.status();
                var self = status.members.find(m => m.self);
                print(self ? self.stateStr : 'Unknown');
            } catch(e) {
                print('Standalone');
            }
        " --quiet 2>/dev/null)
        
        echo "  ✓ Status: Online - Role: $role"
    else
        echo "  ✗ Status: Offline or unreachable"
    fi
}

# Check all nodes
check_node "192.168.1.20" "Primary Node"
check_node "192.168.1.21" "Secondary Node 1"  
check_node "192.168.1.22" "Secondary Node 2"

echo
echo "=== End Health Check ==="
```

Chạy monitoring:
```bash
chmod +x monitor-cluster.sh
./monitor-cluster.sh

# Hoặc chạy định kỳ
watch -n 30 ./monitor-cluster.sh
```

## PHẦN 7: TROUBLESHOOTING

### 7.1 Các Lỗi Thường Gặp

**Lỗi 1: Connection refused**
```bash
# Kiểm tra MongoDB service
sudo systemctl status mongod

# Kiểm tra port đang listen
sudo netstat -tlnp | grep 27017

# Kiểm tra firewall
sudo ufw status
sudo ufw allow 27017

# Restart service
sudo systemctl restart mongod
```

**Lỗi 2: Replica set not initialized**
```javascript
// Trong mongosh
rs.status()
// Nếu lỗi "no replset config has been received"

// Re-initialize
rs.initiate({
  _id: "learningRS",
  members: [
    { _id: 0, host: "192.168.1.20:27017" },
    { _id: 1, host: "192.168.1.21:27017" },
    { _id: 2, host: "192.168.1.22:27017" }
  ]
})
```

**Lỗi 3: NoSQLBooster không connect được**
```bash
# Test từ command line
mongosh "mongodb://192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017/?replicaSet=learningRS"

# Nếu vẫn không được:
# - Kiểm tra firewall rules
# - Ping test từng IP
# - Kiểm tra MongoDB log files
```

### 7.2 Các lệnh hữu ích

**Kiểm tra log MongoDB:**
```bash
sudo tail -f /var/log/mongodb/mongod.log
```

**Restart toàn bộ cluster:**
```bash
# Trên từng node, restart lần lượt (bắt đầu từ Secondary)
sudo systemctl restart mongod
```

**Kiểm tra kết nối network:**
```bash
# Ping test
ping 192.168.1.20
ping 192.168.1.21
ping 192.168.1.22

# Port test
telnet 192.168.1.20 27017
telnet 192.168.1.21 27017
telnet 192.168.1.22 27017
```

## Tóm Tắt Quy Trình

1. **Chuẩn bị**: Tạo 3 VMs với Ubuntu 22.04, cấu hình IP tĩnh
2. **Cài đặt**: Chạy script cài MongoDB trên cả 3 nodes (192.168.1.20, 192.168.1.21, 192.168.1.22)
3. **Cấu hình**: Sửa file mongod.conf để enable replication với replSetName "learningRS"
4. **Khởi tạo**: Chạy rs.initiate() trên Primary node (192.168.1.20)
5. **Kiểm tra**: Test write/read và failover giữa các nodes
6. **Kết nối**: Cấu hình NoSQLBooster với connection string sử dụng IP
7. **Monitoring**: Sử dụng script để theo dõi cluster health

Replica Set này sẽ cung cấp high availability, automatic failover, và khả năng đọc từ secondary nodes để phân tải. Tất cả kết nối sử dụng IP address trực tiếp thay vì hostname để tránh vấn đề DNS resolution.
