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

| Node | Hostname | IP Address | Role |
|------|----------|------------|------|
| VM1 | mongo-primary | 192.168.1.20 | Primary Node |
| VM2 | mongo-secondary1 | 192.168.1.21 | Secondary Node |
| VM3 | mongo-secondary2 | 192.168.1.22 | Secondary Node |

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
        - 192.168.1.20/24  # Thay đổi cho từng VM
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
  replSetName: "test"
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

Kết nối vào MongoDB:
```bash
mongosh --host <mongo-primary-IP> --port 27017
```

Trong MongoDB Shell, chạy lệnh khởi tạo:
```javascript
// Khởi tạo replica set
rs.initiate({
  _id: "test",
  members: [
    { 
      _id: 0, 
      host: "mongo-primary:27017",
      priority: 2  // Ưu tiên cao nhất làm Primary
    },
    { 
      _id: 1, 
      host: "mongo-secondary1:27017",
      priority: 1  // Có thể làm Primary
    },
    { 
      _id: 2, 
      host: "mongo-secondary2:27017", 
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
for host in mongo-primary mongo-secondary1 mongo-secondary2; do
    echo "Checking MongoDB on $host..."
    mongosh --host $host --port 27017 --eval "db.runCommand('ping')" --quiet
    if [ $? -eq 0 ]; then
        echo "✓ $host is accessible"
    else
        echo "✗ Cannot connect to $host"
        exit 1
    fi
done

# Khởi tạo replica set
echo "Initializing replica set..."
mongosh --host mongo-primary --port 27017 --eval '
rs.initiate({
  _id: "learningRS",
  members: [
    { _id: 0, host: "mongo-primary:27017", priority: 2 },
    { _id: 1, host: "mongo-secondary1:27017", priority: 1 },
    { _id: 2, host: "mongo-secondary2:27017", priority: 1 }
  ]
})
'

echo "Waiting for replica set to initialize..."
sleep 30

echo "Checking replica set status..."
mongosh --host mongo-primary --port 27017 --eval 'rs.status()' --quiet

echo "Replica set setup completed!"
```

## PHẦN 4: KIỂM TRA VÀ TEST

### 4.1 Kiểm Tra Trạng Thái Cluster

```javascript
// Kết nối vào bất kỳ node nào
mongosh --host mongo-primary --port 27017

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
mongosh --host mongo-primary --port 27017

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
mongosh --host mongo-secondary1 --port 27017

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
- **Host**: mongo-primary,mongo-secondary1,mongo-secondary2
- **Port**: 27017
- ☑ **This is a replica set connection**
- **Replica Set Name**: learningRS
- **Database**: admin
- **Authentication**: None (for now)

Hoặc dùng URI format:
```
mongodb://mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/admin?replicaSet=learningRS
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

## PHẦN 5A: THIẾT LẬP AUTHENTICATION VÀ TẠO USER

### 5A.1 Tạo Admin User (Chỉ trên Primary Node)

**Bước 1: Kết nối vào Primary Node**
```bash
mongosh --host mongo-primary --port 27017
```

**Bước 2: Tạo Admin User**
```javascript
// Chuyển sang database admin
use admin

// Tạo user admin với full permissions
db.createUser({
  user: "mongoAdmin",
  pwd: "SecurePassword123!",
  roles: [
    { role: "root", db: "admin" },
    { role: "clusterAdmin", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "userAdminAnyDatabase", db: "admin" }
  ]
})

// Verify user đã được tạo
db.getUsers()
```

**Bước 3: Tạo Application User**
```javascript
// Tạo user cho application
db.createUser({
  user: "appUser", 
  pwd: "AppPassword456!",
  roles: [
    { role: "readWrite", db: "testdb" },
    { role: "readWrite", db: "productiondb" }
  ]
})

// Tạo user chỉ đọc
db.createUser({
  user: "readOnlyUser",
  pwd: "ReadOnlyPass789!",
  roles: [
    { role: "read", db: "testdb" },
    { role: "read", db: "productiondb" }
  ]
})
```

