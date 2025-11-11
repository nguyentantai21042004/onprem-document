# HƯỚNG DẪN TẠO DATABASE VÀ 4 USER LEVELS TRONG POSTGRESQL 18

## MỤC LỤC

1. [Tổng quan](#tổng-quan)
2. [Kiến trúc phân quyền](#kiến-trúc-phân-quyền)
3. [Chuẩn bị](#chuẩn-bị)
4. [Bước 1: Tạo Database](#bước-1-tạo-database)
5. [Bước 2: Tạo User Owner](#bước-2-tạo-user-owner)
6. [Bước 3: Tạo User API](#bước-3-tạo-user-api)
7. [Bước 4: Tạo User Dev](#bước-4-tạo-user-dev)
8. [Bước 5: Tạo User Readonly](#bước-5-tạo-user-readonly)
9. [Bước 6: Cấu hình pg_hba.conf](#bước-6-cấu-hình-pg_hbaconf)
10. [Bước 7: Testing](#bước-7-testing)
11. [Bước 8: Connection Strings](#bước-8-connection-strings)
12. [Troubleshooting](#troubleshooting)
13. [Security Best Practices](#security-best-practices)
14. [Backup và Maintenance](#backup-và-maintenance)

---

## TỔNG QUAN

Hướng dẫn này sẽ giúp bạn tạo một database PostgreSQL production-ready với 4 user levels khác nhau, mỗi user có quyền phù hợp với vai trò của họ.

**Database:** `smap`

**4 Users:**
- `smap_owner` - Quản lý database, chạy migrations
- `smap_api` - Dùng cho production API (quyền hạn chế)
- `smap_dev` - Dùng cho developers (nhiều quyền hơn)
- `smap_readonly` - Chỉ đọc dữ liệu (reporting, analytics)

---

## KIẾN TRÚC PHÂN QUYỀN

```
┌─────────────────────────────────────────────────────┐
│            postgres (superuser)                      │
│              - Toàn quyền hệ thống                   │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐            ┌──────▼───────┐
│  smap_owner   │            │ Other DBs    │
│  - Owner DB    │            │              │
│  - Migrations  │            └──────────────┘
│  - DDL changes │
└───────┬────────┘
        │
    ┌───┴────┬────────┬──────────┐
    │        │        │          │
┌───▼──┐  ┌──▼──┐  ┌─▼───┐  ┌──▼────────┐
│ api  │  │ dev │  │ ro  │  │ Future... │
└──────┘  └─────┘  └─────┘  └───────────┘
```

---

## SO SÁNH QUYỀN CÁC USER

| Quyền | owner | api | dev | readonly |
|-------|:-----:|:---:|:---:|:--------:|
| SELECT |  |  |  |  |
| INSERT |  |  |  | ❌ |
| UPDATE |  |  |  | ❌ |
| DELETE |  |  |  | ❌ |
| TRUNCATE |  | ❌ |  | ❌ |
| CREATE TABLE |  | ❌ |  | ❌ |
| DROP TABLE |  | ❌ |  | ❌ |
| ALTER TABLE |  | ❌ |  | ❌ |
| CREATE INDEX |  | ❌ |  | ❌ |
| CREATE/DROP DB | * | ❌ | ❌ | ❌ |
| Max Connections | 10 | 100 | 30 | 50 |
| **Use Case** | Migration | Prod API | Dev/Test | Reports |

*Owner có thể xóa database nếu có attribute CREATEDB

---

## CHUẨN BỊ

### Yêu cầu hệ thống:
- Ubuntu Server (18.04+)
- PostgreSQL 18 đã cài đặt
- Quyền sudo/root
- Terminal access

### Kiểm tra PostgreSQL đã chạy:
```bash
sudo systemctl status postgresql
```

### Kết nối với superuser:
```bash
sudo -u postgres psql
```

---

## BƯỚC 1: TẠO DATABASE

### 1.1. Kết nối PostgreSQL với user postgres

```bash
sudo -u postgres psql
```

### 1.2. Tạo database mới

```sql
-- Tạo database với encoding UTF8
CREATE DATABASE smap 
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0
    CONNECTION LIMIT = -1;

-- Thêm comment cho database (tùy chọn)
COMMENT ON DATABASE smap IS 'Production database for smap application';
```

### 1.3. Kiểm tra database đã tạo

```sql
-- Liệt kê databases
\l smap

-- Hoặc query
SELECT datname, pg_encoding_to_char(encoding), datcollate, datctype 
FROM pg_database 
WHERE datname = 'smap';
```

**Kết quả mong đợi:**
```
  datname  | pg_encoding_to_char |   datcollate    |    datctype     
-----------+---------------------+-----------------+-----------------
 smap     | UTF8                | en_US.UTF-8     | en_US.UTF-8
```

### 1.4. Kết nối vào database mới

```sql
\c smap
```

**Checkpoint 1:** Database `smap` đã được tạo thành công

---

## BƯỚC 2: TẠO USER OWNER

### 2.1. Tạo role smap_owner

```sql
-- Đảm bảo đang ở postgres database
\c postgres

-- Tạo user owner
CREATE ROLE smap_owner WITH 
    LOGIN                           -- Cho phép đăng nhập
    PASSWORD 'smap_owner@21042004'
    NOSUPERUSER                     -- Không phải superuser
    CREATEDB                        -- Có thể tạo/xóa database
    NOCREATEROLE                    -- Không tạo role khác
    NOINHERIT                       -- Không kế thừa quyền
    NOREPLICATION                   -- Không phải replication user
    CONNECTION LIMIT 10;            -- Tối đa 10 connections

-- Thêm comment
COMMENT ON ROLE smap_owner IS 'Database owner - Use for migrations and schema changes only';
```

### 2.2. Đặt owner cho database

```sql
-- Chuyển ownership database sang smap_owner
ALTER DATABASE smap OWNER TO smap_owner;

-- Kiểm tra
\l smap
```

### 2.3. Cấp quyền đầy đủ trong database

```sql
-- Kết nối vào database smap
\c smap

-- Cấp ALL quyền trên schema public
GRANT ALL PRIVILEGES ON SCHEMA public TO smap_owner;

-- Cấp quyền trên tất cả objects hiện có
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO smap_owner;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO smap_owner;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO smap_owner;

-- Cấp quyền tự động cho objects mới tạo sau này
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT ALL PRIVILEGES ON TABLES TO smap_owner;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT ALL PRIVILEGES ON SEQUENCES TO smap_owner;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT ALL PRIVILEGES ON FUNCTIONS TO smap_owner;
```

### 2.4. Thu hồi quyền trên database khác

```sql
\c postgres

REVOKE ALL ON DATABASE postgres FROM smap_owner;
REVOKE CONNECT ON DATABASE template0 FROM smap_owner;
REVOKE CONNECT ON DATABASE template1 FROM smap_owner;

\c postgres
REVOKE ALL ON SCHEMA public FROM smap_owner;

\c template1
REVOKE ALL ON SCHEMA public FROM smap_owner;

\c postgres
```

### 2.5. Kiểm tra user owner

```sql
-- Xem thông tin role
\du smap_owner

-- Kết quả mong đợi:
--   Role name    |  Attributes  | Member of 
-- ---------------+--------------+-----------
--  smap_owner   | Create DB   +| {}
--                | 10 connections|
```

**Checkpoint 2:** User `smap_owner` đã được tạo với đầy đủ quyền trên database `smap`

---

## BƯỚC 3: TẠO USER API

### 3.1. Tạo role smap_api

```sql
-- Kết nối postgres database
\c postgres

-- Tạo user cho production API
CREATE ROLE smap_api WITH 
    LOGIN 
    PASSWORD 'smap_api@2025'
    NOSUPERUSER 
    NOCREATEDB                    -- KHÔNG được tạo database
    NOCREATEROLE 
    NOINHERIT 
    NOREPLICATION 
    CONNECTION LIMIT 100;         -- API cần nhiều connections

COMMENT ON ROLE smap_api IS 'Production API user - Limited to CRUD operations only';
```

### 3.2. Cấp quyền CONNECT vào database

```sql
-- Cho phép kết nối vào smap
GRANT CONNECT ON DATABASE smap TO smap_api;

-- Thu hồi quyền vào database khác
REVOKE ALL ON DATABASE postgres FROM smap_api;
REVOKE CONNECT ON DATABASE template0 FROM smap_api;
REVOKE CONNECT ON DATABASE template1 FROM smap_api;
```

### 3.3. Cấp quyền USAGE trên schema

```sql
-- Kết nối vào smap
\c smap

-- Cấp quyền USAGE (cần thiết để truy cập objects)
GRANT USAGE ON SCHEMA public TO smap_api;
```

### 3.4. Cấp quyền CRUD only (KHÔNG có DDL)

```sql
-- CHỈ cho phép SELECT, INSERT, UPDATE, DELETE
-- KHÔNG cho phép CREATE, DROP, ALTER, TRUNCATE
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO smap_api;

-- Cấp quyền trên sequences (cần cho auto-increment)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO smap_api;

-- Cấp quyền EXECUTE trên functions (nếu có stored procedures)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO smap_api;
```

### 3.5. Cấu hình quyền cho objects mới

```sql
-- Khi smap_owner tạo table mới, tự động grant cho smap_api
ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smap_api;

ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT USAGE, SELECT ON SEQUENCES TO smap_api;

ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT EXECUTE ON FUNCTIONS TO smap_api;
```

### 3.6. Kiểm tra quyền của smap_api

```sql
-- Kiểm tra role attributes
\du smap_api

-- Kiểm tra quyền trên schema
\dn+ public

-- Xem default privileges
\ddp
```

**Checkpoint 3:** User `smap_api` có quyền CRUD nhưng không thể thay đổi schema

---

## BƯỚC 4: TẠO USER DEV

### 4.1. Tạo role smap_dev

```sql
-- Kết nối postgres database
\c postgres

-- Tạo user cho developers
CREATE ROLE smap_dev WITH 
    LOGIN 
    PASSWORD 'smap_dev@2025'
    NOSUPERUSER 
    NOCREATEDB                     -- KHÔNG được tạo database
    NOCREATEROLE 
    NOINHERIT 
    NOREPLICATION 
    CONNECTION LIMIT 30;           -- Dev cần ít connection hơn API

COMMENT ON ROLE smap_dev IS 'Developer user - Full access for testing and development';
```

### 4.2. Cấp quyền CONNECT

```sql
-- Cho phép kết nối vào smap
GRANT CONNECT ON DATABASE smap TO smap_dev;

-- Thu hồi quyền vào database khác
REVOKE ALL ON DATABASE postgres FROM smap_dev;
REVOKE CONNECT ON DATABASE template0 FROM smap_dev;
REVOKE CONNECT ON DATABASE template1 FROM smap_dev;
```

### 4.3. Cấp quyền đầy đủ (bao gồm DDL)

```sql
-- Kết nối vào smap
\c smap

-- Cấp ALL quyền trên schema
GRANT ALL PRIVILEGES ON SCHEMA public TO smap_dev;

-- Cấp ALL quyền trên tất cả objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO smap_dev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO smap_dev;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO smap_dev;

-- Tự động cho objects mới
ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT ALL PRIVILEGES ON TABLES TO smap_dev;

ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT ALL PRIVILEGES ON SEQUENCES TO smap_dev;

ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT ALL PRIVILEGES ON FUNCTIONS TO smap_dev;
```

### 4.4. Kiểm tra quyền của smap_dev

```sql
\du smap_dev

-- Dev có thể CREATE/DROP table nhưng KHÔNG thể xóa database
```

** Checkpoint 4:** User `smap_dev` có đầy đủ quyền để test và phát triển

---

## BƯỚC 5: TẠO USER READONLY

### 5.1. Tạo role smap_readonly

```sql
-- Kết nối postgres database
\c postgres

-- Tạo user readonly
CREATE ROLE smap_readonly WITH 
    LOGIN 
    PASSWORD 'smap_readonly@2025'
    NOSUPERUSER 
    NOCREATEDB 
    NOCREATEROLE 
    NOINHERIT 
    NOREPLICATION 
    CONNECTION LIMIT 50;              -- Cho reporting tools

COMMENT ON ROLE smap_readonly IS 'Read-only user for reporting and analytics';
```

### 5.2. Cấp quyền CONNECT

```sql
-- Cho phép kết nối vào smap
GRANT CONNECT ON DATABASE smap TO smap_readonly;

-- Thu hồi quyền vào database khác
REVOKE ALL ON DATABASE postgres FROM smap_readonly;
REVOKE CONNECT ON DATABASE template0 FROM smap_readonly;
REVOKE CONNECT ON DATABASE template1 FROM smap_readonly;
```

### 5.3. Cấp quyền SELECT only

```sql
-- Kết nối vào smap
\c smap

-- Cấp USAGE trên schema
GRANT USAGE ON SCHEMA public TO smap_readonly;

-- CHỈ cho phép SELECT
GRANT SELECT ON ALL TABLES IN SCHEMA public TO smap_readonly;

-- Cho phép xem sequences (nhưng không update)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO smap_readonly;

-- Tự động cho tables mới
ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT SELECT ON TABLES TO smap_readonly;

ALTER DEFAULT PRIVILEGES FOR ROLE smap_owner IN SCHEMA public 
    GRANT SELECT ON SEQUENCES TO smap_readonly;
```

### 5.4. Kiểm tra quyền của smap_readonly

```sql
\du smap_readonly

-- User này chỉ có thể SELECT, không INSERT/UPDATE/DELETE
```

**Checkpoint 5:** User `smap_readonly` chỉ có quyền đọc dữ liệu

---

## BƯỚC 6: CẤU HÌNH pg_hba.conf

### 6.1. Backup file config gốc

```bash
# Thoát khỏi psql
\q

# Backup config
sudo cp /etc/postgresql/18/main/pg_hba.conf /etc/postgresql/18/main/pg_hba.conf.backup.$(date +%Y%m%d_%H%M%S)

# Kiểm tra backup
ls -la /etc/postgresql/18/main/pg_hba.conf*
```

### 6.2. Chỉnh sửa pg_hba.conf

```bash
sudo nano /etc/postgresql/18/main/pg_hba.conf
```

### 6.3. Thêm rules cho tất cả users

**Tìm dòng:**
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
```

**Thêm NGAY SAU dòng này (đặt ở ĐẦU, trước các rule khác):**

```
# ==============================================================================
# DATABASE: smap - 4 USER LEVELS SECURITY CONFIGURATION
# ==============================================================================
# Rule priority: First match wins! Order matters!
# ==============================================================================

# -------------------------------
# 1. USER: smap_owner (Owner)
# -------------------------------
# Chỉ cho phép kết nối từ localhost và các subnet nội bộ được phép (192.168.1.0/24, 172.16.21.0/24)

local   smap           smap_owner                             md5
host    smap           smap_owner     127.0.0.1/32            md5
host    smap           smap_owner     ::1/128                 md5
host    smap           smap_owner     192.168.1.0/24          md5
host    smap           smap_owner     172.16.21.0/24          md5
# Từ chối owner kết nối từ mạng ngoài
host    smap           smap_owner     0.0.0.0/0               reject

# -------------------------------
# 2. USER: smap_api (Production API)
# -------------------------------
# Cho phép kết nối vào database smap từ localhost, 192.168.1.0/24 và 172.16.21.0/24 (có thể bổ sung subnet khác nếu cần)

local   smap           smap_api                               md5
host    smap           smap_api       127.0.0.1/32            md5
host    smap           smap_api       ::1/128                 md5
host    smap           smap_api       192.168.1.0/24          md5
host    smap           smap_api       172.16.21.0/24          md5
host    smap           smap_api       0.0.0.0/0               md5

# -------------------------------
# 3. USER: smap_dev (Developers)
# -------------------------------
# Cho phép kết nối vào database smap từ localhost, 192.168.1.0/24 và 172.16.21.0/24

local   smap           smap_dev                               md5
host    smap           smap_dev       127.0.0.1/32            md5
host    smap           smap_dev       ::1/128                 md5
host    smap           smap_dev       192.168.1.0/24          md5
host    smap           smap_dev       172.16.21.0/24          md5
host    smap           smap_dev       0.0.0.0/0               md5

# -------------------------------
# 4. USER: smap_readonly (Analytics)
# -------------------------------
# Cho phép kết nối vào database smap từ localhost, 192.168.1.0/24 và 172.16.21.0/24

local   smap           smap_readonly                          md5
host    smap           smap_readonly  127.0.0.1/32            md5
host    smap           smap_readonly  ::1/128                 md5
host    smap           smap_readonly  192.168.1.0/24          md5
host    smap           smap_readonly  172.16.21.0/24          md5
host    smap           smap_readonly  0.0.0.0/0               md5

# ==============================================================================
# SECURITY: TỪ CHỐI tất cả smap users kết nối vào database KHÁC
# ==============================================================================

local   all             smap_owner                             reject
local   all             smap_api                               reject
local   all             smap_dev                               reject
local   all             smap_readonly                          reject

host    all             smap_owner     0.0.0.0/0               reject
host    all             smap_api       0.0.0.0/0               reject
host    all             smap_dev       0.0.0.0/0               reject
host    all             smap_readonly  0.0.0.0/0               reject

# ==============================================================================
# SUPERUSER: postgres (Giữ nguyên)
# ==============================================================================

local   all             postgres                                peer
host    all             postgres        127.0.0.1/32            scram-sha-256
host    all             postgres        ::1/128                 scram-sha-256

# ==============================================================================
# OTHER USERS (Giữ nguyên các rules cũ nếu có)
# ==============================================================================

local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# ==============================================================================
# END OF smap CONFIGURATION
# ==============================================================================
```

### 6.4. Lưu file và kiểm tra syntax

```bash
# Lưu file: Ctrl + O, Enter, Ctrl + X

# Kiểm tra syntax
sudo /usr/lib/postgresql/18/bin/postgres --check-config -D /etc/postgresql/18/main/

# Xem file đã chỉnh sửa (bỏ comments và dòng trống)
sudo cat /etc/postgresql/18/main/pg_hba.conf | grep -v "^#" | grep -v "^$"
```

### 6.5. Reload PostgreSQL

```bash
# Cách 1: Reload config (không ngắt connections hiện tại)
sudo systemctl reload postgresql

# Cách 2: Restart (nếu reload không đủ)
sudo systemctl restart postgresql

# Kiểm tra service
sudo systemctl status postgresql
```

### 6.6. Kiểm tra PostgreSQL log

```bash
# Xem log để đảm bảo không có lỗi
sudo tail -50 /var/log/postgresql/postgresql-18-main.log
```

** Checkpoint 6:** pg_hba.conf đã được cấu hình đúng và PostgreSQL đã reload

---

## BƯỚC 7: TESTING

### 7.1. Test User: smap_owner

#### A. Test kết nối vào smap (phải OK)

```bash
psql -U smap_owner -h localhost -d smap
```

Nhập password: `Owner_SecureP@ss123!`

```sql
-- Kiểm tra database và user hiện tại
SELECT current_database(), current_user, session_user;

-- Liệt kê databases (chỉ thấy smap)
\l

-- Kết quả mong đợi: CHỈ thấy database 'smap' 

-- Test quyền tạo table
CREATE TABLE owner_test (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert data
INSERT INTO owner_test (name) VALUES ('Owner Test 1'), ('Owner Test 2');

-- Query
SELECT * FROM owner_test;

-- Test ALTER TABLE
ALTER TABLE owner_test ADD COLUMN description TEXT;

-- Test DROP TABLE
DROP TABLE owner_test;

-- Thoát
\q
```

**Kết quả mong đợi:**  Tất cả lệnh đều thành công

#### B. Test kết nối vào postgres (phải BỊ TỪ CHỐI)

```bash
psql -U smap_owner -h localhost -d postgres
```

**Kết quả mong đợi:**
```
psql: error: connection to server at "localhost" (127.0.0.1), port 5432 failed: 
FATAL: pg_hba.conf rejects connection for host "127.0.0.1", user "smap_owner", database "postgres"
```

 **ĐÚNG!** Owner bị chặn không vào được database khác

---

### 7.2. Test User: smap_api

```bash
psql -U smap_api -h localhost -d smap
```

Nhập password: `smap_api@2025`

```sql
-- Test SELECT (phải OK)
SELECT current_database(), current_user;
\l

-- Test INSERT (phải OK)
CREATE TABLE IF NOT EXISTS api_test (id SERIAL PRIMARY KEY, name VARCHAR(100));
-- ⚠ Nếu table chưa có, tạm dùng owner để tạo trước

INSERT INTO api_test (name) VALUES ('API Test 1');

-- Test UPDATE (phải OK)
UPDATE api_test SET name = 'API Test Updated' WHERE id = 1;

-- Test SELECT (phải OK)
SELECT * FROM api_test;

-- Test DELETE (phải OK)
DELETE FROM api_test WHERE id = 1;

-- ❌ Test CREATE TABLE (phải LỖI - không có quyền DDL)
CREATE TABLE api_should_fail (id INT);
-- Kết quả mong đợi: ERROR: permission denied for schema public

-- ❌ Test DROP TABLE (phải LỖI)
DROP TABLE api_test;
-- Kết quả mong đợi: ERROR: must be owner of table api_test

-- ❌ Test TRUNCATE (phải LỖI)
TRUNCATE api_test;
-- Kết quả mong đợi: ERROR: permission denied for table api_test

-- ❌ Test ALTER TABLE (phải LỖI)
ALTER TABLE api_test ADD COLUMN description TEXT;
-- Kết quả mong đợi: ERROR: must be owner of table api_test

\q
```

**Tóm tắt kết quả:**
-  SELECT, INSERT, UPDATE, DELETE: OK
- ❌ CREATE TABLE, DROP TABLE, TRUNCATE, ALTER TABLE: BỊ TỪ CHỐI

---

### 7.3. Test User: smap_dev

```bash
psql -U smap_dev -h localhost -d smap
```

Nhập password: `smap_dev@2025`

```sql
-- Test SELECT (phải OK)
SELECT current_database(), current_user;

-- Test CREATE TABLE (phải OK)
CREATE TABLE dev_test (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Test INSERT (phải OK)
INSERT INTO dev_test (name) VALUES ('Dev Test 1'), ('Dev Test 2');

-- Test UPDATE (phải OK)
UPDATE dev_test SET name = 'Dev Test Updated' WHERE id = 1;

-- Test SELECT (phải OK)
SELECT * FROM dev_test;

-- Test ALTER TABLE (phải OK)
ALTER TABLE dev_test ADD COLUMN description TEXT;

-- Test TRUNCATE (phải OK)
TRUNCATE dev_test;

-- Test DROP TABLE (phải OK)
DROP TABLE dev_test;

-- ❌ Test DROP DATABASE (phải LỖI - không có CREATEDB)
\c postgres
DROP DATABASE smap;
-- Kết quả mong đợi: ERROR: permission denied to drop database

\c smap
\q
```

**Tóm tắt kết quả:**
-  Tất cả CRUD và DDL operations: OK
- ❌ DROP DATABASE: BỊ TỪ CHỐI

---

### 7.4. Test User: smap_readonly

```bash
psql -U smap_readonly -h localhost -d smap
```

Nhập password: `smap_readonly@2025`

```sql
-- Test SELECT (phải OK)
SELECT current_database(), current_user;
\l

-- Test SELECT từ tables (phải OK)
SELECT * FROM users LIMIT 10;
-- Hoặc table nào đó bạn có

-- ❌ Test INSERT (phải LỖI)
INSERT INTO users (username) VALUES ('should_fail');
-- Kết quả mong đợi: ERROR: permission denied for table users

-- ❌ Test UPDATE (phải LỖI)
UPDATE users SET username = 'fail' WHERE id = 1;
-- Kết quả mong đợi: ERROR: permission denied for table users

-- ❌ Test DELETE (phải LỖI)
DELETE FROM users WHERE id = 1;
-- Kết quả mong đợi: ERROR: permission denied for table users

-- ❌ Test CREATE TABLE (phải LỖI)
CREATE TABLE readonly_fail (id INT);
-- Kết quả mong đợi: ERROR: permission denied for schema public

-- ❌ Test TRUNCATE (phải LỖI)
TRUNCATE users;
-- Kết quả mong đợi: ERROR: permission denied for table users

\q
```

**Tóm tắt kết quả:**
-  SELECT: OK
- ❌ INSERT, UPDATE, DELETE, CREATE, DROP, TRUNCATE: TẤT CẢ BỊ TỪ CHỐI

---

### 7.5. Test từ pgAdmin

1. Mở pgAdmin: `http://your_vm_ip/pgadmin4`

2. Tạo 4 server connections:

#### Connection 1: smap_owner
- Name: `smap - Owner`
- Host: `localhost`
- Port: `5432`
- Maintenance database: `smap`
- Username: `smap_owner`
- Password: `Owner_SecureP@ss123!`

#### Connection 2: smap_api
- Name: `smap - API`
- Host: `localhost`
- Port: `5432`
- Maintenance database: `smap`
- Username: `smap_api`
- Password: `smap_api@2025`

#### Connection 3: smap_dev
- Name: `smap - Dev`
- Host: `localhost`
- Port: `5432`
- Maintenance database: `smap`
- Username: `smap_dev`
- Password: `smap_dev@2025`

#### Connection 4: smap_readonly
- Name: `smap - Readonly`
- Host: `localhost`
- Port: `5432`
- Maintenance database: `smap`
- Username: `smap_readonly`
- Password: `smap_readonly@2025`

3. Kiểm tra từng connection:
   -  Tất cả đều kết nối thành công
   -  Trong cây Databases, CHỈ thấy `smap`
   -  KHÔNG thấy `postgres`, `template0`, `template1`

** Checkpoint 7:** Tất cả 4 users hoạt động đúng như thiết kế

---

## BƯỚC 8: CONNECTION STRINGS

### 8.1. Format chuẩn

```
postgresql://username:password@host:port/database
```

### 8.2. Connection strings cho từng user

#### Owner (Migrations only)
```bash
# Development/Local
DATABASE_URL="postgresql://smap_owner:Owner_SecureP@ss123!@localhost:5432/smap"

# Production (không nên expose ra ngoài)
DATABASE_URL="postgresql://smap_owner:Owner_SecureP@ss123!@10.0.1.5:5432/smap"
```

#### API (Production Application)
```bash
# Production
DATABASE_URL="postgresql://smap_api:smap_api@2025@10.0.1.5:5432/smap"

# Development
DATABASE_URL="postgresql://smap_api:smap_api@2025@localhost:5432/smap"

# Docker
DATABASE_URL="postgresql://smap_api:smap_api@2025@postgres:5432/smap"
```

#### Dev (Developers)
```bash
# Local development
DATABASE_URL="postgresql://smap_dev:smap_dev@2025@localhost:5432/smap"

# Dev server
DATABASE_URL="postgresql://smap_dev:smap_dev@2025@dev.example.com:5432/smap"
```

#### Readonly (Reporting/Analytics)
```bash
# Analytics tools
DATABASE_URL="postgresql://smap_readonly:smap_readonly@2025@10.0.1.5:5432/smap"

# BI tools
DATABASE_URL="postgresql://smap_readonly:smap_readonly@2025@localhost:5432/smap"
```

### 8.3. Connection strings cho frameworks

#### Node.js (Sequelize, Prisma, TypeORM)
```javascript
// Owner (migrations)
const ownerConfig = {
  host: 'localhost',
  port: 5432,
  database: 'smap',
  username: 'smap_owner',
  password: 'Owner_SecureP@ss123!',
  dialect: 'postgres'
};

// API (production)
const apiConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: 'smap',
  username: 'smap_api',
  password: process.env.DB_PASSWORD,
  dialect: 'postgres',
  pool: {
    max: 20,
    min: 5,
    acquire: 30000,
    idle: 10000
  }
};
```

#### Python (Django, SQLAlchemy)
```python
# settings.py (Django)

# Owner (migrations)
DATABASES_OWNER = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smap',
        'USER': 'smap_owner',
        'PASSWORD': 'Owner_SecureP@ss123!',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# API (production)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smap',
        'USER': 'smap_api',
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': '5432',
        'CONN_MAX_AGE': 600,
    }
}
```

#### Go
```go
// Owner (migrations)
ownerDSN := "host=localhost port=5432 user=smap_owner password=Owner_SecureP@ss123! dbname=smap sslmode=disable"

// API (production)
apiDSN := fmt.Sprintf(
    "host=%s port=5432 user=smap_api password=%s dbname=smap sslmode=require",
    os.Getenv("DB_HOST"),
    os.Getenv("DB_PASSWORD"),
)
```

#### Java (JDBC)
```java
// Owner (migrations)
String ownerUrl = "jdbc:postgresql://localhost:5432/smap";
Properties ownerProps = new Properties();
ownerProps.setProperty("user", "smap_owner");
ownerProps.setProperty("password", "Owner_SecureP@ss123!");

// API (production)
String apiUrl = "jdbc:postgresql://" + System.getenv("DB_HOST") + ":5432/smap";
Properties apiProps = new Properties();
apiProps.setProperty("user", "smap_api");
apiProps.setProperty("password", System.getenv("DB_PASSWORD"));
```

### 8.4. Best practices cho connection strings

#### Sử dụng biến môi trường

```bash
# .env file (KHÔNG commit vào git!)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smap
DB_USER=smap_api
DB_PASSWORD=smap_api@2025
```

#### Connection pooling

```javascript
// Node.js example
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,                 // Tối đa 20 connections
  min: 5,                  // Tối thiểu 5 connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

---

## TROUBLESHOOTING

### Vấn đề 1: Connection refused

**Triệu chứng:**
```
psql: error: connection to server at "localhost" (127.0.0.1), port 5432 failed: 
Connection refused
```

**Giải pháp:**
```bash
# Kiểm tra PostgreSQL có chạy không
sudo systemctl status postgresql

# Nếu không chạy, start service
sudo systemctl start postgresql

# Kiểm tra port đang listen
sudo ss -tulpn | grep 5432

# Kiểm tra postgresql.conf
sudo grep "listen_addresses" /etc/postgresql/18/main/postgresql.conf
# Phải là: listen_addresses = '*'
```

---

### Vấn đề 2: Password authentication failed

**Triệu chứng:**
```
psql: error: connection to server at "localhost" (127.0.0.1), port 5432 failed: 
FATAL: password authentication failed for user "smap_api"
```

**Giải pháp:**
```bash
# Reset password
sudo -u postgres psql
```

```sql
ALTER ROLE smap_api WITH PASSWORD 'NewPassword123!';
\q
```

```bash
# Reload PostgreSQL
sudo systemctl reload postgresql
```

---

### Vấn đề 3: Permission denied khi query

**Triệu chứng:**
```sql
SELECT * FROM users;
ERROR: permission denied for table users
```

**Giải pháp:**
```bash
sudo -u postgres psql -d smap
```

```sql
-- Kiểm tra owner của table
\dt+ users

-- Nếu owner không phải smap_owner, đổi owner
ALTER TABLE users OWNER TO smap_owner;

-- Cấp lại quyền cho các users khác
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO smap_api;
GRANT ALL PRIVILEGES ON users TO smap_dev;
GRANT SELECT ON users TO smap_readonly;

\q
```

---

### Vấn đề 4: pg_hba.conf rejects connection

**Triệu chứng:**
```
FATAL: pg_hba.conf rejects connection for host "192.168.1.50", user "smap_api", database "smap"
```

**Giải pháp:**
```bash
# Sửa pg_hba.conf để cho phép IP đó
sudo nano /etc/postgresql/18/main/pg_hba.conf
```

Thêm rule:
```
host    smap           smap_api       192.168.1.50/32         md5
```

```bash
# Reload
sudo systemctl reload postgresql

# Kiểm tra log
sudo tail -f /var/log/postgresql/postgresql-18-main.log
```

---

### Vấn đề 5: Vẫn thấy databases khác

**Triệu chứng:**
Khi chạy `\l`, vẫn thấy `postgres`, `template0`, `template1`

**Giải pháp:**
```bash
sudo -u postgres psql
```

```sql
-- Thu hồi CONNECT từ PUBLIC
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;
REVOKE CONNECT ON DATABASE template0 FROM PUBLIC;
REVOKE CONNECT ON DATABASE template1 FROM PUBLIC;

-- Thu hồi từ user cụ thể
REVOKE ALL ON DATABASE postgres FROM smap_api;
REVOKE ALL ON DATABASE postgres FROM smap_dev;
REVOKE ALL ON DATABASE postgres FROM smap_readonly;

\q
```

---

### Vấn đề 6: Cannot create table (for smap_dev)

**Triệu chứng:**
```sql
CREATE TABLE test (id INT);
ERROR: permission denied for schema public
```

**Giải pháp:**
```bash
sudo -u postgres psql -d smap
```

```sql
-- Cấp lại ALL quyền cho dev
GRANT ALL PRIVILEGES ON SCHEMA public TO smap_dev;

-- Kiểm tra
\dn+ public

\q
```

---

### Vấn đề 7: Max connections reached

**Triệu chứng:**
```
FATAL: remaining connection slots are reserved for non-replication superuser connections
```

**Giải pháp:**
```bash
# Kiểm tra connections hiện tại
sudo -u postgres psql
```

```sql
SELECT count(*) FROM pg_stat_activity;
SELECT usename, count(*) FROM pg_stat_activity GROUP BY usename;

-- Kill connections cũ
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'smap' 
  AND state = 'idle' 
  AND state_change < NOW() - INTERVAL '5 minutes';

\q
```

```bash
# Tăng max_connections (nếu cần)
sudo nano /etc/postgresql/18/main/postgresql.conf
```

Sửa:
```ini
max_connections = 200
```

```bash
sudo systemctl restart postgresql
```

---

## SECURITY BEST PRACTICES

### 1. Password Management

#### Sử dụng passwords mạnh
```bash
# Generate random password
openssl rand -base64 32

# Hoặc dùng pwgen
sudo apt install pwgen
pwgen -s 32 1
```

#### Lưu passwords an toàn
```bash
# Sử dụng environment variables
export smap_OWNER_PASS='...'
export smap_API_PASS='...'
export smap_DEV_PASS='...'
export smap_READONLY_PASS='...'

# Hoặc dùng secrets management
# - AWS Secrets Manager
# - HashiCorp Vault
# - Azure Key Vault
```

#### Đổi passwords định kỳ
```sql
-- Đổi password cho user
ALTER ROLE smap_api WITH PASSWORD 'NewSecurePassword!';
```

---

### 2. Network Security

#### Giới hạn IP trong pg_hba.conf
```
# KHÔNG làm thế này (quá mở)
host    smap           smap_api       0.0.0.0/0               md5

# Làm thế này (giới hạn IP cụ thể)
host    smap           smap_api       192.168.1.100/32        md5
host    smap           smap_api       10.0.1.0/24             md5
```

#### Bật SSL/TLS
```bash
# Enable SSL trong postgresql.conf
sudo nano /etc/postgresql/18/main/postgresql.conf
```

```ini
ssl = on
ssl_cert_file = '/etc/postgresql/18/main/server.crt'
ssl_key_file = '/etc/postgresql/18/main/server.key'
```

```bash
# Tạo self-signed certificate
sudo openssl req -new -x509 -days 365 -nodes -text \
  -out /etc/postgresql/18/main/server.crt \
  -keyout /etc/postgresql/18/main/server.key \
  -subj "/CN=postgres.yourdomain.com"

sudo chmod 600 /etc/postgresql/18/main/server.key
sudo chown postgres:postgres /etc/postgresql/18/main/server.*

# Restart
sudo systemctl restart postgresql
```

Trong pg_hba.conf, đổi `host` thành `hostssl`:
```
hostssl smap           smap_api       10.0.1.0/24             md5
```

---

### 3. Firewall Configuration

```bash
# Cài ufw
sudo apt install -y ufw

# Cho phép SSH (QUAN TRỌNG!)
sudo ufw allow 22/tcp

# Chỉ cho phép PostgreSQL từ subnet cụ thể
sudo ufw allow from 10.0.1.0/24 to any port 5432

# Hoặc từ IP cụ thể
sudo ufw allow from 192.168.1.100 to any port 5432

# Bật firewall
sudo ufw enable

# Kiểm tra
sudo ufw status verbose
```

---

### 4. Logging và Monitoring

#### Cấu hình logging
```bash
sudo nano /etc/postgresql/18/main/postgresql.conf
```

```ini
# Logging configuration
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000  # Log queries > 1s

# Log connections
log_connections = on
log_disconnections = on

# Log failed authentication
log_line_prefix = '%t [%p] %u@%d from %h '
```

```bash
sudo systemctl reload postgresql
```

#### Monitor failed login attempts
```bash
# Xem failed login attempts
sudo grep "password authentication failed" /var/log/postgresql/postgresql-18-main.log

# Xem connections từ IP lạ
sudo grep "connection authorized" /var/log/postgresql/postgresql-18-main.log | grep -v "127.0.0.1"
```

---

### 5. Regular Security Audits

#### Kiểm tra users và permissions
```sql
-- Liệt kê tất cả users
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole 
FROM pg_roles 
WHERE rolname NOT LIKE 'pg_%';

-- Kiểm tra connections
SELECT usename, application_name, client_addr, state, query_start 
FROM pg_stat_activity 
WHERE datname = 'smap';

-- Kiểm tra quyền trên tables
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_schema = 'public';
```

#### Remove unused users
```sql
-- Xóa user không dùng
DROP ROLE IF EXISTS old_user;
```

---

## BACKUP VÀ MAINTENANCE

### 1. Backup Database

#### Backup với pg_dump
```bash
# Backup toàn bộ database (dùng owner user)
pg_dump -U smap_owner -h localhost -d smap -F c -f smap_backup_$(date +%Y%m%d).backup

# Backup chỉ schema (không data)
pg_dump -U smap_owner -h localhost -d smap --schema-only -f smap_schema.sql

# Backup chỉ data
pg_dump -U smap_owner -h localhost -d smap --data-only -f smap_data.sql

# Backup một table cụ thể
pg_dump -U smap_owner -h localhost -d smap -t users -F c -f users_backup.backup
```

---

### 2. Restore Database

#### Restore từ backup
```bash
# Restore toàn bộ (dùng owner user)
pg_restore -U smap_owner -h localhost -d smap -v smap_backup_20250101.backup

# Restore với clean (xóa objects cũ trước)
pg_restore -U smap_owner -h localhost -d smap -c -v smap_backup.backup

# Restore chỉ một table
pg_restore -U smap_owner -h localhost -d smap -t users -v users_backup.backup
```

---

### 3. Automated Backup Script

```bash
# Tạo script backup tự động
sudo nano /usr/local/bin/backup-smap.sh
```

```bash
#!/bin/bash

# Configuration
BACKUP_DIR="/var/backups/postgresql/smap"
DB_NAME="smap"
DB_USER="smap_owner"
DB_HOST="localhost"
BACKUP_RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup filename with timestamp
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).backup"
LOG_FILE="$BACKUP_DIR/backup.log"

# Execute backup
echo "$(date): Starting backup of $DB_NAME..." >> "$LOG_FILE"

PGPASSWORD='Owner_SecureP@ss123!' pg_dump \
    -U "$DB_USER" \
    -h "$DB_HOST" \
    -d "$DB_NAME" \
    -F c \
    -f "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "$(date): Backup completed successfully - $BACKUP_FILE" >> "$LOG_FILE"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    
    # Delete old backups (older than retention days)
    find "$BACKUP_DIR" -name "${DB_NAME}_*.backup.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
    echo "$(date): Cleaned up old backups (retention: $BACKUP_RETENTION_DAYS days)" >> "$LOG_FILE"
else
    echo "$(date): Backup FAILED!" >> "$LOG_FILE"
    exit 1
fi
```

```bash
# Phân quyền
sudo chmod +x /usr/local/bin/backup-smap.sh

# Test script
sudo /usr/local/bin/backup-smap.sh
```

---

### 4. Setup Cronjob

```bash
# Edit crontab
sudo crontab -e
```

Thêm dòng (backup hàng ngày lúc 2:00 AM):
```
0 2 * * * /usr/local/bin/backup-smap.sh
```

Backup mỗi 6 giờ:
```
0 */6 * * * /usr/local/bin/backup-smap.sh
```

```bash
# Kiểm tra cronjobs
sudo crontab -l

# Xem log
sudo tail -f /var/backups/postgresql/smap/backup.log
```

---

### 5. Database Maintenance

#### VACUUM và ANALYZE
```bash
# Tạo script maintenance
sudo nano /usr/local/bin/maintain-smap.sh
```

```bash
#!/bin/bash

DB_NAME="smap"
DB_USER="smap_owner"
LOG_FILE="/var/log/postgresql/maintenance.log"

echo "$(date): Starting maintenance for $DB_NAME..." >> "$LOG_FILE"

# VACUUM ANALYZE (clean up và update statistics)
PGPASSWORD='Owner_SecureP@ss123!' psql \
    -U "$DB_USER" \
    -h localhost \
    -d "$DB_NAME" \
    -c "VACUUM ANALYZE;" >> "$LOG_FILE" 2>&1

# Reindex (nếu cần)
PGPASSWORD='Owner_SecureP@ss123!' psql \
    -U "$DB_USER" \
    -h localhost \
    -d "$DB_NAME" \
    -c "REINDEX DATABASE $DB_NAME;" >> "$LOG_FILE" 2>&1

echo "$(date): Maintenance completed" >> "$LOG_FILE"
```

```bash
sudo chmod +x /usr/local/bin/maintain-smap.sh

# Thêm vào crontab (chạy hàng tuần)
sudo crontab -e
```

```
0 3 * * 0 /usr/local/bin/maintain-smap.sh
```

---

## MONITORING

### 1. Kiểm tra Database Size

```sql
-- Kích thước database
SELECT pg_size_pretty(pg_database_size('smap'));

-- Kích thước từng table
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

### 2. Kiểm tra Connections

```sql
-- Số connections hiện tại
SELECT count(*) as total_connections FROM pg_stat_activity;

-- Connections theo user
SELECT usename, count(*) 
FROM pg_stat_activity 
GROUP BY usename;

-- Connections theo database
SELECT datname, count(*) 
FROM pg_stat_activity 
GROUP BY datname;

-- Kill idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
  AND state_change < NOW() - INTERVAL '30 minutes';
```

---

### 3. Slow Queries

```sql
-- Enable pg_stat_statements extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 slowest queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## FINAL CHECKLIST

- [ ] Database `smap` đã tạo thành công
- [ ] User `smap_owner` có full quyền, chỉ dùng cho migrations
- [ ] User `smap_api` có quyền CRUD, dùng cho production
- [ ] User `smap_dev` có quyền DDL, dùng cho developers
- [ ] User `smap_readonly` chỉ có quyền SELECT, dùng cho reporting
- [ ] pg_hba.conf đã cấu hình đúng với security rules
- [ ] PostgreSQL đã reload/restart
- [ ] Test tất cả 4 users thành công
- [ ] Connection strings đã chuẩn bị
- [ ] Passwords đã lưu an toàn (secrets manager/env vars)
- [ ] Firewall đã cấu hình (nếu cần)
- [ ] SSL/TLS đã enable (nếu production)
- [ ] Logging đã bật
- [ ] Backup script đã setup
- [ ] Cronjob backup tự động đã cấu hình
- [ ] Monitoring đã enable

---

## BEST PRACTICES SUMMARY

### DO
1. **Luôn dùng đúng user cho đúng mục đích**
   - Owner: migrations only
   - API: production app
   - Dev: development/testing
   - Readonly: analytics/reporting

2. **Bảo vệ passwords**
   - Dùng passwords mạnh (32+ characters)
   - Lưu trong secrets manager
   - Đổi định kỳ (3-6 tháng)
   - Không commit vào git

3. **Giới hạn network access**
   - Chỉ cho phép IPs cần thiết
   - Bật SSL/TLS cho production
   - Dùng firewall

4. **Backup thường xuyên**
   - Automated daily backups
   - Test restore định kỳ
   - Lưu backup offsite

5. **Monitor và audit**
   - Log connections và queries
   - Review permissions định kỳ
   - Monitor slow queries

### DON'T
1. **KHÔNG dùng owner user cho production app**
   - Owner có quá nhiều quyền
   - Rủi ro bảo mật cao

2. **KHÔNG hard-code passwords**
   - Luôn dùng environment variables
   - Không commit passwords vào git

3. **KHÔNG mở 0.0.0.0/0 cho production**
   - Luôn giới hạn IP cụ thể
   - Dùng VPN nếu cần remote access

4. **KHÔNG bỏ qua backups**
   - Data loss = disaster
   - Setup automated backups ngay

5. **KHÔNG share passwords giữa environments**
   - Dev, staging, production phải khác passwords
   - Mỗi developer nên có user riêng

---

## SUPPORT & UPDATES

### Cập nhật hướng dẫn này cho database khác

Để áp dụng cho database khác, chỉ cần thay đổi:
1. Tên database: `smap` → `your_db_name`
2. Tên users: `smap_*` → `yourapp_*`
3. Passwords
4. IP ranges trong pg_hba.conf

### Mở rộng

#### Thêm user mới (ví dụ: monitoring user)
```sql
CREATE ROLE smap_monitor WITH LOGIN PASSWORD 'Monitor_Pass!';
GRANT CONNECT ON DATABASE smap TO smap_monitor;
GRANT pg_monitor TO smap_monitor;
```

#### Tạo schema riêng cho từng module
```sql
CREATE SCHEMA auth AUTHORIZATION smap_owner;
CREATE SCHEMA billing AUTHORIZATION smap_owner;

GRANT USAGE ON SCHEMA auth TO smap_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO smap_api;
```

---

## HOÀN TẤT!

Bạn đã hoàn thành việc setup database PostgreSQL production-ready với 4 user levels và security best practices!

**Next steps:**
1. Deploy application với connection string phù hợp
2. Setup monitoring và alerting
3. Document access procedures cho team
4. Schedule regular security audits

**Happy coding!**

---

*Document version: 1.0*  
*Last updated: 2025-11-11*  
*PostgreSQL version: 18*