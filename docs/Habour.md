# Hướng dẫn cài đặt và sử dụng Harbor Registry

## Giới thiệu

Harbor là một registry mã nguồn mở để lưu trữ và quản lý Docker images một cách bảo mật. Nó cung cấp các tính năng như quản lý user, access control, activity auditing, và replication giữa các instances. File này sẽ hướng dẫn chi tiết cách cài đặt, cấu hình và sử dụng Harbor registry trên Ubuntu/Linux.

## Cấu hình khuyến nghị

Để Harbor hoạt động ổn định, hệ thống cần đáp ứng các yêu cầu tối thiểu sau:

- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 250GB

## Bước 1: Cài đặt Docker và Docker Compose

Trước khi cài đặt Harbor, chúng ta cần cài đặt Docker và Docker Compose:

```bash
#!/bin/bash

sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce
sudo systemctl start docker
sudo systemctl enable docker
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker --version
docker-compose --version
```

## Bước 2: Cài đặt Certbot (để tạo SSL certificate)

Cài đặt certbot để tạo SSL certificate cho Harbor:

```bash
apt update -y
apt install certbot -y
```

## Bước 3: Tải xuống và giải nén Harbor

Tạo thư mục và tải xuống Harbor phiên bản mới nhất:

```bash
mkdir -p /tools/harbor && cd /tools/harbor
curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep '.tgz$' | wget -i -
tar xvzf harbor-offline-installer*.tgz
```

Sau khi giải nén, bạn sẽ thấy các file:
```
harbor/
harbor-offline-installer-v2.13.1.tgz
harbor-online-installer-v2.13.1.tgz
```

## Bước 4: Tạo SSL Certificate

Thiết lập biến môi trường và tạo SSL certificate:

```bash
export DOMAIN="registry.ngtantai.pro"
export EMAIL="tai21042004@gmail.com"

# Tạo thư mục lưu SSL certificate
sudo mkdir -p /etc/harbor/ssl

# Tạo private key
sudo openssl genrsa -out /etc/harbor/ssl/harbor.key 4096

# Tạo certificate signing request
sudo openssl req -new -key /etc/harbor/ssl/harbor.key -out /etc/harbor/ssl/harbor.csr -subj "/C=VN/ST=HCM/L=HCM/O=Harbor/CN=registry.ngtantai.pro"

# Tạo self-signed certificate
sudo openssl x509 -req -days 365 -in /etc/harbor/ssl/harbor.csr -signkey /etc/harbor/ssl/harbor.key -out /etc/harbor/ssl/harbor.crt

# Thiết lập quyền truy cập
sudo chmod 600 /etc/harbor/ssl/harbor.key
sudo chmod 644 /etc/harbor/ssl/harbor.crt
```

## Bước 5: Cấu hình Harbor

Chỉnh sửa file cấu hình `harbor.yml`:

```yaml
# Configuration file of Harbor
hostname: registry.ngtantai.pro

# http related config
http:
  # port for http, default is 80. If https enabled, this port will redirect to https port
  port: 80

# https related config
https:
  port: 443
  certificate: /etc/harbor/ssl/harbor.crt
  private_key: /etc/harbor/ssl/harbor.key

harbor_admin_password: 21042004

# Harbor DB configuration
database:
  password: 21042004
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

# The default data volume
data_volume: /data

trivy:
  ignore_unfixed: false
  skip_update: false
  skip_java_db_update: false
  offline_scan: false
  security_check: vuln
  insecure: false
  timeout: 5m0s

jobservice:
  max_job_workers: 10
  max_job_duration_hours: 24
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1 #days

notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3 #seconds

# Log configurations
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 2.13.0

proxy:
  http_proxy:
  https_proxy:
  no_proxy:
  components:
    - core
    - jobservice
    - trivy

# Enable purge _upload directories
upload_purging:
  enabled: true
  age: 168h
  interval: 24h
  dryrun: false

cache:
  # not enabled by default
  enabled: false
  # keep cache for one day by default
  expire_hours: 24
```

## Bước 6: Cài đặt và khởi chạy Harbor

Chuẩn bị cấu hình Harbor:

```bash
cd harbor
sudo ./prepare
```

Cài đặt Harbor (chạy với quyền sudo):

