# Wake On LAN - Bước đầu tiên trong hành trình DevOps

## Giới thiệu

Wake On LAN (WOL) là một trong những kỹ thuật cơ bản nhưng quan trọng khi bắt đầu học DevOps. Nó không chỉ giúp quản lý server từ xa mà còn mở ra nhiều khái niệm quan trọng trong việc quản lý hạ tầng.

### Tại sao Wake On LAN quan trọng?

**Automation Foundation**: WOL là bước đầu tiên để hiểu về remote control và automation - hai yếu tố cốt lõi của DevOps.

**Resource Management**: Học cách bật/tắt server từ xa giúp tối ưu hóa tài nguyên và chi phí vận hành.

**Network Understanding**: Việc cài đặt WOL đòi hỏi hiểu biết cơ bản về network protocols và infrastructure.

**Infrastructure as Code**: Scripts WOL là nền tảng đầu tiên cho việc quản lý infrastructure bằng code.

---

## PHẦN A: THIẾT LẬP TRÊN ESXi SERVER

### Bước 1: Kích hoạt Wake On LAN

#### 1.1 SSH vào ESXi và enable WOL:
```bash
ssh root@[IP_ESXi_server]

# Kích hoạt WOL cho network adapter chính
ethtool -s vmnic0 wol g

# Kiểm tra WOL đã được enable
ethtool vmnic0 | grep -i wake
# Kết quả mong đợi: Wake-on: g
```

#### 1.2 Cấu hình Power Management (khuyến nghị):
```bash
# Set High Performance mode để đảm bảo WOL ổn định
esxcli system settings advanced set -o /Power/CpuPolicy -s "High Performance"

# Kiểm tra cấu hình
esxcli system settings advanced list -o /Power/CpuPolicy
```

#### 1.3 Lưu MAC Address:
```bash
# Lấy MAC address của vmnic0
esxcli network nic list | grep vmnic0
```
**📝 Ghi nhớ MAC Address này** (ví dụ: `00:e0:25:30:50:7b`)

---

## PHẦN B: THIẾT LẬP CLIENT-SIDE AUTOMATION

### 🍎 macOS Setup (Recommended Approach)

#### B.1 Cài đặt công cụ cần thiết:
```bash
# Cài đặt wakeonlan
brew install wakeonlan
```

#### B.2 Thêm functions vào ~/.zshrc:

```bash
# Mở file cấu hình
nano ~/.zshrc

# Thêm phần này vào cuối file:
```

```bash
## Server Management Functions ##
alias ssh-server="ssh root@192.168.1.50"  # Thay IP của bạn

# Wake server với smart checking
wake-server() {
    SERVER_IP="192.168.1.50"              # Thay IP ESXi server của bạn
    SERVER_MAC="00:e0:25:30:50:7b"        # Thay MAC address của bạn

    echo "[INFO] Checking server status"
    if ping -c 1 -W 5 $SERVER_IP > /dev/null 2>&1; then
        echo "[INFO] Server is online"
        echo "[INFO] ESXi URL: https://$SERVER_IP"
    else
        echo "[WARN] Server is offline. Sending WOL packet"
        wakeonlan $SERVER_MAC
        echo "[INFO] WOL packet sent"
        echo "[INFO] Waiting for server startup"
        
        # Wait up to 60 seconds
        for i in {1..12}; do
            sleep 5
            if ping -c 1 -W 5 $SERVER_IP > /dev/null 2>&1; then
                echo "[INFO] Server online after $((i*5))s"
                echo "[INFO] ESXi URL: https://$SERVER_IP"
                return 0
            fi
            echo "[INFO] Waiting... ($((i*5))s elapsed)"
        done
        echo "[WARN] Timeout reached. Check https://$SERVER_IP manually"
    fi
}

# Standby server (graceful shutdown)
standby-server() {
    echo "[INFO] Sending standby command to server"
    ssh-server "echo 'Preparing server for Wake on LAN...' && \
                echo 'Checking maintenance mode...' && \
                if esxcli system maintenanceMode get | grep -q Enabled; then \
                    echo 'Maintenance mode already enabled - OK'; \
                else \
                    echo 'Entering maintenance mode...' && \
                    esxcli system maintenanceMode set -e true; \
                fi && \
                echo 'Waiting 5 seconds for services to stop...' && \
                sleep 5 && \
                echo 'Shutting down to standby mode...' && \
                echo 'Server will be ready for Wake on LAN' && \
                esxcli system shutdown poweroff -d 10 -r \"Standby for WoL - \$(date)\""
    echo "[INFO] Standby command sent"
}

# Quick wake alias
alias wakeserver="wakeonlan 00:e0:25:30:50:7b"  # Thay MAC của bạn
```

