# MongoDB Replica Set với LVM Storage - Production Guide

*Complete step-by-step guide đã được test và verified hoạt động 100%*

---

## Tổng Quan

Guide này hướng dẫn setup **MongoDB Replica Set 3 nodes** với:
- ✅ **High Availability** với automatic failover
- ✅ **LVM Storage** layout tối ưu performance  
- ✅ **Authentication & Security** đầy đủ
- ✅ **Production-ready configuration**
- ✅ **Comprehensive testing & monitoring**

### Kiến Trúc Cluster

| Node | IP Address | Role | Priority |
|------|------------|------|----------|
| **mongo-primary** | 172.16.19.111 | PRIMARY | 3 (highest) |
| **mongo-secondary-1** | 172.16.19.112 | SECONDARY | 2 |
| **mongo-secondary-2** | 172.16.19.113 | SECONDARY | 1 |

**Replica Set Name**: `replicaCfg`

---

## Prerequisites

### Hệ Thống
- **Ubuntu 22.04 LTS** hoặc compatible
- **RAM**: Tối thiểu 4GB, khuyến nghị 8GB+
- **Storage**: LVM setup với ubuntu-vg volume group
- **Network**: Internal network 172.16.19.0/24

### Ports Required
- **27017**: MongoDB primary port
- **22**: SSH management

---

## Bước 1: Chuẩn Bị Hệ Thống (trên cả 3 VMs)

### 1.1 Update System và Install Dependencies

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget gnupg lsb-release htop iotop

# Install LVM tools
sudo apt install -y lvm2

# Verify LVM setup
sudo vgs
sudo lvs
lsblk
```

### 1.2 Configure Hostnames và Network

```bash
# Set hostname (adjust per node)
sudo hostnamectl set-hostname mongo-primary     # On 172.16.19.111
sudo hostnamectl set-hostname mongo-secondary-1 # On 172.16.19.112  
sudo hostnamectl set-hostname mongo-secondary-2 # On 172.16.19.113

# Add hosts entries for easier management
sudo tee -a /etc/hosts > /dev/null <<EOF
172.16.19.111 mongo-primary
172.16.19.112 mongo-secondary-1  
172.16.19.113 mongo-secondary-2
EOF

# Verify network connectivity
ping -c 3 172.16.19.111
ping -c 3 172.16.19.112
ping -c 3 172.16.19.113
```

### 1.3 System Optimization

```bash
# Configure kernel parameters for MongoDB
sudo tee /etc/sysctl.d/99-mongodb.conf > /dev/null <<EOF
# MongoDB optimizations
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.max_map_count = 262144

# Network optimizations
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_max_syn_backlog = 4096
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 30
vm.overcommit_memory = 1
EOF

# Apply kernel parameters
sudo sysctl -p /etc/sysctl.d/99-mongodb.conf

# Disable transparent huge pages
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Make THP disable permanent
sudo tee /etc/systemd/system/disable-thp.service > /dev/null <<EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'

[Install]
WantedBy=basic.target
EOF

sudo systemctl enable disable-thp
sudo systemctl start disable-thp
```

---

---

## Bước 2: Thiết Lập LVM Storage (trên cả 3 VMs)

### 2.1 Kiểm Tra LVM Hiện Tại

```bash
# Xem trạng thái LVM
sudo vgs
sudo lvs
lsblk

# Kiểm tra free space (cần ít nhất 40GB)
sudo vgdisplay ubuntu-vg | grep "Free"
```

### 2.2 Tạo LVM Logical Volumes

```bash
# Tạo volumes cho MongoDB (adjust sizes theo needs)
sudo lvcreate -L 25G -n mongodb-data ubuntu-vg
sudo lvcreate -L 8G -n mongodb-logs ubuntu-vg  
sudo lvcreate -L 6G -n mongodb-backup ubuntu-vg

# Verify volumes created
sudo lvs | grep mongodb
```

### 2.3 Format Filesystems

```bash
# Format với XFS cho optimal database performance
sudo mkfs.xfs /dev/ubuntu-vg/mongodb-data
sudo mkfs.xfs /dev/ubuntu-vg/mongodb-logs
sudo mkfs.ext4 /dev/ubuntu-vg/mongodb-backup

