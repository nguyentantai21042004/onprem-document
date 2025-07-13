# Wake-on-LAN Setup Guide

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Thiết lập trên ESXi Server](#thiết-lập-trên-esxi-server)
3. [Thiết lập Client-side Automation](#thiết-lập-client-side-automation)
4. [Testing và Validation](#testing-và-validation)
5. [Troubleshooting](#troubleshooting)

## Giới thiệu

Wake-on-LAN (WOL) là một trong những kỹ thuật cơ bản nhưng quan trọng khi bắt đầu học DevOps. Nó không chỉ giúp quản lý server từ xa mà còn mở ra nhiều khái niệm quan trọng trong việc quản lý hạ tầng.

### Tại sao Wake-on-LAN quan trọng?

- **Automation Foundation**: WOL là bước đầu tiên để hiểu về remote control và automation - hai yếu tố cốt lõi của DevOps
- **Resource Management**: Học cách bật/tắt server từ xa giúp tối ưu hóa tài nguyên và chi phí vận hành
- **Network Understanding**: Việc cài đặt WOL đòi hỏi hiểu biết cơ bản về network protocols và infrastructure
- **Infrastructure as Code**: Scripts WOL là nền tảng đầu tiên cho việc quản lý infrastructure bằng code

---

## Thiết lập trên ESXi Server

### Bước 1: Kích hoạt Wake-on-LAN

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

## Thiết lập Client-side Automation

### 🍎 macOS Setup (Recommended)

#### Bước 1: Cài đặt công cụ cần thiết
```bash
# Cài đặt wakeonlan
brew install wakeonlan
```

#### Bước 2: Thêm functions vào ~/.zshrc

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

#### Bước 3: Reload cấu hình
```bash
source ~/.zshrc
```

### 💻 Windows Setup

#### Tạo PowerShell script `ServerManager.ps1`:
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

---

## Testing và Validation

### Testing Wake-on-LAN

#### 1. Test từ macOS/Linux:
```bash
# Test wake function
wake-server

# Test standby function
standby-server

# Test status check
ping -c 1 192.168.1.50
```

#### 2. Test từ Windows:
```powershell
# Test wake
.\ServerManager.ps1 -Action wake

# Test standby
.\ServerManager.ps1 -Action standby

# Test status
.\ServerManager.ps1 -Action status
```

### Validation Checklist

- [ ] **WOL enabled trên ESXi**: `ethtool vmnic0 | grep -i wake` shows `Wake-on: g`
- [ ] **MAC address được ghi nhận**: Đã lưu MAC address của vmnic0
- [ ] **Client tools installed**: wakeonlan (macOS) hoặc PowerShell script (Windows)
- [ ] **Scripts functional**: Wake và standby functions hoạt động
- [ ] **Network connectivity**: Ping test từ client tới server
- [ ] **ESXi web access**: Có thể truy cập https://server-ip sau khi wake

---

## Troubleshooting

### Common Issues

#### 1. WOL packet không hoạt động
**Symptoms**: Server không wake up sau khi gửi WOL packet

**Solutions**:
```bash
# Kiểm tra WOL status trên ESXi
ssh root@server-ip
ethtool vmnic0 | grep -i wake

# Re-enable WOL nếu cần
ethtool -s vmnic0 wol g

# Kiểm tra power management
esxcli system settings advanced list -o /Power/CpuPolicy
```

#### 2. Network connectivity issues
**Symptoms**: Client không thể kết nối tới server

**Solutions**:
```bash
# Test network connectivity
ping server-ip
traceroute server-ip

# Check firewall rules
# Ensure UDP port 9 is open for WOL
```

#### 3. ESXi không shutdown properly
**Symptoms**: Server không vào standby mode

**Solutions**:
```bash
# Force maintenance mode
esxcli system maintenanceMode set -e true

# Check running VMs
esxcli vm process list

# Force shutdown if necessary
esxcli system shutdown poweroff -d 10 -r "Force shutdown"
```

### Monitoring và Logs

#### ESXi Logs:
```bash
# Check system logs
tail -f /var/log/syslog.log

# Check network logs
tail -f /var/log/vmkernel.log
```

#### Client-side Logging:
```bash
# Add logging to wake-server function
echo "$(date): WOL packet sent to $SERVER_MAC" >> ~/wol.log
```

---

## Best Practices

### Security Considerations

1. **MAC Address Protection**: Không share MAC address publicly
2. **Network Segmentation**: Sử dụng VPN khi WOL từ internet
3. **Access Control**: Hạn chế quyền truy cập SSH tới ESXi
4. **Monitoring**: Log tất cả WOL activities

### Performance Optimization

1. **Static IP**: Sử dụng static IP cho ESXi server
2. **Network Speed**: Ensure gigabit network connection
3. **Power Management**: Optimize power settings cho WOL
4. **Backup Plans**: Có physical access backup plan

### Automation Integration

1. **Scheduled Tasks**: Tích hợp với cron jobs
2. **Monitoring Systems**: Alert khi server offline
3. **Infrastructure as Code**: Version control cho WOL scripts
4. **Documentation**: Maintain accurate IP/MAC mappings

---

## Next Steps

Sau khi hoàn thành Wake-on-LAN setup, bạn có thể tiến tới:

1. **[ESXi VM Autostart](esxi-vm-autostart.md)** - Tự động khởi động VMs
2. **[Networking Configuration](networking.md)** - Advanced network setup
3. **[Port Forwarding](port-forwarding.md)** - Expose services ra internet

---

## Tham khảo

- [VMware ESXi Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [Wake-on-LAN Standard](https://en.wikipedia.org/wiki/Wake-on-LAN)
- [ethtool Documentation](https://www.kernel.org/pub/software/network/ethtool/) 