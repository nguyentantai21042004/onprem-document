# Thiết Lập MongoDB Replica Set

## Mục Lục

- [Giới Thiệu](#giới-thiệu)
- [Yêu Cầu Tiên Quyết](#yêu-cầu-tiên-quyết)
- [Tổng Quan Kiến Trúc](#tổng-quan-kiến-trúc)
- [Hướng Dẫn Cài Đặt](#hướng-dẫn-cài-đặt)
- [Cấu Hình](#cấu-hình)
- [Quản Lý Replica Set](#quản-lý-replica-set)
- [Thực Hành Bảo Mật Tốt Nhất](#thực-hành-bảo-mật-tốt-nhất)
- [Giám Sát và Bảo Trì](#giám-sát-và-bảo-trì)
- [Khắc Phục Sự Cố](#khắc-phục-sự-cố)
- [Tích Hợp với Các Dịch Vụ Khác](#tích-hợp-với-các-dịch-vụ-khác)

---

## Giới Thiệu

MongoDB Replica Set là một nhóm các instance MongoDB duy trì cùng một tập dữ liệu, cung cấp tính dự phòng và khả năng sẵn sàng cao. Đây là nền tảng cho tất cả các triển khai MongoDB production.

### Replica Set là gì?

Replica Set là một nhóm các tiến trình MongoDB duy trì cùng một tập dữ liệu. Nó bao gồm:

- **Primary Node**: Nhận tất cả các thao tác ghi
- **Secondary Nodes**: Sao chép dữ liệu từ Primary
- **Arbiter** (tùy chọn): Tham gia bầu cử nhưng không lưu trữ dữ liệu

### Lợi Ích Chính

1. **Khả Năng Sẵn Sàng Cao**
   - Tự động chuyển đổi dự phòng khi Primary lỗi
   - Ứng dụng có thể tiếp tục hoạt động không bị gián đoạn

2. **Dự Phòng Dữ Liệu**
   - Dữ liệu được sao chép trên nhiều máy chủ
   - Bảo vệ chống lỗi phần cứng

3. **Khả Năng Mở Rộng Đọc**
   - Các thao tác đọc có thể được phân phối đến các node Secondary
   - Cải thiện hiệu suất cho khối lượng công việc đọc nhiều

4. **Khôi Phục Thảm Họa**
   - Sao lưu tự động thông qua replication
   - Khả năng khôi phục point-in-time

---

## Yêu Cầu Tiên Quyết

### Yêu Cầu Phần Cứng

| Thành Phần | Tối Thiểu | Khuyến Nghị |
|------------|-----------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 50GB SSD | 100GB+ SSD |
| **Network** | 1 Gbps | 1 Gbps |

### Yêu Cầu Phần Mềm

- **OS**: Ubuntu 22.04 LTS
- **MongoDB**: 7.0 hoặc mới hơn
- **Network**: Địa chỉ IP tĩnh cho tất cả các node

### Cấu Hình Mạng

| Node | Địa Chỉ IP | Vai Trò |
|------|------------|---------|
| VM1 | 192.168.1.20 | Primary |
| VM2 | 192.168.1.21 | Secondary |
| VM3 | 192.168.1.22 | Secondary |

---

## Tổng Quan Kiến Trúc

```
┌─────────────────────────────────────────────────────────────┐
│                MongoDB Replica Set                          │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   Primary    │    │  Secondary   │    │  Secondary   │   │
│  │192.168.1.20  │◄──►│192.168.1.21  │◄──►│192.168.1.22  │   │
│  │   :27017     │    │   :27017     │    │   :27017     │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Oplog                                │ │
│  │  • Nhật ký thao tác trên Primary                       │ │
│  │  • Được sao chép đến Secondaries                       │ │
│  │  • Duy trì tính nhất quán dữ liệu                      │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │    Ứng Dụng           │
                    │                       │
                    │  • Ghi vào Primary    │
                    │  • Đọc từ bất kỳ Node │
                    │  • Tự động failover   │
                    └───────────────────────┘
```

---

## Hướng Dẫn Cài Đặt

### Bước 1: Chuẩn Bị Hệ Thống

Chạy trên cả ba VM:

```bash
#!/bin/bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói yêu cầu
sudo apt install -y curl wget gnupg lsb-release ca-certificates

# Đặt timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Cấu hình IP tĩnh (ví dụ cho VM1)
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.20/24  # Thay đổi cho mỗi VM: .21, .22
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Áp dụng cấu hình mạng
sudo netplan apply
```

### Bước 2: Cài Đặt MongoDB

Tạo và chạy script cài đặt trên tất cả VM:

```bash
#!/bin/bash
# install-mongodb.sh
echo "Bắt đầu cài đặt MongoDB..."

# Import MongoDB public key
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Thêm MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Cập nhật danh sách package
sudo apt update

# Cài đặt MongoDB
sudo apt install -y mongodb-org

# Khóa phiên bản package
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections

# Tạo thư mục
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown mongodb:mongodb /var/lib/mongodb
sudo chown mongodb:mongodb /var/log/mongodb

# Kích hoạt service
sudo systemctl enable mongod

echo "Hoàn thành cài đặt MongoDB!"
```

### Bước 3: Cấu Hình MongoDB

Tạo file cấu hình `/etc/mongod.conf` (giống nhau trên tất cả VM):

```yaml
# Cấu hình Storage
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy

# Cấu hình System log
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
  logLevel: 1

# Cấu hình Network
net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 100
  compression:
    compressors: snappy

# Quản lý Process
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

# Cấu hình Security
security:
  authorization: enabled
  keyFile: /etc/mongodb-keyfile

# Cấu hình Replication
replication:
  replSetName: "learningRS"
  oplogSizeMB: 1024

# Operation profiling
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
```

### Bước 4: Thiết Lập Bảo Mật

Tạo keyfile cho xác thực inter-replica:

```bash
# Tạo keyfile (chỉ chạy trên PRIMARY)
sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
sudo chmod 400 /tmp/mongodb-keyfile

# Sao chép đến tất cả nodes
scp /tmp/mongodb-keyfile admin@192.168.1.21:/tmp/
scp /tmp/mongodb-keyfile admin@192.168.1.22:/tmp/

# Trên mỗi node:
sudo cp /tmp/mongodb-keyfile /etc/mongodb-keyfile
sudo chown mongodb:mongodb /etc/mongodb-keyfile
sudo chmod 400 /etc/mongodb-keyfile
```

---

## Cấu Hình

### Bước 1: Khởi Động Dịch Vụ MongoDB

Khởi động MongoDB trên tất cả nodes:

```bash
# Trên cả ba VM
sudo systemctl start mongod
sudo systemctl status mongod

# Kiểm tra logs
sudo tail -f /var/log/mongodb/mongod.log
```

### Bước 2: Khởi Tạo Replica Set

Kết nối đến node PRIMARY và khởi tạo:

```bash
# Kết nối đến PRIMARY (192.168.1.20)
mongosh --host 192.168.1.20 --port 27017
```

Khởi tạo replica set:

```javascript
// Khởi tạo replica set
rs.initiate({
  _id: "learningRS",
  members: [
    { 
      _id: 0, 
      host: "192.168.1.20:27017",
      priority: 2
    },
    { 
      _id: 1, 
      host: "192.168.1.21:27017",
      priority: 1
    },
    { 
      _id: 2, 
      host: "192.168.1.22:27017",
      priority: 1
    }
  ]
})

// Chờ khởi tạo (30 giây)
// Kiểm tra trạng thái
rs.status()
```

### Bước 3: Tạo Admin User

```javascript
// Tạo admin user
use admin
db.createUser({
  user: "admin",
  pwd: "your_secure_password",
  roles: [
    { role: "root", db: "admin" }
  ]
})

// Tạo replication user
db.createUser({
  user: "replicator",
  pwd: "replicator_password",
  roles: [
    { role: "clusterAdmin", db: "admin" },
    { role: "backup", db: "admin" },
    { role: "restore", db: "admin" }
  ]
})
```

---

## Quản Lý Replica Set

### Giám Sát Replica Set

```javascript
// Kiểm tra trạng thái replica set
rs.status()

// Kiểm tra cấu hình replica set
rs.conf()

// Kiểm tra trạng thái oplog
rs.printReplicationInfo()

// Kiểm tra trạng thái member
rs.isMaster()
```

### Thêm Member Mới

```javascript
// Thêm member mới
rs.add("192.168.1.23:27017")

// Thêm với cấu hình cụ thể
rs.add({
  _id: 3,
  host: "192.168.1.23:27017",
  priority: 0,
  hidden: true
})
```

### Xóa Member

```javascript
// Xóa member
rs.remove("192.168.1.23:27017")

// Xóa theo ID
rs.remove("192.168.1.23:27017")
```

### Failover Thủ Công

```javascript
// Hạ cấp primary (ép buộc bầu cử)
rs.stepDown()

// Ép buộc cấu hình lại
rs.reconfig(config, {force: true})
```

---

## Thực Hành Bảo Mật Tốt Nhất

### 1. Xác Thực

```javascript
// Kích hoạt xác thực trong mongod.conf
security:
  authorization: enabled

// Sử dụng mật khẩu mạnh
use admin
db.createUser({
  user: "appuser",
  pwd: passwordPrompt(),
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})
```

### 2. Bảo Mật Mạng

```bash
# Cấu hình firewall
sudo ufw allow from 192.168.1.0/24 to any port 27017
sudo ufw deny 27017

# Bind đến các interface cụ thể
net:
  bindIp: 192.168.1.20,127.0.0.1
```

### 3. Cấu Hình SSL/TLS

```yaml
# mongod.conf
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
```

---

## Giám Sát và Bảo Trì

### 1. Thu Thập Metrics

```javascript
// Thống kê database
db.stats()

// Thống kê collection
db.collection.stats()

// Trạng thái server
db.serverStatus()

// Metrics replica set
rs.status().members.forEach(member => {
  print(`${member.name}: ${member.stateStr}`)
})
```

### 2. Chiến Lược Backup

```bash
#!/bin/bash
# backup-mongodb.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/mongodb"

# Tạo thư mục backup
mkdir -p $BACKUP_DIR

# Backup sử dụng mongodump
mongodump --host 192.168.1.20:27017 \
  --username admin \
  --password your_password \
  --authenticationDatabase admin \
  --out $BACKUP_DIR/backup_$DATE

# Nén backup
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz $BACKUP_DIR/backup_$DATE
rm -rf $BACKUP_DIR/backup_$DATE

# Xóa backup cũ (giữ lại 7 ngày gần nhất)
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
```

### 3. Kiểm Tra Sức Khỏe

```bash
#!/bin/bash
# health-check.sh
NODES=("192.168.1.20" "192.168.1.21" "192.168.1.22")

for node in "${NODES[@]}"; do
  echo "Đang kiểm tra $node..."
  
  # Kiểm tra xem MongoDB có đang chạy không
  if mongosh --host $node --port 27017 --eval "db.runCommand('ping')" --quiet; then
    echo "✓ $node đang hoạt động"
  else
    echo "✗ $node không hoạt động"
  fi
done

# Kiểm tra sức khỏe replica set
mongosh --host 192.168.1.20:27017 --eval "
  rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr + ' (health: ' + member.health + ')');
  })
"
```

---

## Khắc Phục Sự Cố

### Các Vấn Đề Thường Gặp

#### 1. Node Không Tham Gia Replica Set

```bash
# Kiểm tra logs
sudo tail -f /var/log/mongodb/mongod.log

# Kiểm tra kết nối mạng
telnet 192.168.1.20 27017

# Kiểm tra phân giải DNS
nslookup 192.168.1.20
```

#### 2. Lỗi Xác Thực

```javascript
// Kiểm tra users
use admin
db.getUsers()

// Đặt lại mật khẩu user
db.changeUserPassword("username", "newpassword")
```

#### 3. Độ Trễ Replica

```javascript
// Kiểm tra độ trễ replication
rs.printSlaveReplicationInfo()

// Kiểm tra kích thước oplog
db.oplog.rs.stats()
```

### Tối Ưu Hóa Hiệu Suất

```javascript
// Kiểm tra các truy vấn chậm
db.setProfilingLevel(1, { slowms: 100 })
db.system.profile.find().sort({ ts: -1 }).limit(5)

// Tối ưu hóa index
db.collection.createIndex({ field: 1 })
db.collection.getIndexes()
```

---

## Tích Hợp với Các Dịch Vụ Khác

### 1. Kết Nối Ứng Dụng

```javascript
// Connection string
const connectionString = "mongodb://admin:password@192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017/myapp?replicaSet=learningRS&authSource=admin";

// Ví dụ Node.js
const { MongoClient } = require('mongodb');

const client = new MongoClient(connectionString, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
  readPreference: 'secondaryPreferred'
});
```

### 2. Tích Hợp Giám Sát

```yaml
# prometheus.yml
- job_name: 'mongodb'
  static_configs:
    - targets: ['192.168.1.20:9216', '192.168.1.21:9216', '192.168.1.22:9216']
```

### 3. Tích Hợp Backup

```bash
# Tích hợp với dịch vụ backup
#!/bin/bash
# Lập lịch với cron
# 0 2 * * * /opt/scripts/backup-mongodb.sh

# Upload lên cloud storage
aws s3 cp /backup/mongodb/backup_latest.tar.gz s3://your-bucket/mongodb/
```

---

## Các Bước Tiếp Theo

Sau khi thiết lập MongoDB thành công:

1. **Cấu Hình Giám Sát**: Thiết lập Prometheus và Grafana cho MongoDB metrics
2. **Triển Khai Backup**: Lập lịch backup định kỳ và kiểm tra khôi phục
3. **Tăng Cường Bảo Mật**: Triển khai SSL/TLS và các biện pháp bảo mật bổ sung
4. **Điều Chỉnh Hiệu Suất**: Tối ưu hóa truy vấn và index dựa trên workload
5. **Kiểm Tra Khả Năng Sẵn Sàng Cao**: Kiểm tra các tình huống failover

Để tìm hiểu thêm các chủ đề nâng cao, tham khảo:
- [Harbor Container Registry](container-registry.md)
- [Thiết Lập Monitoring](monitoring-setup.md)
- [Cấu Hình VPN Server](vpn-server.md)

---

## Kết Luận

MongoDB Replica Set này cung cấp một giải pháp cơ sở dữ liệu mạnh mẽ, có khả năng mở rộng với tính sẵn sàng cao và dự phòng dữ liệu. Thiết lập này đảm bảo các ứng dụng của bạn có thể xử lý lỗi một cách graceful trong khi duy trì tính nhất quán dữ liệu trên tất cả các node.

Đối với các triển khai production, hãy xem xét các tính năng bổ sung như sharding để mở rộng theo chiều ngang và cấu hình bảo mật nâng cao dựa trên yêu cầu cụ thể của bạn. 