# Verify formatting
sudo blkid | grep mongodb
```

### 2.4 Create Mount Points và Mount

```bash
# Create directories
sudo mkdir -p /data/mongodb
sudo mkdir -p /logs/mongodb
sudo mkdir -p /backup/mongodb

# Mount filesystems
sudo mount /dev/ubuntu-vg/mongodb-data /data/mongodb
sudo mount /dev/ubuntu-vg/mongodb-logs /logs/mongodb
sudo mount /dev/ubuntu-vg/mongodb-backup /backup/mongodb

# Verify mounts
df -h | grep mongodb
```

### 2.5 Configure Auto-mount

```bash
# Add to fstab for automatic mounting
sudo tee -a /etc/fstab > /dev/null <<EOF
# MongoDB LVM mounts
/dev/ubuntu-vg/mongodb-data /data/mongodb xfs defaults,noatime 0 0
/dev/ubuntu-vg/mongodb-logs /logs/mongodb xfs defaults,noatime 0 0
/dev/ubuntu-vg/mongodb-backup /backup/mongodb ext4 defaults,noatime 0 0
EOF

# Test auto-mount
sudo umount /data/mongodb /logs/mongodb /backup/mongodb
sudo mount -a
df -h | grep mongodb
```

---

## Bước 3: Cài Đặt MongoDB (trên cả 3 VMs)

### 3.1 Add MongoDB Repository

```bash
# Import MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package database
sudo apt update
```

### 3.2 Install MongoDB

```bash
# Install MongoDB packages
sudo apt install -y mongodb-org

# Hold packages to prevent automatic updates
sudo apt-mark hold mongodb-org mongodb-org-database mongodb-org-server mongodb-org-mongos mongodb-org-tools

# Verify installation
mongod --version
mongosh --version
```

### 3.3 Configure System Limits

```bash
# Enhanced system limits for MongoDB
sudo tee /etc/security/limits.d/99-mongodb.conf > /dev/null <<EOF
# MongoDB system limits
mongodb soft nproc 64000
mongodb hard nproc 64000
mongodb soft nofile 128000
mongodb hard nofile 128000
mongodb soft memlock unlimited
mongodb hard memlock unlimited
mongodb soft fsize unlimited
mongodb hard fsize unlimited
mongodb soft cpu unlimited
mongodb hard cpu unlimited
EOF

# Set ownership for directories
sudo chown -R mongodb:mongodb /data/mongodb
sudo chown -R mongodb:mongodb /logs/mongodb
sudo chown -R mongodb:mongodb /backup/mongodb

# Enable service (don't start yet)
sudo systemctl enable mongod

# Verify user created
id mongodb
```

---

## Bước 4: Cấu Hình MongoDB (trên cả 3 VMs)

### 4.1 Create Production Configuration

**Trên mongo-primary (172.16.19.111):**

```bash
# Backup original config
sudo cp /etc/mongod.conf /etc/mongod.conf.original

# Create production config for primary
sudo tee /etc/mongod.conf > /dev/null <<EOF
# MongoDB Production Configuration - PRIMARY
# Generated: $(date)

# ========== STORAGE CONFIGURATION ==========
storage:
  dbPath: /data/mongodb
  directoryPerDB: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4  # Adjust based on available RAM
      journalCompressor: snappy
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

# ========== SYSTEM LOG CONFIGURATION ==========
systemLog:
  destination: file
  path: /logs/mongodb/mongod.log
  logAppend: true
  logRotate: reopen
  component:
    accessControl:
      verbosity: 0
    command:
      verbosity: 0
    storage:
      verbosity: 0

# ========== NETWORK CONFIGURATION ==========
net:
  port: 27017
  bindIp: 127.0.0.1,172.16.19.111
  maxIncomingConnections: 1000
  compression:
    compressors: snappy,zstd

# ========== PROCESS MANAGEMENT ==========
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid

# ========== REPLICATION CONFIGURATION ==========
replication:
  replSetName: "replicaCfg"
  oplogSizeMB: 2048

# ========== OPERATION PROFILING ==========
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100

# ========== SET PARAMETERS ==========
setParameter:
  wiredTigerConcurrentReadTransactions: 128
  wiredTigerConcurrentWriteTransactions: 128
  tcmallocAggressiveMemoryDecommit: true
  diagnosticDataCollectionEnabled: true
