# ESXi VM Autostart & Systemd Service Automation

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Autostart VM trong ESXi](#autostart-vm-trong-esxi)
3. [Systemd Service cho Scripts](#systemd-service-cho-scripts)
4. [Templates và Examples](#templates-và-examples)
5. [Monitoring và Logging](#monitoring-và-logging)
6. [Best Practices](#best-practices)

## Giới thiệu

Sau khi Wake-on-LAN thành công, bước tiếp theo là đảm bảo các VM và services quan trọng tự động khởi động. Hướng dẫn này tập trung chi tiết vào việc **tạo systemd service** để tự động chạy các script .sh khi VM khởi động.

### 🎯 Mục tiêu

Khi bật server ESXi bằng Wake-on-LAN, cần đảm bảo:
1. **Các máy ảo quan trọng** được khởi động tự động trong ESXi
2. **Các script .sh bên trong VM** được thực thi tự động thông qua systemd services

---

## Autostart VM trong ESXi

### ✅ Thiết lập Autostart trong ESXi

#### Truy cập ESXi Web Interface:
```
https://<IP-server>
```

#### Navigation:
**Host → Manage → System → Autostart**

#### Cấu hình:
- ✅ **Enable Autostart**
- ✅ **Chọn VMs** cần tự động khởi động
- ⚙️ **Thiết lập delay** giữa các VM (khuyến nghị: 30-60 giây)

#### Advanced Configuration:
```bash
# SSH vào ESXi để cấu hình advanced
ssh root@esxi-ip

# Xem cấu hình autostart hiện tại
vim-cmd hostsvc/autostartmanager/get_autostartseq

# Enable autostart policy
vim-cmd hostsvc/autostartmanager/enable_autostart true

# Cấu hình autostart cho VM cụ thể
vim-cmd hostsvc/autostartmanager/update_autostartentry [vmid] PowerOn 120 systemDefault systemDefault
```

---

## Systemd Service cho Scripts

### 📁 Cấu trúc thư mục khuyến nghị

```bash
/usr/local/bin/                    # Nơi đặt scripts
├── start-services.sh             # Script chính
├── backup-service.sh             # Script backup
├── monitoring-service.sh         # Script monitoring
└── database-service.sh           # Script database

/etc/systemd/system/              # Nơi đặt service files
├── start-services.service        # Service file chính
├── backup-service.service        # Service backup
├── monitoring-service.service    # Service monitoring
└── database-service.service      # Service database
```

### 🛠️ Bước 1: Tạo Script .sh

#### 📄 Template cơ bản cho file .sh

```bash
sudo nano /usr/local/bin/start-services.sh
```

**Nội dung mẫu:**

```bash
#!/bin/bash

# =============================================================================
# Script: start-services.sh
# Description: Auto-start essential services on VM boot
# Author: Your Name
# Date: $(date +%Y-%m-%d)
# =============================================================================

# Set script variables
SCRIPT_NAME="start-services"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
PID_FILE="/var/run/${SCRIPT_NAME}.pid"

# Function: Write to log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${SCRIPT_NAME}] $1" | tee -a ${LOG_FILE}
}

# Function: Check if service is running
check_service() {
    if systemctl is-active --quiet $1; then
        log_message "✅ Service $1 is running"
        return 0
    else
        log_message "❌ Service $1 is not running"
        return 1
    fi
}

# Function: Start service with error handling
start_service() {
    log_message "🔄 Starting service: $1"
    if systemctl start $1; then
        log_message "✅ Successfully started: $1"
    else
        log_message "❌ Failed to start: $1"
        return 1
    fi
}

# Function: Wait for network
wait_for_network() {
    log_message "⏳ Waiting for network connectivity..."
    local timeout=30
    local count=0
    
    while ! ping -c 1 8.8.8.8 >/dev/null 2>&1; do
        if [ $count -ge $timeout ]; then
            log_message "❌ Network timeout after ${timeout}s"
            return 1
        fi
        sleep 1
        ((count++))
    done
    
    log_message "✅ Network is ready"
    return 0
}

# Main execution
main() {
    log_message "🚀 Starting ${SCRIPT_NAME} script"
    
    # Create PID file
    echo $$ > ${PID_FILE}
    
    # Wait for network to be ready
    if ! wait_for_network; then
        log_message "❌ Network not available, exiting"
        exit 1
    fi
    
    # Example: Start Docker containers
    if command -v docker &> /dev/null; then
        log_message "🐳 Starting Docker containers..."
        docker start vpn-server || log_message "❌ Failed to start vpn-server"
        docker start web-server || log_message "❌ Failed to start web-server"
        docker start database || log_message "❌ Failed to start database"
    fi
    
    # Example: Start specific services
    start_service "nginx"
    start_service "postgresql"
    start_service "redis"
    
    # Example: Run custom commands
    log_message "🔧 Running custom initialization..."
    
    # Mount network drives
    if [ -f "/etc/fstab" ]; then
        mount -a && log_message "✅ Network drives mounted" || log_message "❌ Failed to mount drives"
    fi
    
    # Start VPN if exists
    if [ -f "/usr/local/bin/start-vpn.sh" ]; then
        /usr/local/bin/start-vpn.sh && log_message "✅ VPN started" || log_message "❌ VPN failed"
    fi
    
    # Health check
    log_message "🔍 Performing health checks..."
    check_service "nginx"
    check_service "postgresql"
    
    # Cleanup
    rm -f ${PID_FILE}
    log_message "✅ ${SCRIPT_NAME} completed successfully"
}

# Error handling
error_exit() {
    log_message "💥 ERROR: $1"
    rm -f ${PID_FILE}
    exit 1
}

# Trap errors
trap 'error_exit "Script interrupted"' INT TERM

# Execute main function
main "$@"

exit 0
```

#### 🔒 Cấp quyền thực thi

```bash
sudo chmod +x /usr/local/bin/start-services.sh
```

#### 🧪 Test script thủ công

```bash
sudo /usr/local/bin/start-services.sh
```

### 🛠️ Bước 2: Tạo Systemd Service File

#### 📄 Template Service File

```bash
sudo nano /etc/systemd/system/start-services.service
```

**Nội dung service file:**

```ini
[Unit]
# ============================================================================
# Service: start-services.service
# Description: Auto-start essential services and scripts on VM boot
# ============================================================================

Description=Essential Services Startup Script
Documentation=man:systemd.service(5)
After=network.target network-online.target
Wants=network-online.target
RequiresMountsFor=/usr/local/bin

[Service]
# Service configuration
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=300
TimeoutStopSec=30

# User and environment
User=root
Group=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
WorkingDirectory=/usr/local/bin

# Execution
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/start-services.sh
ExecReload=/bin/kill -HUP $MAINPID

# Security settings
NoNewPrivileges=false
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/log /var/run /tmp

# Restart configuration
Restart=on-failure
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=start-services

[Install]
WantedBy=multi-user.target
```

### 🛠️ Bước 3: Kích hoạt và quản lý Service

#### 📝 Các lệnh quản lý service

```bash
# Reload systemd để nhận service mới
sudo systemctl daemon-reload

# Kích hoạt service để chạy khi boot
sudo systemctl enable start-services.service

# Khởi động service ngay lập tức
sudo systemctl start start-services.service

# Kiểm tra status
sudo systemctl status start-services.service

# Xem logs
sudo journalctl -u start-services.service -f

# Restart service
sudo systemctl restart start-services.service

# Disable service
sudo systemctl disable start-services.service
```

---

## Templates và Examples

### 📄 Database Service Template

```bash
# /usr/local/bin/database-service.sh
#!/bin/bash

SCRIPT_NAME="database-service"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${SCRIPT_NAME}] $1" | tee -a ${LOG_FILE}
}

main() {
    log_message "🚀 Starting database services"
    
    # Start MongoDB
    if systemctl is-enabled mongod &>/dev/null; then
        systemctl start mongod
        log_message "✅ MongoDB started"
    fi
    
    # Start PostgreSQL
    if systemctl is-enabled postgresql &>/dev/null; then
        systemctl start postgresql
        log_message "✅ PostgreSQL started"
    fi
    
    # Start Redis
    if systemctl is-enabled redis &>/dev/null; then
        systemctl start redis
        log_message "✅ Redis started"
    fi
    
    log_message "✅ Database services startup completed"
}

main "$@"
```

### 📄 Monitoring Service Template

```bash
# /usr/local/bin/monitoring-service.sh
#!/bin/bash

SCRIPT_NAME="monitoring-service"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${SCRIPT_NAME}] $1" | tee -a ${LOG_FILE}
}

main() {
    log_message "🚀 Starting monitoring services"
    
    # Start Prometheus
    if [ -d "/opt/prometheus" ]; then
        cd /opt/prometheus
        docker-compose up -d
        log_message "✅ Prometheus stack started"
    fi
    
    # Start Node Exporter
    if systemctl is-enabled node_exporter &>/dev/null; then
        systemctl start node_exporter
        log_message "✅ Node Exporter started"
    fi
    
    # Start Grafana
    if systemctl is-enabled grafana-server &>/dev/null; then
        systemctl start grafana-server
        log_message "✅ Grafana started"
    fi
    
    log_message "✅ Monitoring services startup completed"
}

main "$@"
```

### 📄 Backup Service Template

```bash
# /usr/local/bin/backup-service.sh
#!/bin/bash

SCRIPT_NAME="backup-service"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
BACKUP_DIR="/backup/$(date +%Y%m%d)"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${SCRIPT_NAME}] $1" | tee -a ${LOG_FILE}
}

main() {
    log_message "🚀 Starting backup services"
    
    # Create backup directory
    mkdir -p ${BACKUP_DIR}
    
    # Mount backup drives
    if [ -f "/etc/fstab" ]; then
        mount -a
        log_message "✅ Backup drives mounted"
    fi
    
    # Start backup scheduler
    if systemctl is-enabled backup-scheduler &>/dev/null; then
        systemctl start backup-scheduler
        log_message "✅ Backup scheduler started"
    fi
    
    log_message "✅ Backup services startup completed"
}

main "$@"
```

---

## Monitoring và Logging

### 📊 System Monitoring

#### Service Status Dashboard
```bash
# /usr/local/bin/service-status.sh
#!/bin/bash

echo "=== System Service Status ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo ""

services=("nginx" "postgresql" "redis" "docker" "mongod")

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: RUNNING"
    else
        echo "❌ $service: STOPPED"
    fi
done

echo ""
echo "=== Docker Containers ==="
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi
```

#### Log Rotation Configuration
```bash
# /etc/logrotate.d/custom-services
/var/log/start-services.log
/var/log/database-service.log
/var/log/monitoring-service.log
/var/log/backup-service.log
{
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
```

### 📈 Alerting

#### Discord Notification Function
```bash
# Function: Send Discord notification
send_discord_notification() {
    local message="$1"
    local webhook_url="YOUR_DISCORD_WEBHOOK_URL"
    
    if [ -n "$webhook_url" ]; then
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"content\":\"$message\"}" \
             "$webhook_url"
    fi
}

# Usage in scripts
send_discord_notification "🚀 Services started successfully on $(hostname)"
```

---

## Best Practices

### 🔒 Security Considerations

1. **Least Privilege**: Run services với minimum required permissions
2. **Secure Logging**: Protect log files từ unauthorized access
3. **Input Validation**: Validate all inputs trong scripts
4. **Error Handling**: Implement proper error handling
5. **Secrets Management**: Không hardcode credentials trong scripts

### 📈 Performance Optimization

1. **Parallel Execution**: Start independent services in parallel
2. **Resource Monitoring**: Monitor CPU, memory, disk usage
3. **Timeout Configuration**: Set appropriate timeouts
4. **Health Checks**: Implement proper health checks
5. **Graceful Shutdowns**: Handle shutdowns gracefully

### 🔄 Automation Best Practices

1. **Idempotency**: Scripts should be idempotent
2. **Logging**: Comprehensive logging cho debugging
3. **Testing**: Test scripts trong isolated environments
4. **Version Control**: Use git cho script management
5. **Documentation**: Document dependencies và configurations

---

## Troubleshooting

### Common Issues

#### 1. Service fails to start
```bash
# Check service status
sudo systemctl status start-services.service

# View detailed logs
sudo journalctl -u start-services.service -f

# Check script permissions
ls -la /usr/local/bin/start-services.sh
```

#### 2. Network dependency issues
```bash
# Test network connectivity
ping -c 1 8.8.8.8

# Check network service
sudo systemctl status network-online.target

# Restart networking
sudo systemctl restart systemd-networkd
```

#### 3. Permission errors
```bash
# Check file permissions
ls -la /usr/local/bin/
ls -la /etc/systemd/system/

# Fix permissions
sudo chmod +x /usr/local/bin/start-services.sh
sudo chown root:root /etc/systemd/system/start-services.service
```

---

## Next Steps

Sau khi hoàn thành ESXi VM Autostart setup, bạn có thể tiến tới:

1. **[Networking Configuration](networking.md)** - Advanced network setup
2. **[Port Forwarding](port-forwarding.md)** - Expose services ra internet
3. **[VPN Server Setup](../02-services/vpn-server.md)** - Secure remote access

---

## Tham khảo

- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [VMware ESXi Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [Linux Service Management](https://www.linux.com/training-tutorials/understanding-and-using-systemd/) 