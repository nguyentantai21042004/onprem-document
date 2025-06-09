# Hướng dẫn Setup PostgreSQL + Repmgr

## Giới thiệu

File này hướng dẫn chi tiết cách thiết lập và cấu hình PostgreSQL kết hợp với Repmgr để tạo một hệ thống cơ sở dữ liệu có tính sẵn sàng cao (High Availability). 

Repmgr là một công cụ mã nguồn mở được thiết kế để đơn giản hóa việc quản lý và giám sát các cluster PostgreSQL replication. Với hướng dẫn này, bạn sẽ học cách:

- Cài đặt và cấu hình PostgreSQL
- Thiết lập Repmgr cho high availability
- Cấu hình replication giữa các node
- Giám sát và quản lý cluster
- Xử lý failover tự động

Hướng dẫn này phù hợp cho các DevOps engineer và database administrator muốn xây dựng một hệ thống database PostgreSQL ổn định và có khả năng phục hồi cao.

## Phase 1: Basic Setup (30-45 phút)

### Chuẩn bị môi trường

```bash
# Trên cả 2 máy (192.168.1.202 và 192.168.1.203)
sudo apt update && sudo apt upgrade -y

# Install PostgreSQL 14
sudo apt install postgresql postgresql-client postgresql-contrib -y

# Kiểm tra version
psql --version
# Output: psql (PostgreSQL) 14.x

# Check service status
sudo systemctl status postgresql
```

### Setup user và security

```bash
# Trên PRIMARY (192.168.1.202)
sudo -u postgres psql

-- Trong PostgreSQL console:
ALTER USER postgres PASSWORD 'your_strong_password';

-- Tạo replication user
CREATE USER repmgr WITH REPLICATION LOGIN SUPERUSER;
ALTER USER repmgr PASSWORD 'repmgr_password';

-- Tạo database cho repmgr
CREATE DATABASE repmgr OWNER repmgr;

-- Exit
\q
```

### Cấu hình network

```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/14/main/postgresql.conf

# Tìm và sửa những dòng này:
listen_addresses = '*'                    # Thay vì 'localhost'
port = 5432
max_connections = 100
wal_level = replica                       # Enable replication
max_wal_senders = 10                      # Số standby servers
max_replication_slots = 10
hot_standby = on                          # Enable read từ standby
```

```bash
# Edit pg_hba.conf để cho phép kết nối
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Thêm vào cuối file:
host    all             all             192.168.1.0/24         md5
host    replication     repmgr          192.168.1.0/24         md5
host    repmgr          repmgr          192.168.1.0/24         md5
```

```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Test kết nối từ máy khác
psql -h 192.168.1.202 -U postgres -d postgres
# Nhập password và test
```

## 🎯 Phase 2: Replication Setup (45-60 phút)

### Install Repmgr

```bash
# Trên cả 2 máy
sudo apt install postgresql-14-repmgr -y
```

### Cấu hình Repmgr trên PRIMARY

```bash
# Tạo config file cho repmgr
sudo nano /etc/repmgr.conf

# Nội dung file:
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

# Logging
log_level='INFO'
log_facility='STDERR'
log_file='/var/log/repmgr/repmgr.log'
```

```bash
# Tạo log directory
sudo mkdir -p /var/log/repmgr
sudo chown postgres:postgres /var/log/repmgr

# Set permissions
sudo chown postgres:postgres /etc/repmgr.conf
sudo chmod 640 /etc/repmgr.conf
```

### Register PRIMARY node

```bash
# Chạy với user postgres
sudo -u postgres repmgr -f /etc/repmgr.conf primary register

# Kiểm tra
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show
```

### Setup STANDBY server

```bash
# Trên máy STANDBY (192.168.1.203)
# Stop PostgreSQL service trước
sudo systemctl stop postgresql

# Tạo repmgr config
sudo nano /etc/repmgr.conf

# Nội dung (chú ý khác với primary):
node_id=2
node_name='standby1'
conninfo='host=192.168.1.203 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/14/main'
pg_bindir='/usr/lib/postgresql/14/bin'

replication_user='repmgr'
replication_type='physical'

failover='automatic'
promote_command='/usr/bin/repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='/usr/bin/repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'

log_level='INFO'
log_facility='STDERR'
log_file='/var/log/repmgr/repmgr.log'
```

```bash
# Set permissions
sudo mkdir -p /var/log/repmgr
sudo chown postgres:postgres /var/log/repmgr
sudo chown postgres:postgres /etc/repmgr.conf
sudo chmod 640 /etc/repmgr.conf

# Xóa data directory cũ và clone từ primary
sudo rm -rf /var/lib/postgresql/14/main/*

# Clone data từ primary
sudo -u postgres repmgr -h 192.168.1.202 -U repmgr -d repmgr -f /etc/repmgr.conf standby clone

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Register standby
sudo -u postgres repmgr -f /etc/repmgr.conf standby register
```

## 🎯 Phase 3: Management Tools Setup

```bash
# Install pgAdmin 4 trên một máy bất kỳ (có thể là primary)
sudo apt update

# Add pgAdmin repository
curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add
sudo sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

sudo apt update
sudo apt install pgadmin4-web -y

# Setup pgAdmin (tạo user admin)
sudo /usr/pgadmin4/bin/setup-web.sh

# Enable PostgreSQL service
sudo systemctl enable postgresql@14-main
```