EOF
```

**Trên mongo-secondary-1 (172.16.19.112):**

```bash
# Copy config và adjust IP
sudo cp /etc/mongod.conf /etc/mongod.conf.original

sudo tee /etc/mongod.conf > /dev/null <<EOF
# MongoDB Production Configuration - SECONDARY-1

storage:
  dbPath: /data/mongodb
  directoryPerDB: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4
      journalCompressor: snappy
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

systemLog:
  destination: file
  path: /logs/mongodb/mongod.log
  logAppend: true
  logRotate: reopen

net:
  port: 27017
  bindIp: 127.0.0.1,172.16.19.112
  maxIncomingConnections: 1000

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid

replication:
  replSetName: "replicaCfg"
  oplogSizeMB: 2048

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100

setParameter:
  wiredTigerConcurrentReadTransactions: 128
  wiredTigerConcurrentWriteTransactions: 128
EOF
```

**Trên mongo-secondary-2 (172.16.19.113):**

```bash
# Similar config với IP 172.16.19.113
sudo cp /etc/mongod.conf /etc/mongod.conf.original

sudo tee /etc/mongod.conf > /dev/null <<EOF
# MongoDB Production Configuration - SECONDARY-2

storage:
  dbPath: /data/mongodb
  directoryPerDB: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4
      journalCompressor: snappy
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

systemLog:
  destination: file
  path: /logs/mongodb/mongod.log
  logAppend: true
  logRotate: reopen

net:
  port: 27017
  bindIp: 127.0.0.1,172.16.19.113
  maxIncomingConnections: 1000

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid

replication:
  replSetName: "replicaCfg"
  oplogSizeMB: 2048

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100

setParameter:
  wiredTigerConcurrentReadTransactions: 128
  wiredTigerConcurrentWriteTransactions: 128
