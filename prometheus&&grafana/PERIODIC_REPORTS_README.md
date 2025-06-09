# 📊 VM Health Periodic Reports Setup

Hướng dẫn thiết lập gửi báo cáo định kỳ về tình trạng VM lên Discord.

## 🎯 Tổng quan

Hệ thống này cung cấp **2 phương pháp** để gửi báo cáo định kỳ:

1. **Prometheus + Alertmanager** (Khuyến nghị) - Tích hợp với monitoring stack
2. **Python Script + Cron Job** - Standalone solution

## 🚀 Phương pháp 1: Prometheus + Alertmanager

### Cài đặt

1. **Restart monitoring stack để load cấu hình mới:**
   ```bash
   cd prometheus&&grafana
   docker-compose down
   docker-compose up -d
   ```

2. **Kiểm tra Prometheus rules đã load:**
   - Truy cập: http://localhost:9090/rules
   - Tìm: `health_metrics.rules` và `periodic_reports.rules`

3. **Kiểm tra Alertmanager config:**
   - Truy cập: http://localhost:9093

### Tính năng

- ✅ **Hourly Reports**: Mỗi giờ vào phút thứ 0-4
- ✅ **Daily Summary**: Mỗi ngày lúc 9:00 AM
- ✅ **Health Score**: Tính toán tự động từ CPU, Memory, Disk
- ✅ **Rich Metrics**: Uptime, network throughput, storage info

## 🐍 Phương pháp 2: Python Script

### Cài đặt nhanh

```bash
cd prometheus&&grafana
chmod +x setup_periodic_reports.sh
sudo ./setup_periodic_reports.sh
```

### Cài đặt thủ công

1. **Install dependencies:**
   ```bash
   pip3 install -r requirements.txt
   ```

2. **Test script:**
   ```bash
   python3 vm_health_reporter.py
   ```

3. **Setup cron job:**
   ```bash
   # Chỉnh sửa crontab
   crontab -e
   
   # Thêm dòng sau để gửi report mỗi giờ:
   0 * * * * cd /path/to/prometheus&&grafana && python3 vm_health_reporter.py
   ```

## ⚙️ Tùy chỉnh

### Thay đổi tần suất báo cáo

**Prometheus method:**
- Chỉnh sửa `prometheus/health_report_rules.yml`
- Thay đổi `minute() >= 0 and minute() <= 4` thành khoảng thời gian khác

**Python method:**
- Chỉnh sửa cron job:
```bash
# Mỗi 30 phút
0,30 * * * * cd /path/to/script && python3 vm_health_reporter.py

# Mỗi 15 phút
*/15 * * * * cd /path/to/script && python3 vm_health_reporter.py

# Chỉ vào buổi sáng (6-12h)
0 6-12 * * * cd /path/to/script && python3 vm_health_reporter.py
```

### Tùy chỉnh nội dung báo cáo

1. **Chỉnh sửa template trong Alertmanager** (`alertmanager/alertmanager.yml`)
2. **Hoặc chỉnh sửa Python script** (`vm_health_reporter.py`)

## 📋 Cấu trúc báo cáo

Mỗi báo cáo bao gồm:

- 🎯 **Health Score** (0-100%)
- 💻 **CPU Usage** + core count
- 🧠 **Memory Usage** + available/total
- 💾 **Disk Usage** + free space
- ⏱️ **System Uptime**
- 🌐 **Network Statistics**
- 📊 **Load Average** (Python only)

## 🔧 Troubleshooting

### Prometheus không gửi reports

1. **Kiểm tra rules:**
   ```bash
   curl http://localhost:9090/api/v1/rules
   ```

2. **Kiểm tra alerts:**
   ```bash
   curl http://localhost:9090/api/v1/alerts
   ```

3. **Kiểm tra Alertmanager:**
   ```bash
   curl http://localhost:9093/api/v1/alerts
   ```

### Python script không hoạt động

1. **Kiểm tra dependencies:**
   ```bash
   python3 -c "import psutil, requests; print('OK')"
   ```

2. **Kiểm tra permissions:**
   ```bash
   ls -la vm_health_reporter.py
   chmod +x vm_health_reporter.py
   ```

3. **Kiểm tra cron logs:**
   ```bash
   grep vm_health /var/log/syslog
   tail -f /var/log/vm_health_reports.log
   ```

### Discord webhook không hoạt động

1. **Test webhook URL:**
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d '{"content": "Test message"}'
   ```

2. **Kiểm tra rate limiting** (Discord có giới hạn 30 requests/minute)

## 📊 Ví dụ báo cáo

```
📊 Hourly VM Health Report - server-01

🟢 Overall Health: 87.5% (Good)

⏰ Report Time: 2024-01-15 14:00:00

📊 System Metrics:
• CPU Usage: 25.3% (4 cores)
• Memory Usage: 68.2% (2.1GB free / 8.0GB total)
• Disk Usage: 45.7% (28.5GB free / 50.0GB total)

⚡ Performance:
• Load Average: 0.85, 0.92, 1.05
• Uptime: 5d 14h 23m

🌐 Network:
• Sent: 1.2 GB
• Received: 856.7 MB
```

## 📝 Notes

- Báo cáo được gửi cùng Discord webhook với alerts khác
- Health score được tính dựa trên trọng số: CPU (40%), Memory (40%), Disk (20%)
- Prometheus method tích hợp tốt hơn với monitoring stack hiện tại
- Python method linh hoạt hơn và có thể chạy độc lập

## 🔄 Updates

Để cập nhật cấu hình:
1. Chỉnh sửa files cấu hình
2. Restart Docker services: `docker-compose restart`
3. Hoặc reload Prometheus: `curl -X POST http://localhost:9090/-/reload` 