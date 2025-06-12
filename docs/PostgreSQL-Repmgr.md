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

### Truy cập pgAdmin 4 Web Interface

```bash
# Kiểm tra pgAdmin 4 đang chạy ở port nào
sudo ss -tlnp | grep pgadmin
# hoặc
sudo netstat -tlnp | grep pgadmin

# Kiểm tra Apache status (pgAdmin thường chạy qua Apache)
sudo systemctl status apache2

# Kiểm tra port 80 (mặc định)
sudo ss -tlnp | grep :80
```

**Truy cập pgAdmin 4:**
- **URL mặc định:** `http://your-server-ip/pgadmin4`
- **Port:** 80 (HTTP) hoặc 443 (HTTPS nếu đã cấu hình SSL)

Ví dụ:
```
http://192.168.1.202/pgadmin4
```

### Troubleshooting

```bash
# Nếu không truy cập được, check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Restart Apache nếu cần
sudo systemctl restart apache2

# Check logs nếu có lỗi
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/pgadmin/pgadmin4.log
```

## 🎯 Phase 4: Connection Strategies và Testing

### Hiểu về vai trò của các node

**PRIMARY (192.168.1.202):**
- Xử lý tất cả các lệnh READ và WRITE
- Node chính để ứng dụng kết nối
- Đồng bộ dữ liệu sang STANDBY

**STANDBY (192.168.1.203):**
- Chỉ xử lý lệnh READ-only (nếu được cấu hình)
- Backup node tự động
- Sẽ promote lên PRIMARY khi node chính down

### 🔄 Chiến lược kết nối

#### 1. Kết nối cơ bản (Recommended cho bắt đầu)

```bash
# Chỉ kết nối với PRIMARY cho mọi thao tác
Connection String:
host=192.168.1.202 port=5432 dbname=your_db user=your_user password=your_pass

# Hoặc từ ứng dụng
psql -h 192.168.1.202 -U postgres -d postgres
```

**Ưu điểm:**
- Đơn giản, dễ cấu hình
- Tất cả READ/WRITE đều qua PRIMARY
- Không lo conflict

**Nhược điểm:**
- Không tận dụng được STANDBY để phân tải READ

#### 2. Read/Write Split (Advanced)

```bash
# Application config example
# WRITE operations -> PRIMARY
DATABASE_WRITE_URL=postgresql://user:pass@192.168.1.202:5432/dbname

# READ operations -> STANDBY (nếu cần phân tải)
DATABASE_READ_URL=postgresql://user:pass@192.168.1.203:5432/dbname
```

**Code example (Python):**
```python
import psycopg2

# Connection cho WRITE
write_conn = psycopg2.connect(
    host="192.168.1.202",
    database="your_db", 
    user="your_user",
    password="your_pass"
)

# Connection cho READ (optional)
read_conn = psycopg2.connect(
    host="192.168.1.203",
    database="your_db",
    user="your_user", 
    password="your_pass"
)
```

#### 3. Auto-Failover Connection (Production Ready)

```bash
# Multi-host connection string
host=192.168.1.202,192.168.1.203 port=5432 target_session_attrs=read-write dbname=your_db
```

**Hoặc với pgBouncer/Connection Pooling:**
```ini
# pgbouncer.ini
[databases]
your_db = host=192.168.1.202,192.168.1.203 port=5432 dbname=your_db

[pgbouncer]
listen_port = 6432
listen_addr = *
pool_mode = transaction
```

### 🧪 Testing Connections

```bash
# Test kết nối PRIMARY
psql -h 192.168.1.202 -U postgres -c "SELECT pg_is_in_recovery();"
# Kết quả: f (false = PRIMARY)

# Test kết nối STANDBY  
psql -h 192.168.1.203 -U postgres -c "SELECT pg_is_in_recovery();"
# Kết quả: t (true = STANDBY)

# Test replication lag
psql -h 192.168.1.202 -U postgres -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

# Test write trên PRIMARY
psql -h 192.168.1.202 -U postgres -c "CREATE TABLE test_write (id serial, created_at timestamp default now());"

# Test read trên STANDBY (sau vài giây)
psql -h 192.168.1.203 -U postgres -c "SELECT * FROM test_write;"
```

### 🚨 Failover Testing

```bash
# Simulate PRIMARY failure
sudo systemctl stop postgresql  # Trên PRIMARY (192.168.1.202)

# Check promotion trên STANDBY
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show

# STANDBY sẽ tự động promote lên PRIMARY
# Application với multi-host connection sẽ tự động chuyển sang node mới
```

### 📱 Application Configuration Examples

#### Node.js/Express
```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: '192.168.1.202,192.168.1.203',
  port: 5432,
  database: 'your_db',
  user: 'your_user',
  password: 'your_pass',
  target_session_attrs: 'read-write'
});
```

#### Django
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'host': '192.168.1.202,192.168.1.203',
            'port': '5432',
            'target_session_attrs': 'read-write',
        },
        'NAME': 'your_db',
        'USER': 'your_user',
        'PASSWORD': 'your_pass',
    }
}
```

### 💡 Best Practices

**Cho Development/Testing:**
- Kết nối trực tiếp với PRIMARY (192.168.1.202)
- Đơn giản và dễ debug

**Cho Production:**
- Sử dụng multi-host connection string
- Implement connection pooling (pgBouncer)
- Monitor replication lag
- Setup automated alerts

**Connection String Production:**
```
postgresql://user:pass@192.168.1.202:5432,192.168.1.203:5432/dbname?target_session_attrs=read-write&application_name=your_app
```

### 🔍 Monitoring Commands

```bash
# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr.conf cluster show

# Check replication status
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"

# Check lag time
sudo -u postgres psql -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) as lag_seconds;" # Trên STANDBY
```