EOF
```

### 4.2 Setup Log Rotation

```bash
# Trên cả 3 nodes
sudo tee /etc/logrotate.d/mongodb > /dev/null <<EOF
/logs/mongodb/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0640 mongodb mongodb
    sharedscripts
    postrotate
        /bin/kill -SIGUSR1 \$(cat /var/run/mongodb/mongod.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

# Test log rotation config
sudo logrotate -d /etc/logrotate.d/mongodb
```

### 4.3 Start MongoDB Services (NO Authentication)

```bash
# Trên cả 3 nodes
sudo systemctl start mongod
sudo systemctl status mongod

# Test connection (specific IP)
mongosh --host 172.16.19.111 --port 27017 --eval "db.runCommand('ping')"  # Primary
mongosh --host 172.16.19.112 --port 27017 --eval "db.runCommand('ping')"  # Secondary-1
mongosh --host 172.16.19.113 --port 27017 --eval "db.runCommand('ping')"  # Secondary-2

# Verify port binding
sudo ss -tlnp | grep 27017
```

---

## Bước 5: Setup Security (Authentication & Keyfile)

---

### 5.1 Tạo Keyfile cho Inter-Replica Authentication

**Trên mongo-primary (172.16.19.111):**

```bash
# Generate keyfile
sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
sudo chmod 400 /tmp/mongodb-keyfile

# Copy keyfile to secondary nodes
scp /tmp/mongodb-keyfile root@172.16.19.112:/tmp/
scp /tmp/mongodb-keyfile root@172.16.19.113:/tmp/

echo "✅ Keyfile distributed to all nodes"
```

**Trên cả 3 nodes (111, 112, 113):**

```bash
# Install keyfile
sudo cp /tmp/mongodb-keyfile /etc/mongodb-keyfile
sudo chown mongodb:mongodb /etc/mongodb-keyfile
sudo chmod 400 /etc/mongodb-keyfile

# Verify keyfile
ls -la /etc/mongodb-keyfile
sudo wc -c /etc/mongodb-keyfile  # Should be ~1024 bytes

# Clean up temp file
rm /tmp/mongodb-keyfile
```

---

## Bước 6: Initialize Replica Set

### 6.1 Initialize Replica Set (CHỈ trên PRIMARY)

**Trên mongo-primary (172.16.19.111):**

```bash
# Connect to MongoDB
mongosh --host 172.16.19.111 --port 27017
```

**Trong MongoDB shell:**

```javascript
// Initialize replica set
rs.initiate({
  _id: "replicaCfg",
  members: [
    { _id: 0, host: "172.16.19.111:27017", priority: 3 },  // PRIMARY
    { _id: 1, host: "172.16.19.112:27017", priority: 2 },  // SECONDARY-1
    { _id: 2, host: "172.16.19.113:27017", priority: 1 }   // SECONDARY-2
  ]
})

// Wait for initialization (30-60 seconds)
sleep(30000)

// Check status
rs.status()

// Verify configuration
rs.conf()

// Exit shell
exit
```

### 6.2 Verify Replica Set

```bash
# Check replica set status
mongosh --host 172.16.19.111 --port 27017 --eval "
rs.status().members.forEach(function(member) {
  print(member.name + ': ' + member.stateStr);
});
"

# Expected output:
# 172.16.19.111:27017: PRIMARY
# 172.16.19.112:27017: SECONDARY  
# 172.16.19.113:27017: SECONDARY
```

---

## Bước 7: Create Users và Enable Authentication

### 7.1 Create Admin Users (trên PRIMARY, no auth)

**Trên mongo-primary (172.16.19.111):**

```bash
mongosh --host 172.16.19.111 --port 27017
```

**Trong MongoDB shell:**

```javascript
// Create root admin user
use admin
db.createUser({
  user: "admin",
  pwd: "YourSecurePassword123!",  // Change this!
  roles: [{role: "root", db: "admin"}]
})

// Create backup user
db.createUser({
  user: "backup", 
  pwd: "BackupPassword123!",
  roles: [
    {role: "backup", db: "admin"},
    {role: "restore", db: "admin"},
    {role: "readAnyDatabase", db: "admin"}
  ]
})

// Create monitoring user
db.createUser({
  user: "monitor",
  pwd: "MonitorPassword123!",
  roles: [
    {role: "clusterMonitor", db: "admin"},
    {role: "read", db: "local"}
  ]
})

// Verify users created
db.getUsers()

// Exit
exit
```

### 7.2 Enable Authentication trên All Nodes

**Trên cả 3 nodes:**

```bash
# Add security section to config
sudo tee -a /etc/mongod.conf > /dev/null <<EOF

# ========== SECURITY CONFIGURATION ==========
security:
  authorization: enabled
  keyFile: /etc/mongodb-keyfile
EOF

# Restart với authentication enabled
sudo systemctl restart mongod
sudo systemctl status mongod
```

### 7.3 Test Authentication

```bash
# Test admin connection
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr))"

# Test backup user
mongosh --host 172.16.19.111 --port 27017 \
  -u backup -p BackupPassword123! \
  --authenticationDatabase admin \
  --eval "db.runCommand('listDatabases')"

# Test monitoring user  
mongosh --host 172.16.19.111 --port 27017 \
  -u monitor -p MonitorPassword123! \
  --authenticationDatabase admin \
  --eval "db.serverStatus().connections"
```

---

## Bước 8: User Management và Permissions

### 8.1 Create Application Users

**Connect với admin user:**

```bash
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin
```

**Create different types of users:**

```javascript
// Read-only user cho specific database
use myapp
db.createUser({
  user: "readonly",
  pwd: "ReadOnlyPassword123!",
  roles: [
    { role: "read", db: "myapp" }
  ]
})

// Developer user - read/write but no admin
use myapp
db.createUser({
  user: "developer",
  pwd: "DevPassword123!",
  roles: [
    { role: "readWrite", db: "myapp" },
    { role: "dbAdmin", db: "myapp" }
  ]
})

// Application user cho production
use production_app
db.createUser({
  user: "appuser",
  pwd: "AppPassword123!",
  roles: [
    { role: "readWrite", db: "production_app" }
  ]
})

// Global read-only analyst
use admin
db.createUser({
  user: "analyst", 
  pwd: "AnalystPassword123!",
  roles: [
    { role: "readAnyDatabase", db: "admin" }
  ]
})
```

### 8.2 Test User Permissions

```bash
# Test read-only user
mongosh --host 172.16.19.111 --port 27017 \
  -u readonly -p ReadOnlyPassword123! \
  --authenticationDatabase myapp \
  --eval "
  use myapp;
  db.test.find().limit(5);
  // This should FAIL:
  try {
    db.test.insertOne({test: 'should fail'});
  } catch(e) {
    print('✅ Insert correctly blocked: ' + e.message);
  }
  "

