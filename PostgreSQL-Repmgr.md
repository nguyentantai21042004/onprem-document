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