### 5A.2 Enable Authentication

**Bước 1: Tạo Keyfile cho Replica Set Authentication**
Trên Primary node:
```bash
# Tạo keyfile
sudo mkdir -p /opt/mongodb
sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
sudo mv /tmp/mongodb-keyfile /opt/mongodb/mongodb-keyfile
sudo chmod 400 /opt/mongodb/mongodb-keyfile
sudo chown mongodb:mongodb /opt/mongodb/mongodb-keyfile
```

**Bước 2: Copy keyfile sang các Secondary nodes**
```bash
# Từ Primary node, copy sang Secondary nodes
scp /opt/mongodb/mongodb-keyfile user@mongo-secondary1:/tmp/
scp /opt/mongodb/mongodb-keyfile user@mongo-secondary2:/tmp/

# Trên mỗi Secondary node
sudo mkdir -p /opt/mongodb
sudo mv /tmp/mongodb-keyfile /opt/mongodb/
sudo chmod 400 /opt/mongodb/mongodb-keyfile
sudo chown mongodb:mongodb /opt/mongodb/mongodb-keyfile
```

**Bước 3: Cập nhật cấu hình MongoDB (trên cả 3 nodes)**
```bash
sudo nano /etc/mongod.conf
```

Thêm phần security vào file cấu hình:
```yaml
# ... existing configuration ...

# Security configuration
security:
  authorization: enabled
  keyFile: /opt/mongodb/mongodb-keyfile

# ... rest of configuration ...
```

**Bước 4: Restart tất cả MongoDB services**
```bash
# Trên cả 3 nodes, restart lần lượt (bắt đầu từ Secondary)
# Secondary nodes trước
sudo systemctl restart mongod

# Primary node cuối cùng
sudo systemctl restart mongod
```

### 5A.3 Test Authentication

```bash
# Test kết nối với admin user
mongosh --host mongo-primary --port 27017 -u mongoAdmin -p SecurePassword123! --authenticationDatabase admin

# Test trong MongoDB shell
db.runCommand({connectionStatus: 1})
rs.status()
```

### 5A.4 Tạo Connection URLs cho NoSQL Booster

**Admin Connection (Full Access):**
```
mongodb://mongoAdmin:SecurePassword123!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/admin?replicaSet=learningRS&authSource=admin
```

**Application User Connection:**
```
mongodb://appUser:AppPassword456!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/testdb?replicaSet=learningRS&authSource=admin
```

**Read Only Connection:**
```
mongodb://readOnlyUser:ReadOnlyPass789!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/testdb?replicaSet=learningRS&authSource=admin
```

### 5A.5 Cấu hình NoSQL Booster với Authentication

**Cách 1: Sử dụng URI Connection String**
1. Mở NoSQL Booster
2. File → New Connection
3. Chọn "URI" tab
4. Paste một trong các connection string ở trên
5. Test Connection

**Cách 2: Cấu hình Manual**
1. **Connection Name**: MongoDB Secure Cluster
2. **Connection Type**: MongoDB
3. **Host**: mongo-primary,mongo-secondary1,mongo-secondary2
4. **Port**: 27017
5. ☑ **This is a replica set connection**
6. **Replica Set Name**: learningRS
7. **Database**: admin
8. **Authentication**: Username/Password
9. **Username**: mongoAdmin
10. **Password**: SecurePassword123!
11. **Auth Database**: admin

### 5A.6 Script Tạo Users Tự Động