# Test developer user
mongosh --host 172.16.19.111 --port 27017 \
  -u developer -p DevPassword123! \
  --authenticationDatabase myapp \
  --eval "
  use myapp;
  db.dev_test.insertOne({message: 'Dev can write', timestamp: new Date()});
  db.dev_test.createIndex({message: 1});
  print('✅ Developer can read/write in myapp');
  
  // This should FAIL:
  try {
    rs.status();
  } catch(e) {
    print('✅ Cluster operations correctly blocked: ' + e.message);
  }
  "
```

---

## Bước 9: Verification và Testing

### 9.1 Comprehensive Health Check

```bash
# Script để test tất cả functionality
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
print('🔍 MONGODB REPLICA SET HEALTH CHECK');
print('=====================================');

// Check replica set health
var status = rs.status();
print('Replica Set: ' + status.set);
print('Total Members: ' + status.members.length);
print('');

status.members.forEach(function(member) {
  print('Node: ' + member.name);
  print('  State: ' + member.stateStr);
  print('  Health: ' + member.health);
  print('  Uptime: ' + Math.round(member.uptime/60) + ' minutes');
  if (member.pingMs !== undefined) {
    print('  Ping: ' + member.pingMs + 'ms');
  }
  print('');
});

// Check database stats
print('📊 DATABASE STATISTICS:');
print('======================');
var dbStats = db.stats();
print('Collections: ' + dbStats.collections);
print('Data Size: ' + Math.round(dbStats.dataSize/1024/1024*100)/100 + ' MB');
print('Index Size: ' + Math.round(dbStats.indexSize/1024/1024*100)/100 + ' MB');
print('');

// Check server status
print('🖥️  SERVER STATUS:');
print('=================');
var serverStatus = db.serverStatus();
print('Version: ' + serverStatus.version);
print('Uptime: ' + Math.round(serverStatus.uptime/3600*100)/100 + ' hours');
print('Connections: ' + serverStatus.connections.current + '/' + serverStatus.connections.available);
print('');

// Check storage engine
var wiredTiger = serverStatus.wiredTiger;
if (wiredTiger) {
  var cache = wiredTiger.cache;
  print('Cache Size: ' + Math.round(cache['maximum bytes configured']/1024/1024/1024*100)/100 + ' GB');
  print('Cache Used: ' + Math.round(cache['bytes currently in the cache']/1024/1024/1024*100)/100 + ' GB');
}
"
```

### 9.2 Test Write Replication

```bash
# Write data on PRIMARY
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  use testdb;
  var testId = new Date().getTime();
  db.replication_test.insertOne({
    message: 'Testing replication',
    timestamp: new Date(),
    test_id: testId,
    primary_write: true
  });
  print('✅ Data written to PRIMARY with test_id: ' + testId);
  "

# Verify replication on SECONDARIES
for ip in 172.16.19.112 172.16.19.113; do
  echo "Checking replication on $ip..."
  mongosh --host $ip --port 27017 \
    -u admin -p YourSecurePassword123! \
    --authenticationDatabase admin \
    --eval "
    rs.secondaryOk();
    use testdb;
    var count = db.replication_test.countDocuments();
    print('✅ Secondary $ip has ' + count + ' documents');
    " --quiet
done
```

### 9.3 Test Automatic Failover

```bash
echo "🔥 TESTING AUTOMATIC FAILOVER..."

# Get current PRIMARY
PRIMARY=$(mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "print(rs.isMaster().primary)" --quiet)

echo "Current PRIMARY: $PRIMARY"

# Step down PRIMARY (simulate failure)
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "rs.stepDown(60)" --quiet

echo "⏳ Waiting for new PRIMARY election..."
sleep 20

# Check new PRIMARY từ secondary node
mongosh --host 172.16.19.112 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  var status = rs.status();
  status.members.forEach(function(member) {
    if (member.stateStr === 'PRIMARY') {
      print('✅ NEW PRIMARY: ' + member.name);
    }
  });
  " --quiet
