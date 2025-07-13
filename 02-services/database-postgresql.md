# PostgreSQL High Availability with Repmgr

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Installation and Setup](#installation-and-setup)
- [Repmgr Configuration](#repmgr-configuration)
- [Cluster Management](#cluster-management)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Integration with Other Services](#integration-with-other-services)

---

## Introduction

This guide provides comprehensive instructions for setting up PostgreSQL with Repmgr to create a highly available database cluster. Repmgr is an open-source tool designed to simplify administration and daily management of PostgreSQL replication clusters.

### What is Repmgr?

Repmgr is a suite of open-source tools for managing replication and failover in PostgreSQL clusters. It provides:

- **Cluster Management**: Easy setup and management of replication clusters
- **Automatic Failover**: Promotes standby servers when primary fails
- **Monitoring**: Comprehensive cluster health monitoring
- **Switchover**: Planned maintenance with minimal downtime
- **Witness Servers**: Quorum-based decision making for split-brain protection

### Key Benefits

1. **High Availability**
   - Automatic failover with minimal downtime
   - Seamless promotion of standby servers

2. **Data Protection**
   - Streaming replication for real-time backup
   - Point-in-time recovery capabilities

3. **Scalability**
   - Read replicas for load distribution
   - Easy addition of new nodes

4. **Management Simplicity**
   - Command-line tools for cluster operations
   - Comprehensive monitoring and alerting

---

## Prerequisites

### Hardware Requirements

| Component | Primary Node | Standby Node |
|-----------|-------------|-------------|
| **CPU** | 4 cores | 2 cores |
| **RAM** | 8GB | 4GB |
| **Storage** | 100GB SSD | 50GB SSD |
| **Network** | 1 Gbps | 1 Gbps |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS
- **PostgreSQL**: 14 or later
- **Repmgr**: 5.3 or later
- **Network**: Static IP addresses for all nodes

### Network Configuration

| Node | IP Address | Role |
|------|------------|------|
| Primary | 192.168.1.202 | Primary Database |
| Standby | 192.168.1.203 | Standby Database |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              PostgreSQL + Repmgr Cluster                   │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐       │
│  │    Primary Node      │    │    Standby Node      │       │
│  │  192.168.1.202:5432  │◄──►│  192.168.1.203:5432  │       │
│  │                      │    │                      │       │
│  │  ┌────────────────┐  │    │  ┌────────────────┐  │       │
│  │  │  PostgreSQL    │  │    │  │  PostgreSQL    │  │       │
│  │  │  (Primary)     │  │    │  │  (Standby)     │  │       │
│  │  └────────────────┘  │    │  └────────────────┘  │       │
│  │                      │    │                      │       │
│  │  ┌────────────────┐  │    │  ┌────────────────┐  │       │
│  │  │    Repmgr      │  │    │  │    Repmgr      │  │       │
│  │  │   (Master)     │  │    │  │   (Standby)    │  │       │
│  │  └────────────────┘  │    │  └────────────────┘  │       │
│  └──────────────────────┘    └──────────────────────┘       │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Streaming Replication                      │ │
│  │  • Real-time data synchronization                      │ │
│  │  • WAL (Write-Ahead Logging) streaming                 │ │
│  │  • Automatic failover capabilities                     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │     Applications      │
                    │                       │
                    │  • Write to Primary   │
                    │  • Read from Standby  │
                    │  • Auto-failover      │
                    └───────────────────────┘
```

---

## Installation and Setup

### Phase 1: Basic Setup (Primary Node)

#### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget gnupg lsb-release ca-certificates

# Set timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

#### Step 2: Configure Static IP

```bash
# Configure static IP for primary node
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.202/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Apply configuration
sudo netplan apply
```

#### Step 3: Install PostgreSQL

```bash
# Add PostgreSQL official APT repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Update package list
sudo apt update

# Install PostgreSQL 14
sudo apt install -y postgresql-14 postgresql-client-14 postgresql-contrib-14

# Check installation
sudo systemctl status postgresql
psql --version
```

#### Step 4: Initial PostgreSQL Configuration

```bash
# Switch to postgres user
sudo -u postgres psql

-- Set password for postgres user
ALTER USER postgres PASSWORD 'your_strong_password';

-- Create repmgr user
CREATE USER repmgr WITH REPLICATION LOGIN SUPERUSER;
ALTER USER repmgr PASSWORD 'repmgr_password';

-- Create repmgr database
CREATE DATABASE repmgr OWNER repmgr;

-- Exit PostgreSQL
\q
```

### Phase 2: Database Configuration

#### Step 1: Configure PostgreSQL

Edit `/etc/postgresql/14/main/postgresql.conf`:

```bash
sudo nano /etc/postgresql/14/main/postgresql.conf

# Find and modify these parameters:
listen_addresses = '*'
port = 5432
max_connections = 100

# Replication settings
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/14/main/archive/%f'

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 10MB
log_min_duration_statement = 1000

# Memory settings
shared_buffers = 2GB
effective_cache_size = 6GB
maintenance_work_mem = 256MB
work_mem = 16MB
```

#### Step 2: Configure pg_hba.conf

Edit `/etc/postgresql/14/main/pg_hba.conf`:

```bash
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add these lines at the end:
host    all             all             192.168.1.0/24         md5
host    replication     repmgr          192.168.1.0/24         md5
host    repmgr          repmgr          192.168.1.0/24         md5
```

#### Step 3: Create Archive Directory

```bash
# Create archive directory
sudo mkdir -p /var/lib/postgresql/14/main/archive
sudo chown postgres:postgres /var/lib/postgresql/14/main/archive
sudo chmod 700 /var/lib/postgresql/14/main/archive
```

#### Step 4: Restart PostgreSQL

```bash
# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl enable postgresql

# Test connection
psql -h 192.168.1.202 -U postgres -d postgres
```

---

## Repmgr Configuration

### Step 1: Install Repmgr

```bash
# Install repmgr
sudo apt install -y postgresql-14-repmgr

# Verify installation
repmgr --version
```

### Step 2: Configure Repmgr (Primary Node)

Create `/etc/repmgr.conf`:

```bash
sudo nano /etc/repmgr.conf

# Primary node configuration
node_id=1
node_name='primary'
conninfo='host=192.168.1.202 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/14/main'
pg_bindir='/usr/lib/postgresql/14/bin'

# Replication settings
replication_user='repmgr'
replication_type='physical'

# Failover settings
failover='automatic'
promote_command='/usr/bin/repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='/usr/bin/repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'

# Monitoring settings
monitoring_history=yes
monitor_interval_secs=2
reconnect_attempts=3
reconnect_interval=5

# Logging
log_level='INFO'
log_facility='STDERR'
log_file='/var/log/repmgr/repmgr.log'

# Service management
service_start_command='sudo systemctl start postgresql'
service_stop_command='sudo systemctl stop postgresql'
service_restart_command='sudo systemctl restart postgresql'
service_reload_command='sudo systemctl reload postgresql'
```

### Step 3: Setup Logging

```bash
# Create log directory
sudo mkdir -p /var/log/repmgr
sudo chown postgres:postgres /var/log/repmgr
sudo chmod 750 /var/log/repmgr

# Set permissions
sudo chown postgres:postgres /etc/repmgr.conf
sudo chmod 640 /etc/repmgr.conf
```

### Step 4: Register Primary Node

```bash
# Register primary node
sudo -u postgres repmgr -f /etc/repmgr.conf primary register

# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show
```

---

## Standby Node Setup

### Step 1: Prepare Standby Node

Repeat the system preparation steps on the standby node (192.168.1.203):

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Configure static IP (change IP to 192.168.1.203)
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.203/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Apply configuration
sudo netplan apply
```

### Step 2: Install PostgreSQL and Repmgr

```bash
# Install PostgreSQL and repmgr
sudo apt install -y postgresql-14 postgresql-client-14 postgresql-contrib-14 postgresql-14-repmgr

# Stop PostgreSQL (we'll clone from primary)
sudo systemctl stop postgresql
```

### Step 3: Configure Repmgr (Standby Node)

Create `/etc/repmgr.conf`:

```bash
sudo nano /etc/repmgr.conf

# Standby node configuration
node_id=2
node_name='standby1'
conninfo='host=192.168.1.203 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/14/main'
pg_bindir='/usr/lib/postgresql/14/bin'

# Replication settings
replication_user='repmgr'
replication_type='physical'

# Failover settings
failover='automatic'
promote_command='/usr/bin/repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='/usr/bin/repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'

# Monitoring settings
monitoring_history=yes
monitor_interval_secs=2
reconnect_attempts=3
reconnect_interval=5

# Logging
log_level='INFO'
log_facility='STDERR'
log_file='/var/log/repmgr/repmgr.log'

# Service management
service_start_command='sudo systemctl start postgresql'
service_stop_command='sudo systemctl stop postgresql'
service_restart_command='sudo systemctl restart postgresql'
service_reload_command='sudo systemctl reload postgresql'
```

### Step 4: Clone from Primary

```bash
# Setup logging
sudo mkdir -p /var/log/repmgr
sudo chown postgres:postgres /var/log/repmgr
sudo chmod 750 /var/log/repmgr

# Set permissions
sudo chown postgres:postgres /etc/repmgr.conf
sudo chmod 640 /etc/repmgr.conf

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/14/main/*

# Clone from primary
sudo -u postgres repmgr -h 192.168.1.202 -U repmgr -d repmgr -f /etc/repmgr.conf standby clone

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Register standby
sudo -u postgres repmgr -f /etc/repmgr.conf standby register
```

---

## Cluster Management

### Monitoring Cluster Status

```bash
# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show

# Check node status
sudo -u postgres repmgr -f /etc/repmgr.conf node status

# Check replication status
sudo -u postgres repmgr -f /etc/repmgr.conf node check
```

### Failover Operations

#### Manual Failover

```bash
# On standby node - promote to primary
sudo -u postgres repmgr -f /etc/repmgr.conf standby promote

# On old primary (after fixing) - follow new primary
sudo -u postgres repmgr -f /etc/repmgr.conf standby follow
```

#### Switchover (Planned Maintenance)

```bash
# On primary node - perform switchover
sudo -u postgres repmgr -f /etc/repmgr.conf standby switchover \
  --siblings-follow \
  --dry-run  # Remove --dry-run when ready

# Check cluster status after switchover
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show
```

---

## Monitoring and Maintenance

### Health Monitoring Script

```bash
#!/bin/bash
# postgresql-health-check.sh

NODES=("192.168.1.202" "192.168.1.203")
REPMGR_CONF="/etc/repmgr.conf"

echo "PostgreSQL Cluster Health Check - $(date)"
echo "================================================"

for node in "${NODES[@]}"; do
  echo "Checking node: $node"
  
  # Check PostgreSQL connectivity
  if psql -h $node -U postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo "✓ PostgreSQL is responding on $node"
  else
    echo "✗ PostgreSQL is not responding on $node"
  fi
  
  # Check replication status
  if ssh postgres@$node "repmgr -f $REPMGR_CONF node check" > /dev/null 2>&1; then
    echo "✓ Replication is healthy on $node"
  else
    echo "✗ Replication issues on $node"
  fi
  
  echo "---"
done

# Check cluster status
echo "Cluster Status:"
sudo -u postgres repmgr -f $REPMGR_CONF cluster show
```

### Backup Strategy

```bash
#!/bin/bash
# postgresql-backup.sh

BACKUP_DIR="/backup/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_HOST="192.168.1.202"
DB_USER="postgres"

# Create backup directory
mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -h $DB_HOST -U $DB_USER -d postgres > $BACKUP_DIR/postgres_$DATE.sql

# Backup all databases
pg_dumpall -h $DB_HOST -U $DB_USER > $BACKUP_DIR/all_databases_$DATE.sql

# Compress backups
gzip $BACKUP_DIR/*.sql

# Remove old backups (keep last 7 days)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### Performance Monitoring

```sql
-- Check active connections
SELECT datname, usename, state, client_addr
FROM pg_stat_activity
WHERE state = 'active';

-- Check replication lag
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;

-- Check database statistics
SELECT datname, numbackends, xact_commit, xact_rollback, blks_read, blks_hit
FROM pg_stat_database;

-- Check slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## Security Best Practices

### 1. Authentication and Authorization

```sql
-- Create application user with limited privileges
CREATE USER app_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE myapp TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;

-- Create read-only user for reporting
CREATE USER readonly_user WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE myapp TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
```

### 2. SSL/TLS Configuration

```bash
# Generate SSL certificates
sudo openssl req -new -x509 -days 365 -nodes -text \
  -out /etc/ssl/certs/server.crt \
  -keyout /etc/ssl/private/server.key \
  -subj "/CN=postgres"

# Set permissions
sudo chown postgres:postgres /etc/ssl/private/server.key
sudo chmod 600 /etc/ssl/private/server.key
```

Update `postgresql.conf`:

```bash
# SSL settings
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_prefer_server_ciphers = on
```

### 3. Network Security

```bash
# Configure firewall
sudo ufw allow from 192.168.1.0/24 to any port 5432
sudo ufw deny 5432

# Configure pg_hba.conf for SSL
hostssl all all 192.168.1.0/24 md5
```

---

## Troubleshooting

### Common Issues

#### 1. Replication Lag

```sql
-- Check replication lag
SELECT client_addr, state, 
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as lag_bytes
FROM pg_stat_replication;

-- Check WAL files
SELECT slot_name, active, restart_lsn
FROM pg_replication_slots;
```

#### 2. Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check listening ports
sudo netstat -tlnp | grep 5432

# Test connectivity
psql -h 192.168.1.202 -U postgres -c "SELECT 1"
```

#### 3. Repmgr Issues

```bash
# Check repmgr logs
sudo tail -f /var/log/repmgr/repmgr.log

# Verify repmgr configuration
sudo -u postgres repmgr -f /etc/repmgr.conf node check

# Re-register node if needed
sudo -u postgres repmgr -f /etc/repmgr.conf standby register --force
```

---

## Integration with Other Services

### 1. Application Integration

```python
# Python example with psycopg2
import psycopg2
from psycopg2 import pool

# Connection pool for high availability
connection_pool = psycopg2.pool.ThreadedConnectionPool(
    minconn=1,
    maxconn=20,
    host="192.168.1.202",
    port=5432,
    database="myapp",
    user="app_user",
    password="secure_password"
)

# Fallback to standby for read operations
def get_read_connection():
    try:
        return psycopg2.connect(
            host="192.168.1.203",
            port=5432,
            database="myapp",
            user="readonly_user",
            password="readonly_password"
        )
    except:
        return connection_pool.getconn()
```

### 2. Monitoring Integration

```yaml
# prometheus.yml
- job_name: 'postgresql'
  static_configs:
    - targets: ['192.168.1.202:9187', '192.168.1.203:9187']
```

### 3. Backup Integration

```bash
# Integrate with cloud backup
#!/bin/bash
# Upload backup to cloud storage
aws s3 cp /backup/postgresql/all_databases_latest.sql.gz \
  s3://your-bucket/postgresql/

# Schedule with cron
# 0 2 * * * /opt/scripts/postgresql-backup.sh
```

---

## Next Steps

After successful PostgreSQL setup:

1. **Configure Monitoring**: Set up PostgreSQL exporter for Prometheus
2. **Implement Automated Backup**: Schedule regular backups and test recovery
3. **Security Hardening**: Implement SSL/TLS and additional security measures
4. **Performance Tuning**: Optimize configuration based on workload
5. **High Availability Testing**: Test failover scenarios

For more advanced topics, refer to:
- [MongoDB Database Setup](database-mongodb.md)
- [Monitoring Setup](monitoring-setup.md)
- [Container Registry](container-registry.md)

---

## Conclusion

This PostgreSQL cluster with Repmgr provides a robust, highly available database solution with automatic failover capabilities. The configuration ensures minimal downtime and data protection while maintaining ease of management through Repmgr's comprehensive toolset.

Regular monitoring, maintenance, and testing of failover procedures are essential for maintaining a healthy and reliable database cluster in production environments. 