```bash
sudo ./install.sh
```

Quá trình cài đặt sẽ thực hiện các bước sau:
1. Kiểm tra Docker và Docker Compose
2. Load Harbor images
3. Chuẩn bị môi trường
4. Chuẩn bị cấu hình Harbor
5. Khởi chạy Harbor

Khi thành công, bạn sẽ thấy thông báo:
```
✔ ----Harbor has been installed and started successfully.----
```

## Truy cập Harbor

Sau khi cài đặt thành công, bạn có thể truy cập Harbor qua:

- **HTTPS**: `https://registry.ngtantai.pro`
- **HTTP**: `http://registry.ngtantai.pro` (sẽ redirect sang HTTPS)

**Thông tin đăng nhập mặc định:**
- Username: `admin`
- Password: `21042004`

## Kiểm tra trạng thái Harbor

Để kiểm tra trạng thái các container Harbor:

```bash
cd /tools/harbor/harbor
sudo docker-compose ps
```

## Quản lý Harbor

**Dừng Harbor:**
```bash
cd /tools/harbor/harbor
sudo docker-compose down
```

**Khởi động Harbor:**
```bash
cd /tools/harbor/harbor
sudo docker-compose up -d
```

**Xem logs:**
```bash
cd /tools/harbor/harbor
sudo docker-compose logs -f
```

## Cách Harbor hoạt động

### Kiến trúc Harbor

Harbor được xây dựng trên Docker Compose với các thành phần chính sau:

1. **Nginx (Proxy)**: Load balancer và reverse proxy
2. **Harbor Core**: Thành phần chính xử lý API và web UI
3. **Harbor Job Service**: Xử lý các công việc nền (replication, scanning, etc.)
4. **Registry**: Docker registry lưu trữ images
5. **Database (PostgreSQL)**: Lưu trữ metadata và cấu hình
6. **Redis**: Cache và message queue
7. **Harbor Log**: Thu thập logs từ các services

### Luồng hoạt động

1. **harbor.yml**: File cấu hình chính, định nghĩa certificate path và các thông số cơ bản
2. **Script prepare**: Generate nginx.conf và map certificate từ host vào container
3. **Container nginx**: Đọc certificate từ `/etc/cert/` bên trong container và xử lý HTTPS
4. **Harbor Core**: Xử lý authentication, authorization và API requests
5. **Registry**: Lưu trữ và phục vụ Docker images

### Certificate Mapping

Khi cấu hình SSL, Harbor sẽ mount certificate từ host vào container:

```
Host: /etc/harbor/ssl/harbor.crt  →  Container: /etc/cert/server.crt
Host: /etc/harbor/ssl/harbor.key  →  Container: /etc/cert/server.key
```

### Workflow khi Pull/Push Image

**Push Image:**
1. Docker client gửi request đến nginx proxy
2. Nginx forward request đến Harbor Core
3. Harbor Core xác thực user và project permissions
4. Request được chuyển đến Registry component
5. Image được lưu trong data volume `/data`

**Pull Image:**
1. Docker client request image từ Harbor
2. Harbor Core kiểm tra permissions
3. Registry serve image từ storage
4. Image được trả về cho client

### Cấu hình Data Persistence

Harbor lưu trữ dữ liệu trong các volume:
- **Registry data**: `/data/registry` - Chứa Docker images
- **Database data**: `/data/database` - PostgreSQL data
- **Redis data**: `/data/redis` - Cache data
- **Job logs**: `/var/log/harbor` - Service logs

## Troubleshooting thường gặp

**Lỗi SSL Certificate:**
```bash
# Kiểm tra certificate
sudo openssl x509 -in /etc/harbor/ssl/harbor.crt -text -noout

# Kiểm tra private key
sudo openssl rsa -in /etc/harbor/ssl/harbor.key -check
```

**Harbor không start:**
```bash
# Kiểm tra Docker
sudo systemctl status docker

# Kiểm tra ports
sudo netstat -tulpn | grep -E ':(80|443)\s'

# Restart Harbor
cd /tools/harbor/harbor
sudo docker-compose down
sudo docker-compose up -d
```

**Lỗi disk space:**
```bash
# Dọn dẹp Docker images không dùng
sudo docker system prune -a

# Kiểm tra disk usage
df -h /data
```