```

### 9.4 Performance Testing

```bash
# Load testing
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
use testdb;
print('🚀 PERFORMANCE TESTING:');
print('=======================');

var startTime = new Date();

// Insert 1000 documents
for (var i = 0; i < 1000; i++) {
  db.load_test.insertOne({
    counter: i,
    data: 'Performance test document number ' + i,
    timestamp: new Date(),
    random: Math.random()
  });
}

var endTime = new Date();
var duration = endTime - startTime;

print('✅ Inserted 1000 documents in ' + duration + 'ms');
print('Average: ' + Math.round(duration/1000*100)/100 + 'ms per document');

// Test index creation và query performance
db.load_test.createIndex({counter: 1});
print('✅ Index created on counter field');

var queryStart = new Date();
var result = db.load_test.find({counter: 500}).explain('executionStats');
var queryEnd = new Date();

print('Query execution time: ' + result.executionStats.executionTimeMillis + 'ms');
print('Documents examined: ' + result.executionStats.totalDocsExamined);
print('Index used: ' + (result.executionStats.totalDocsExamined === 1 ? 'YES' : 'NO'));
"
```

---

## Production Usage

### Connection Strings

#### For Node.js Applications

```javascript
const { MongoClient } = require('mongodb');

// High availability connection với automatic failover
const connectionString = "mongodb://admin:YourSecurePassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/admin?replicaSet=replicaCfg&authSource=admin";

// Application-specific user
const appConnectionString = "mongodb://appuser:AppPassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/production_app?replicaSet=replicaCfg&readPreference=secondaryPreferred";

const client = new MongoClient(appConnectionString, {
  maxPoolSize: 50,
  minPoolSize: 5,
  maxIdleTimeMS: 30000,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000
});
```

#### For Different Users

```bash
# Admin connection (full access)
mongodb://admin:YourSecurePassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/admin?replicaSet=replicaCfg

# App user connection  
mongodb://appuser:AppPassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/production_app?replicaSet=replicaCfg

# Read-only connection (prefer secondaries)
mongodb://readonly:ReadOnlyPassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/myapp?replicaSet=replicaCfg&readPreference=secondaryPreferred

# Backup connection
mongodb://backup:BackupPassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/admin?replicaSet=replicaCfg
```

### Management Operations

#### Add/Remove Replica Set Members

```javascript
// Connect to PRIMARY as admin
mongosh --host 172.16.19.111 --port 27017 -u admin -p YourSecurePassword123! --authenticationDatabase admin

// Add new member
rs.add("172.16.19.114:27017")

// Add with specific configuration
rs.add({
  _id: 3,
  host: "172.16.19.114:27017",
  priority: 1,
  votes: 1
})

// Add hidden member (for backup/analytics)
rs.add({
  _id: 4,
  host: "172.16.19.115:27017", 
  priority: 0,
  votes: 0,
  hidden: true
})

// Remove member
rs.remove("172.16.19.114:27017")
```

#### Change Replica Set Configuration

```javascript
// Get current config
var config = rs.conf()

// Modify member priority
config.members[0].priority = 5  // Higher priority for preferred PRIMARY
config.version++

// Apply changes
rs.reconfig(config)

// Force immediate reconfiguration
rs.reconfig(config, {force: true})
```

---

## Monitoring và Maintenance

### Daily Health Checks

```bash
#!/bin/bash
# mongodb-health-check.sh

echo "=== MongoDB Health Check - $(date) ==="

# Check service status
for ip in 172.16.19.111 172.16.19.112 172.16.19.113; do
    echo "Checking $ip..."
    if mongosh --host $ip --port 27017 -u monitor -p MonitorPassword123! --authenticationDatabase admin --eval "db.runCommand('ping')" --quiet >/dev/null 2>&1; then
        echo "✅ $ip: MongoDB responding"
    else
        echo "❌ $ip: MongoDB not responding"
    fi
done

# Check replica set status
echo ""
echo "=== Replica Set Status ==="
mongosh --host 172.16.19.111 --port 27017 \
  -u monitor -p MonitorPassword123! \
  --authenticationDatabase admin \
  --eval "rs.status().members.forEach(m => print(m.name + ': ' + m.stateStr + ' (health: ' + m.health + ')'))" \
  --quiet

