# MongoDB Replica Set Setup

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Installation Guide](#installation-guide)
- [Configuration](#configuration)
- [Replica Set Management](#replica-set-management)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Integration with Other Services](#integration-with-other-services)

---

## Introduction

MongoDB Replica Set is a group of MongoDB instances that maintain the same dataset, providing redundancy and high availability. This is the foundation for all production MongoDB deployments.

### What is a Replica Set?

A replica set is a group of MongoDB processes that maintain the same dataset. It consists of:

- **Primary Node**: Receives all write operations
- **Secondary Nodes**: Replicate data from the Primary
- **Arbiter** (optional): Participates in elections but doesn't store data

### Key Benefits

1. **High Availability**
   - Automatic failover when Primary fails
   - Applications can continue without interruption

2. **Data Redundancy**
   - Data replicated across multiple servers
   - Protection against hardware failures

3. **Read Scalability**
   - Read operations can be distributed to Secondary nodes
   - Improved performance for read-heavy workloads

4. **Disaster Recovery**
   - Automatic backup through replication
   - Point-in-time recovery capabilities

---

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 50GB SSD | 100GB+ SSD |
| **Network** | 1 Gbps | 1 Gbps |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS
- **MongoDB**: 7.0 or later
- **Network**: Static IP addresses for all nodes

### Network Configuration

| Node | IP Address | Role |
|------|------------|------|
| VM1 | 192.168.1.20 | Primary |
| VM2 | 192.168.1.21 | Secondary |
| VM3 | 192.168.1.22 | Secondary |

---

## Architecture Overview

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
│  │  • Operations log on Primary                           │ │
│  │  • Replicated to Secondaries                           │ │
│  │  • Maintains data consistency                          │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │    Applications       │
                    │                       │
                    │  • Write to Primary   │
                    │  • Read from Any Node │
                    │  • Auto-failover      │
                    └───────────────────────┘
```

---

## Installation Guide

### Step 1: System Preparation

Run on all three VMs:

```bash
#!/bin/bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget gnupg lsb-release ca-certificates

# Set timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Configure static IP (example for VM1)
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.20/24  # Change for each VM: .21, .22
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Apply network configuration
sudo netplan apply
```

### Step 2: MongoDB Installation

Create and run installation script on all VMs:

```bash
#!/bin/bash
# install-mongodb.sh
echo "Starting MongoDB installation..."

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

# Pin package versions
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections

# Create directories
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown mongodb:mongodb /var/lib/mongodb
sudo chown mongodb:mongodb /var/log/mongodb

# Enable service
sudo systemctl enable mongod

echo "MongoDB installation completed!"
```

### Step 3: MongoDB Configuration

Create configuration file `/etc/mongod.conf` (same on all VMs):

```yaml
# Storage configuration
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy

# System log configuration
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
  logLevel: 1

# Network configuration
net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 100
  compression:
    compressors: snappy

# Process management
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

# Security configuration
security:
  authorization: enabled
  keyFile: /etc/mongodb-keyfile

# Replication configuration
replication:
  replSetName: "learningRS"
  oplogSizeMB: 1024

# Operation profiling
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
```

### Step 4: Security Setup

Create keyfile for inter-replica authentication:

```bash
# Generate keyfile (run on PRIMARY only)
sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
sudo chmod 400 /tmp/mongodb-keyfile

# Copy to all nodes
scp /tmp/mongodb-keyfile admin@192.168.1.21:/tmp/
scp /tmp/mongodb-keyfile admin@192.168.1.22:/tmp/

# On each node:
sudo cp /tmp/mongodb-keyfile /etc/mongodb-keyfile
sudo chown mongodb:mongodb /etc/mongodb-keyfile
sudo chmod 400 /etc/mongodb-keyfile
```

---

## Configuration

### Step 1: Start MongoDB Services

Start MongoDB on all nodes:

```bash
# On all three VMs
sudo systemctl start mongod
sudo systemctl status mongod

# Check logs
sudo tail -f /var/log/mongodb/mongod.log
```

### Step 2: Initialize Replica Set

Connect to PRIMARY node and initialize:

```bash
# Connect to PRIMARY (192.168.1.20)
mongosh --host 192.168.1.20 --port 27017
```

Initialize replica set:

```javascript
// Initialize replica set
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

// Wait for initialization (30 seconds)
// Check status
rs.status()
```

### Step 3: Create Admin User

```javascript
// Create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "your_secure_password",
  roles: [
    { role: "root", db: "admin" }
  ]
})

// Create replication user
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

## Replica Set Management

### Monitoring Replica Set

```javascript
// Check replica set status
rs.status()

// Check replica set configuration
rs.conf()

// Check oplog status
rs.printReplicationInfo()

// Check member status
rs.isMaster()
```

### Adding a New Member

```javascript
// Add new member
rs.add("192.168.1.23:27017")

// Add with specific configuration
rs.add({
  _id: 3,
  host: "192.168.1.23:27017",
  priority: 0,
  hidden: true
})
```

### Removing a Member

```javascript
// Remove member
rs.remove("192.168.1.23:27017")

// Remove by ID
rs.remove("192.168.1.23:27017")
```

### Manual Failover

```javascript
// Step down primary (forces election)
rs.stepDown()

// Force reconfiguration
rs.reconfig(config, {force: true})
```

---

## Security Best Practices

### 1. Authentication

```javascript
// Enable authentication in mongod.conf
security:
  authorization: enabled

// Use strong passwords
use admin
db.createUser({
  user: "appuser",
  pwd: passwordPrompt(),
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})
```

### 2. Network Security

```bash
# Firewall configuration
sudo ufw allow from 192.168.1.0/24 to any port 27017
sudo ufw deny 27017

# Bind to specific interfaces
net:
  bindIp: 192.168.1.20,127.0.0.1
```

### 3. SSL/TLS Configuration

```yaml
# mongod.conf
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/ca.pem
```

---

## Monitoring and Maintenance

### 1. Metrics Collection

```javascript
// Database statistics
db.stats()

// Collection statistics
db.collection.stats()

// Server status
db.serverStatus()

// Replica set metrics
rs.status().members.forEach(member => {
  print(`${member.name}: ${member.stateStr}`)
})
```

### 2. Backup Strategy

```bash
#!/bin/bash
# backup-mongodb.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/mongodb"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup using mongodump
mongodump --host 192.168.1.20:27017 \
  --username admin \
  --password your_password \
  --authenticationDatabase admin \
  --out $BACKUP_DIR/backup_$DATE

# Compress backup
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz $BACKUP_DIR/backup_$DATE
rm -rf $BACKUP_DIR/backup_$DATE

# Remove old backups (keep last 7 days)
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
```

### 3. Health Checks

```bash
#!/bin/bash
# health-check.sh
NODES=("192.168.1.20" "192.168.1.21" "192.168.1.22")

for node in "${NODES[@]}"; do
  echo "Checking $node..."
  
  # Check if MongoDB is running
  if mongosh --host $node --port 27017 --eval "db.runCommand('ping')" --quiet; then
    echo "✓ $node is responding"
  else
    echo "✗ $node is not responding"
  fi
done

# Check replica set health
mongosh --host 192.168.1.20:27017 --eval "
  rs.status().members.forEach(function(member) {
    print(member.name + ': ' + member.stateStr + ' (health: ' + member.health + ')');
  })
"
```

---

## Troubleshooting

### Common Issues

#### 1. Node Not Joining Replica Set

```bash
# Check logs
sudo tail -f /var/log/mongodb/mongod.log

# Check network connectivity
telnet 192.168.1.20 27017

# Check DNS resolution
nslookup 192.168.1.20
```

#### 2. Authentication Failures

```javascript
// Check users
use admin
db.getUsers()

// Reset user password
db.changeUserPassword("username", "newpassword")
```

#### 3. Replica Lag

```javascript
// Check replication lag
rs.printSlaveReplicationInfo()

// Check oplog size
db.oplog.rs.stats()
```

### Performance Optimization

```javascript
// Check slow queries
db.setProfilingLevel(1, { slowms: 100 })
db.system.profile.find().sort({ ts: -1 }).limit(5)

// Index optimization
db.collection.createIndex({ field: 1 })
db.collection.getIndexes()
```

---

## Integration with Other Services

### 1. Application Connection

```javascript
// Connection string
const connectionString = "mongodb://admin:password@192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017/myapp?replicaSet=learningRS&authSource=admin";

// Node.js example
const { MongoClient } = require('mongodb');

const client = new MongoClient(connectionString, {
  maxPoolSize: 10,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
  readPreference: 'secondaryPreferred'
});
```

### 2. Monitoring Integration

```yaml
# prometheus.yml
- job_name: 'mongodb'
  static_configs:
    - targets: ['192.168.1.20:9216', '192.168.1.21:9216', '192.168.1.22:9216']
```

### 3. Backup Integration

```bash
# Integrate with backup service
#!/bin/bash
# Schedule with cron
# 0 2 * * * /opt/scripts/backup-mongodb.sh

# Upload to cloud storage
aws s3 cp /backup/mongodb/backup_latest.tar.gz s3://your-bucket/mongodb/
```

---

## Next Steps

After successful MongoDB setup:

1. **Configure Monitoring**: Set up Prometheus and Grafana for MongoDB metrics
2. **Implement Backup**: Schedule regular backups and test recovery
3. **Security Hardening**: Implement SSL/TLS and additional security measures
4. **Performance Tuning**: Optimize queries and indexes based on workload
5. **High Availability Testing**: Test failover scenarios

For more advanced topics, refer to:
- [Harbor Container Registry](container-registry.md)
- [Monitoring Setup](monitoring-setup.md)
- [VPN Server Configuration](vpn-server.md)

---

## Conclusion

This MongoDB Replica Set provides a robust, scalable database solution with high availability and data redundancy. The setup ensures your applications can handle failures gracefully while maintaining data consistency across all nodes.

For production deployments, consider additional features like sharding for horizontal scaling and advanced security configurations based on your specific requirements. 