Tạo file `create-users.sh`:
```bash
#!/bin/bash
echo "Creating MongoDB Users..."

# Kết nối và tạo users
mongosh --host mongo-primary --port 27017 --eval '
use admin

// Tạo admin user
try {
  db.createUser({
    user: "mongoAdmin",
    pwd: "SecurePassword123!",
    roles: [
      { role: "root", db: "admin" },
      { role: "clusterAdmin", db: "admin" }
    ]
  })
  print("✓ Admin user created successfully")
} catch(e) {
  print("Admin user might already exist: " + e.message)
}

// Tạo application user  
try {
  db.createUser({
    user: "appUser",
    pwd: "AppPassword456!",
    roles: [
      { role: "readWrite", db: "testdb" },
      { role: "readWrite", db: "productiondb" }
    ]
  })
  print("✓ Application user created successfully")
} catch(e) {
  print("Application user might already exist: " + e.message)
}

// Tạo read-only user
try {
  db.createUser({
    user: "readOnlyUser", 
    pwd: "ReadOnlyPass789!",
    roles: [
      { role: "read", db: "testdb" },
      { role: "read", db: "productiondb" }
    ]
  })
  print("✓ Read-only user created successfully")
} catch(e) {
  print("Read-only user might already exist: " + e.message)
}

print("=== User creation completed ===")
print("Admin URI: mongodb://mongoAdmin:SecurePassword123!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/admin?replicaSet=learningRS&authSource=admin")
print("App URI: mongodb://appUser:AppPassword456!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/testdb?replicaSet=learningRS&authSource=admin")
print("ReadOnly URI: mongodb://readOnlyUser:ReadOnlyPass789!@mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/testdb?replicaSet=learningRS&authSource=admin")
'

echo "Users created! Connection strings printed above."
```

Chạy script:
```bash
chmod +x create-users.sh
./create-users.sh
```

### 5A.7 Quản Lý Users

**Xem danh sách users:**
```javascript
// Kết nối với admin credentials
use admin
db.getUsers()

// Xem users của database cụ thể
use testdb
db.getUsers()
```

**Thay đổi password:**
```javascript
use admin
db.changeUserPassword("appUser", "NewPassword123!")
```

**Xóa user:**
```javascript
use admin
db.dropUser("username")
```

**Thêm role cho user:**
```javascript
use admin
db.grantRolesToUser("appUser", [
  { role: "readWrite", db: "newdatabase" }
])
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
    local host=$1
    local name=$2
    
    echo "Checking $name ($host)..."
    
    if mongosh --host $host --port 27017 --eval "db.runCommand('ping')" --quiet > /dev/null 2>&1; then
        role=$(mongosh --host $host --port 27017 --eval "
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
check_node "mongo-primary" "Primary Node"
check_node "mongo-secondary1" "Secondary Node 1"  
check_node "mongo-secondary2" "Secondary Node 2"

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
    { _id: 0, host: "mongo-primary:27017" },
    { _id: 1, host: "mongo-secondary1:27017" },
    { _id: 2, host: "mongo-secondary2:27017" }
  ]
})
```

**Lỗi 3: NoSQLBooster không connect được**
```bash
# Test từ command line
mongosh "mongodb://mongo-primary:27017,mongo-secondary1:27017,mongo-secondary2:27017/?replicaSet=learningRS"

# Nếu connect được từ command line nhưng NoSQLBooster không được:
# - Kiểm tra hostname resolution
# - Thử dùng IP thay vì hostname
# - Check firewall rules
```

## Tóm Tắt Quy Trình

1. **Chuẩn bị**: Tạo 3 VMs với Ubuntu 22.04, cấu hình network và hostname
2. **Cài đặt**: Chạy script cài MongoDB trên cả 3 nodes
3. **Cấu hình**: Sửa file mongod.conf để enable replication
4. **Khởi tạo**: Chạy rs.initiate() trên Primary node
5. **Kiểm tra**: Test write/read và failover
6. **Kết nối**: Cấu hình NoSQLBooster với connection string
7. **Monitoring**: Sử dụng các script để theo dõi cluster

Replica Set này sẽ cung cấp high availability, automatic failover, và khả năng đọc từ secondary nodes để phân tải.