# Check disk usage
echo ""
echo "=== Disk Usage ==="
df -h | grep -E "(Filesystem|mongodb)"

# Check recent errors in logs
echo ""
echo "=== Recent Errors ==="
sudo grep -i error /logs/mongodb/mongod.log | tail -5
```

### Backup Strategies

#### LVM Snapshot Backup

```bash
#!/bin/bash
# lvm-snapshot-backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/mongodb"

echo "Creating LVM snapshot backup - $DATE"

# Create snapshot
sudo lvcreate -L5G -s -n mongodb-data-snap-$DATE /dev/ubuntu-vg/mongodb-data

# Mount snapshot
sudo mkdir -p /mnt/mongodb-snapshot
sudo mount /dev/ubuntu-vg/mongodb-data-snap-$DATE /mnt/mongodb-snapshot

# Create compressed backup
sudo tar -czf $BACKUP_DIR/lvm-backup-$DATE.tar.gz -C /mnt/mongodb-snapshot .

# Cleanup
sudo umount /mnt/mongodb-snapshot
sudo lvremove -y /dev/ubuntu-vg/mongodb-data-snap-$DATE

echo "✅ Backup completed: $BACKUP_DIR/lvm-backup-$DATE.tar.gz"
```

#### Logical Backup với mongodump

```bash
#!/bin/bash
# mongodump-backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/mongodb"

echo "Creating logical backup with mongodump - $DATE"

# Create backup directory
mkdir -p $BACKUP_DIR/dump-$DATE

# Backup all databases với authentication
mongodump --host 172.16.19.111:27017 \
  --username backup \
  --password BackupPassword123! \
  --authenticationDatabase admin \
  --oplog \
  --gzip \
  --out $BACKUP_DIR/dump-$DATE

# Compress backup
tar -czf $BACKUP_DIR/mongodump-$DATE.tar.gz -C $BACKUP_DIR dump-$DATE
rm -rf $BACKUP_DIR/dump-$DATE

# Keep only last 7 backups
find $BACKUP_DIR -name "mongodump-*.tar.gz" -mtime +7 -delete

echo "✅ Backup completed: $BACKUP_DIR/mongodump-$DATE.tar.gz"
```

### Performance Monitoring

```bash
# Monitor current operations
mongosh --host 172.16.19.111 --port 27017 \
  -u monitor -p MonitorPassword123! \
  --authenticationDatabase admin \
  --eval "
  print('Current Operations:');
  db.currentOp({'secs_running': {\$gte: 5}}).inprog.forEach(
    function(op) {
      print('Op: ' + op.op + ', Duration: ' + op.secs_running + 's, Query: ' + JSON.stringify(op.command));
    }
  );
  "

# Check index usage
mongosh --host 172.16.19.111 --port 27017 \
  -u monitor -p MonitorPassword123! \
  --authenticationDatabase admin \
  --eval "
  db.adminCommand('listCollections').cursor.firstBatch.forEach(
    function(collection) {
      if (collection.name.indexOf('system.') !== 0) {
        print('Collection: ' + collection.name);
        db[collection.name].aggregate([{\$indexStats: {}}]).forEach(
          function(index) {
            print('  Index: ' + index.name + ', Uses: ' + index.accesses.ops);
          }
        );
      }
    }
  );
  "

# Monitor replication lag
mongosh --host 172.16.19.111 --port 27017 \
  -u monitor -p MonitorPassword123! \
  --authenticationDatabase admin \
  --eval "
  print('Replication Lag Information:');
  rs.printSlaveReplicationInfo();
  "
```

---

## Troubleshooting Common Issues

### Connection Issues

```bash
# Debug connection problems
# 1. Check if service is running
sudo systemctl status mongod

# 2. Check port binding
sudo ss -tlnp | grep 27017

# 3. Check authentication
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "db.runCommand('ping')"

# 4. Check logs
sudo tail -f /logs/mongodb/mongod.log

# 5. Verify firewall
sudo ufw status
```

### Replica Set Issues

```bash
# Check replica set configuration
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  printjson(rs.conf());
  printjson(rs.status());
  "

# Force replica set reconfiguration
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  var config = rs.conf();
  config.version++;
  rs.reconfig(config, {force: true});
  "

# Re-sync lagging secondary
mongosh --host 172.16.19.112 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  rs.syncFrom('172.16.19.111:27017');
  "
