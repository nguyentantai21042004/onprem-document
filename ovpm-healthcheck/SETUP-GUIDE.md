# 🏥 OVPM Health Checker - Hướng dẫn Setup Chi tiết

## 📋 Prerequisites

- **OVPM Server**: Ubuntu 22.04 với OVPM đã cài đặt
- **IP Server**: 192.168.1.210 (như trong documentation)
- **Discord**: Server và webhook URL
- **SSH Access**: Root hoặc sudo access

---

## 🚀 Bước 1: Chuẩn bị Files

### **Trên máy local (macOS/Windows):**

```bash
# Di chuyển đến thư mục chứa files
cd /Users/tantai/Workspaces/server/server-build-docs

# Kiểm tra files có đầy đủ không
ls -la ovpm_health_checker.py requirements.txt setup.sh ovpm-health-checker.service

# Nén files để transfer
tar -czf ovpm-health-checker.tar.gz ovpm_health_checker.py requirements.txt setup.sh ovpm-health-checker.service README.md
```

### **Copy files lên OVPM server:**

```bash
# Method 1: SCP
scp ovpm-health-checker.tar.gz root@192.168.1.210:/root/

# Method 2: Copy từng file
scp ovpm_health_checker.py root@192.168.1.210:/root/
scp requirements.txt root@192.168.1.210:/root/
scp setup.sh root@192.168.1.210:/root/
scp ovpm-health-checker.service root@192.168.1.210:/root/
```

---

## 🖥️ Bước 2: SSH vào OVPM Server

```bash
# SSH vào server
ssh root@192.168.1.210

# Hoặc nếu dùng user khác:
ssh yourusername@192.168.1.210
sudo su -  # Switch to root
```

---

## 🐍 Bước 3: Cài đặt Python & Dependencies

### **Update system:**
```bash
apt update && apt upgrade -y
```

### **Cài đặt Python và tools:**
```bash
# Cài đặt Python 3 và pip
apt install -y python3 python3-pip python3-venv python3-dev

# Cài đặt system dependencies
apt install -y curl wget git build-essential

# Kiểm tra Python version
python3 --version
pip3 --version
```

### **Cài đặt system monitoring tools:**
```bash
# Tools cho monitoring
apt install -y htop net-tools netstat-nat
```

---

## 📦 Bước 4: Extract và Setup Files

### **Extract files (nếu đã nén):**
```bash
cd /root
tar -xzf ovpm-health-checker.tar.gz
ls -la ovpm_health_checker.py requirements.txt setup.sh ovpm-health-checker.service
```

### **Set permissions:**
```bash
chmod +x setup.sh
chmod +x ovpm_health_checker.py
```

---

## ⚙️ Bước 5: Chạy Setup Script

### **Kiểm tra OVPM trước khi setup:**
```bash
# Verify OVPM is installed
ovpm --version
ovpm vpn status

# Check if ovpmd service is running
systemctl status ovpmd
```

### **Chạy setup script:**
```bash
# Chạy automated setup
./setup.sh
```

**Output mong đợi:**
```
🏥 OVPM Health Checker Setup Script
====================================
✅ OVPM found
📦 Installing Python dependencies...
📁 Creating installation directory: /opt/ovpm-health-checker
📄 Copying health checker files...
🐍 Setting up Python virtual environment...
⚙️ Creating configuration file...
🔧 Installing systemd service...
✅ OVPM Health Checker installed successfully!
```

---

## 🔧 Bước 6: Configure Discord Webhook

### **Tạo Discord Webhook:**

1. **Vào Discord server** của bạn
2. **Server Settings** → **Integrations** → **Webhooks**
3. **Create Webhook**
4. **Copy Webhook URL** (dạng: `https://discord.com/api/webhooks/...`)

### **Edit configuration file:**
```bash
# Mở config file
nano /opt/ovpm-health-checker/ovpm_config.json
```

**Sửa 2 giá trị này:**
```json
{
    "discord_webhook": "https://discord.com/api/webhooks/YOUR_ACTUAL_WEBHOOK_URL",
    "ovpm_hostname": "vpn.yourdomain.com"
}
```

**Save file:** `Ctrl+X` → `Y` → `Enter`

---

## 🎯 Bước 7: Test Manual Run

### **Test script trước khi enable service:**
```bash
# Di chuyển đến thư mục
cd /opt/ovpm-health-checker

# Chạy manual test
./venv/bin/python3 ovpm_health_checker.py
```

**Output mong đợi:**
```
🏥 OVPM Health Checker Starting...
Running initial health check...
============================================================
Starting OVPM Health Check - 2024-01-15 14:30:15
============================================================
2024-01-15 14:30:15 [INFO] Checking ovpmd service status...
2024-01-15 14:30:16 [INFO] Checking OVPM VPN status...
2024-01-15 14:30:17 [INFO] Checking network connectivity...
2024-01-15 14:30:18 [INFO] Checking system resources...
2024-01-15 14:30:19 [INFO] 🔧 OVPMD Service Status:
2024-01-15 14:30:19 [INFO]    ✅ Running
2024-01-15 14:30:19 [INFO] 🌐 Network Status:
2024-01-15 14:30:19 [INFO]    ovpn_port: ✅ Listening
2024-01-15 14:30:19 [INFO]    web_ui: ✅ Responding (120ms)
2024-01-15 14:30:19 [INFO]    dns: ✅ Resolved to 192.168.1.210
2024-01-15 14:30:19 [INFO] 👥 VPN Status:
2024-01-15 14:30:19 [INFO]    Total Users: 3
2024-01-15 14:30:19 [INFO]    Active Connections: 0
2024-01-15 14:30:19 [INFO] 💻 System Resources:
2024-01-15 14:30:19 [INFO]    CPU: 15.3%
2024-01-15 14:30:19 [INFO]    Memory: 2.1GB/4GB (52%)
2024-01-15 14:30:19 [INFO]    Disk: 0.45GB/20GB (2.3%)
2024-01-15 14:30:19 [INFO]    Uptime: 7d 14h 23m
2024-01-15 14:30:20 [INFO] ✅ Discord notification sent successfully
2024-01-15 14:30:20 [INFO] Health check completed
```