#### B.3 Reload cấu hình:
```bash
source ~/.zshrc
```

### 💻 Windows Setup

#### B.1 Tạo PowerShell script `ServerManager.ps1`:
```powershell
# ESXi Server Management Script
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("wake", "standby", "status")]
    [string]$Action = "wake",
    
    [string]$ServerIP = "192.168.1.50",        # Thay IP của bạn
    [string]$MacAddress = "00:e0:25:30:50:7b", # Thay MAC của bạn
    [string]$Username = "root"
)

function Test-ServerStatus {
    param([string]$IP)
    Write-Host "[INFO] Checking server status at $IP..." -ForegroundColor Cyan
    $ping = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue
    return $ping
}

function Send-WakeOnLan {
    param([string]$Mac)
    Write-Host "[INFO] Sending WOL packet to $Mac..." -ForegroundColor Yellow
    
    try {
        $mac = $Mac -replace '[:-]'
        $target = 0,2,4,6,8,10 | ForEach-Object {[convert]::ToByte($mac.substring($_,2),16)}
        $packet = (,[byte]255 * 6) + ($target * 16)
        
        $UDPclient = New-Object System.Net.Sockets.UdpClient
        $UDPclient.Connect(([System.Net.IPAddress]::Broadcast),9)
        [void]$UDPclient.Send($packet, $packet.Length)
        $UDPclient.Close()
        
        Write-Host "[INFO] WOL packet sent successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERROR] Failed to send WOL packet: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Invoke-ServerStandby {
    param([string]$IP, [string]$User)
    Write-Host "[INFO] Sending standby command to server..." -ForegroundColor Yellow
    
    $standbyCommand = @"
echo 'Preparing server for Wake on LAN...' && \
echo 'Checking maintenance mode...' && \
if esxcli system maintenanceMode get | grep -q Enabled; then \
    echo 'Maintenance mode already enabled - OK'; \
else \
    echo 'Entering maintenance mode...' && \
    esxcli system maintenanceMode set -e true; \
fi && \
echo 'Waiting 5 seconds for services to stop...' && \
sleep 5 && \
echo 'Shutting down to standby mode...' && \
echo 'Server will be ready for Wake on LAN' && \
esxcli system shutdown poweroff -d 10 -r \"Standby for WoL - \$(date)\"
"@

    try {
        ssh "$User@$IP" $standbyCommand
        Write-Host "[INFO] Standby command sent successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to send standby command: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
switch ($Action) {
    "wake" {
        if (Test-ServerStatus -IP $ServerIP) {
            Write-Host "[INFO] Server is already online!" -ForegroundColor Green
            Write-Host "[INFO] ESXi URL: https://$ServerIP" -ForegroundColor Cyan
        } else {
            Write-Host "[WARN] Server is offline. Waking up..." -ForegroundColor Yellow
            if (Send-WakeOnLan -Mac $MacAddress) {
                Write-Host "[INFO] Waiting for server to boot up..." -ForegroundColor Yellow
                
                for ($i = 1; $i -le 12; $i++) {
                    Start-Sleep -Seconds 5
                    if (Test-ServerStatus -IP $ServerIP) {
                        Write-Host "[INFO] Server online after $($i*5) seconds!" -ForegroundColor Green
                        Write-Host "[INFO] ESXi URL: https://$ServerIP" -ForegroundColor Cyan
                        return
                    }
                    Write-Host "[INFO] Waiting... ($($i*5)s elapsed)" -ForegroundColor Gray
                }
                Write-Host "[WARN] Timeout reached. Check https://$ServerIP manually" -ForegroundColor Yellow
            }
        }
    }
    
    "standby" {
        if (Test-ServerStatus -IP $ServerIP) {
            Invoke-ServerStandby -IP $ServerIP -User $Username
        } else {
            Write-Host "[WARN] Server appears to be offline already." -ForegroundColor Yellow
        }
    }
    
    "status" {
        if (Test-ServerStatus -IP $ServerIP) {
            Write-Host "[INFO] Server is ONLINE" -ForegroundColor Green
            Write-Host "[INFO] ESXi URL: https://$ServerIP" -ForegroundColor Cyan
        } else {
            Write-Host "[INFO] Server is OFFLINE" -ForegroundColor Red
        }
    }
}
```