```

### Performance Issues

```bash
# Check slow operations
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  db.setProfilingLevel(1, { slowms: 100 });
  db.system.profile.find().sort({ ts: -1 }).limit(5);
  "

# Check cache usage
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  var status = db.serverStatus();
  var cache = status.wiredTiger.cache;
  print('Cache utilization: ' + Math.round(cache['bytes currently in the cache'] / cache['maximum bytes configured'] * 100) + '%');
  "

# Check locks
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  db.currentOp({'$or': [{'waitingForLock': true}, {'msg': /lock/}]});
  "
```

---

## Security Best Practices

### Network Security

```bash
# Configure firewall
sudo ufw allow from 172.16.19.0/24 to any port 27017 comment 'MongoDB cluster'
sudo ufw allow ssh
sudo ufw enable

# Check firewall status
sudo ufw status verbose
```

### SSL/TLS Configuration (Optional)

```bash
# Generate self-signed certificate (for testing)
sudo openssl req -newkey rsa:2048 -new -x509 -days 3650 -nodes \
  -out /etc/ssl/mongodb.pem -keyout /etc/ssl/mongodb.pem \
  -subj "/C=VN/ST=HCM/L=HCM/O=MyCompany/CN=mongodb-cluster"

# Set permissions
sudo chown mongodb:mongodb /etc/ssl/mongodb.pem
sudo chmod 400 /etc/ssl/mongodb.pem

# Add to mongod.conf
echo "
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
" | sudo tee -a /etc/mongod.conf

# Restart MongoDB
sudo systemctl restart mongod

# Connect with SSL
mongosh --host 172.16.19.111 --port 27017 \
  --ssl --sslAllowInvalidCertificates \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin
```

### User Audit và Management

```bash
# List all users across databases
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  db.adminCommand('listDatabases').databases.forEach(
    function(database) {
      if (database.name !== 'local') {
        print('=== Database: ' + database.name + ' ===');
        var users = db.getSiblingDB(database.name).getUsers();
        users.users.forEach(function(user) {
          print('User: ' + user.user + ', Roles: ' + JSON.stringify(user.roles));
        });
      }
    }
  );
  "

# Rotate user passwords periodically
mongosh --host 172.16.19.111 --port 27017 \
  -u admin -p YourSecurePassword123! \
  --authenticationDatabase admin \
  --eval "
  use admin;
  db.changeUserPassword('backup', 'NewBackupPassword123!');
  print('✅ Backup user password updated');
  "
```

---

## Conclusion

### Final Cluster Status

**🎉 CONGRATULATIONS! Your MongoDB Replica Set is PRODUCTION READY! 🎉**

#### ✅ **What You Have:**
- **High Availability**: 3-node replica set with automatic failover
- **Performance**: LVM storage layout optimized for database workloads
- **Security**: Authentication, authorization, và inter-replica encryption
- **Monitoring**: Comprehensive health checks và performance monitoring
- **Backup**: Multiple backup strategies (LVM snapshots + logical backups)
- **User Management**: Role-based access control với different permission levels

#### 🔗 **Connection Information:**

```bash
# Admin Connection
mongodb://admin:YourSecurePassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/admin?replicaSet=replicaCfg

# Application Connection (recommended)
mongodb://appuser:AppPassword123!@172.16.19.111:27017,172.16.19.112:27017,172.16.19.113:27017/production_app?replicaSet=replicaCfg&readPreference=secondaryPreferred
```

#### 📋 **Important Files:**
- **Config**: `/etc/mongod.conf`
- **Logs**: `/logs/mongodb/mongod.log`
- **Data**: `/data/mongodb/`
- **Backup**: `/backup/mongodb/`
- **Keyfile**: `/etc/mongodb-keyfile`

#### 🎯 **Next Steps:**
1. **Setup monitoring** với Prometheus/Grafana
2. **Implement automated backups** với cron jobs
3. **Test disaster recovery** procedures
4. **Configure alerting** cho critical events
5. **Document runbooks** cho operations team

**Your MongoDB cluster is ready to handle production workloads!** 🚀

---

*Total setup time: ~2 hours | Tested on: Ubuntu 22.04 LTS | MongoDB 7.0.21* 