**Nếu có lỗi Discord:**
```
2024-01-15 14:30:20 [WARNING] Discord webhook URL not configured
```
→ Kiểm tra lại Discord webhook URL trong config

---

## 🔄 Bước 8: Enable System Service

### **Enable và start service:**
```bash
# Enable auto-start
systemctl enable ovpm-health-checker

# Start service
systemctl start ovpm-health-checker

# Check status
systemctl status ovpm-health-checker
```

**Output mong đợi:**
```
● ovpm-health-checker.service - OVPM Health Checker Service
     Loaded: loaded (/etc/systemd/system/ovpm-health-checker.service; enabled)
     Active: active (running) since Mon 2024-01-15 14:30:21 UTC; 5s ago
   Main PID: 12345 (python3)
     Tasks: 1 (limit: 4915)
     Memory: 25.6M
        CPU: 1.234s
     CGroup: /system.slice/ovpm-health-checker.service
             └─12345 /opt/ovpm-health-checker/venv/bin/python3 /opt/ovpm-health-checker/ovpm_health_checker.py

Jan 15 14:30:21 vpn-server systemd[1]: Started OVPM Health Checker Service.
Jan 15 14:30:21 vpn-server python3[12345]: 🏥 OVPM Health Checker Starting...
Jan 15 14:30:21 vpn-server python3[12345]: Running initial health check...
Jan 15 14:30:22 vpn-server python3[12345]: ✅ Health checker is running. Press Ctrl+C to stop.
```

---

## 📊 Bước 9: Verify Operation

### **Check service logs:**
```bash
# Real-time logs
journalctl -u ovpm-health-checker -f

# Recent logs
journalctl -u ovpm-health-checker -n 50
```

### **Check health logs:**
```bash
# View health check logs
tail -f /var/log/ovpm_health.log

# Recent health logs
tail -n 20 /var/log/ovpm_health.log
```

### **Check Discord message:**
- Discord channel sẽ nhận được message đầu tiên
- Format: 🟢 OVPM Health Check - HEALTHY

---

## 🔍 Bước 10: Monitoring Commands

### **Service management:**
```bash
# Stop service
systemctl stop ovpm-health-checker

# Restart service
systemctl restart ovpm-health-checker

# Disable auto-start
systemctl disable ovpm-health-checker

# Check service status
systemctl status ovpm-health-checker
```

### **Manual testing:**
```bash
# One-time manual run
cd /opt/ovpm-health-checker
./venv/bin/python3 ovpm_health_checker.py

# Test with different config
./venv/bin/python3 ovpm_health_checker.py --config /path/to/custom/config.json
```

### **Log monitoring:**
```bash
# Health check logs
tail -f /var/log/ovpm_health.log

# System service logs
journalctl -u ovpm-health-checker -f

# OVPM service logs
journalctl -u ovpmd -f
```

---

## 🚨 Troubleshooting

### **Common Issues:**

#### **1. Service won't start:**
```bash
# Check service status
systemctl status ovpm-health-checker

# Check for Python errors
journalctl -u ovpm-health-checker -n 50

# Test Python environment
cd /opt/ovpm-health-checker
./venv/bin/python3 -c "import requests, psutil, schedule; print('All modules OK')"
```

#### **2. Discord notifications not working:**
```bash
# Test webhook manually
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message from OVPM server"}'

# Check config file
cat /opt/ovpm-health-checker/ovpm_config.json | grep discord_webhook
```

#### **3. OVPM commands fail:**
```bash
# Test OVPM manually
ovpm vpn status
ovpm user list

# Check ovpmd service
systemctl status ovpmd

# Check if user has permissions
which ovpm
ovpm --help
```

#### **4. Permission errors:**
```bash
# Check file permissions
ls -la /opt/ovpm-health-checker/
ls -la /var/log/ovpm_health.log

# Fix permissions if needed
chown -R root:root /opt/ovpm-health-checker/
chmod +x /opt/ovpm-health-checker/ovpm_health_checker.py
```

---

## ✅ Success Checklist

- [ ] Python 3 installed và working
- [ ] OVPM commands accessible
- [ ] Files copied và setup script executed
- [ ] Config file updated với Discord webhook
- [ ] Manual test run successful
- [ ] Discord message received
- [ ] Systemd service enabled và running
- [ ] Logs showing regular health checks
- [ ] Next hourly check scheduled

---

## 🎯 Next Steps

1. **Wait for hourly check** (sẽ chạy vào giờ tròn tiếp theo)
2. **Monitor Discord** cho regular status updates
3. **Check logs** để verify operation
4. **Test VPN connection** để trigger user activity monitoring
5. **Simulate issues** để test alerting (optional)

---

**🎉 Congratulations! OVPM Health Checker đã sẵn sàng monitor VPN server của bạn!** 