#### B.2 Tạo batch wrappers:

**WakeServer.bat:**
```batch
@echo off
title Wake ESXi Server
powershell -ExecutionPolicy Bypass -File "%~dp0ServerManager.ps1" -Action wake
pause
```

**StandbyServer.bat:**
```batch
@echo off
title Standby ESXi Server
powershell -ExecutionPolicy Bypass -File "%~dp0ServerManager.ps1" -Action standby
pause
```

---

## PHẦN C: QUY TRÌNH SỬ DỤNG HÀNG NGÀY

### 🚀 macOS Daily Usage:

```bash
# Bật server (với kiểm tra thông minh)
wake-server

# Tắt server (graceful shutdown)
standby-server

# Quick wake (không kiểm tra)
wakeserver

# SSH vào server
ssh-server
```

### 💻 Windows Daily Usage:

```powershell
# Bật server
.\ServerManager.ps1 -Action wake

# Tắt server  
.\ServerManager.ps1 -Action standby

# Kiểm tra status
.\ServerManager.ps1 -Action status

# Hoặc dùng batch files
WakeServer.bat
StandbyServer.bat
```

---

## PHẦN D: TROUBLESHOOTING

### D.1 Kiểm tra WOL trên ESXi:
```bash
ssh root@[IP_ESXi]
ethtool vmnic0 | grep -i wake
# Phải thấy: Wake-on: g
```

### D.2 Test kết nối:
```bash
# Test ping từ client
ping [IP_ESXi]

# Test SSH connection
ssh root@[IP_ESXi] "echo 'Connection OK'"
```

### D.3 Các vấn đề thường gặp:

**❌ WOL không hoạt động:**
- Kiểm tra server có power (PSU switch ON)
- Kiểm tra network cable
- Verify MAC address đúng
- Test trong cùng subnet

**❌ SSH connection failed:**
- Kiểm tra SSH service enabled trên ESXi
- Verify firewall settings
- Check IP address chính xác

---

## PHẦN E: TÓM TẮT NHANH

### 🎯 Ưu điểm của Client-side Approach:

**✅ Centralized Management**: Tất cả scripts ở client, dễ maintain  
**✅ Version Control**: Scripts có thể commit vào git  
**✅ Backup Friendly**: Backup cùng với dotfiles  
**✅ Multi-server Ready**: Dễ extend cho nhiều servers  
**✅ No Server Dependencies**: Không cần maintain scripts trên server  

### 📋 Setup tóm tắt:

```bash
# 1. ESXi one-time setup
ssh root@[IP] "ethtool -s vmnic0 wol g"

# 2. macOS setup
brew install wakeonlan
# Thêm functions vào ~/.zshrc
source ~/.zshrc

# 3. Daily usage
wake-server    # Bật server
standby-server # Tắt server
```

### 🔧 Configuration checklist:

- [ ] ESXi WOL enabled: `ethtool vmnic0 | grep "Wake-on: g"`
- [ ] MAC address đúng trong scripts
- [ ] IP address đúng trong scripts  
- [ ] SSH key setup (optional): `ssh-copy-id root@[IP]`
- [ ] Network trong cùng subnet
- [ ] Firewall không block UDP port 9

---

## 🎓 KẾT LUẬN

**Client-side approach** cho Wake On LAN mang lại nhiều lợi ích cho DevOps learning:

✅ **Infrastructure as Code**: Scripts client-side dễ version control  
✅ **Automation Best Practices**: Centralized management, smart checking  
✅ **Scalability**: Dễ mở rộng cho multiple servers  
✅ **Maintainability**: Không phụ thuộc vào server-side scripts  
✅ **DevOps Workflow**: Tích hợp tốt với daily development workflow  

**Next steps**: Tích hợp vào CI/CD pipelines, monitoring alerts, và infrastructure automation workflows! 🚀
