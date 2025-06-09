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
