# Port Forwarding & Network Services

## Giới thiệu

Port Forwarding là **bước quan trọng thứ ba** trong journey DevOps home lab. Sau khi đã có Wake On LAN để bật server và Autostart để chạy VMs/services, bước tiếp theo là **expose services ra ngoài Internet** để có thể truy cập từ bất kỳ đâu.

### Tại sao Port Forwarding quan trọng cho DevOps?

**Service Exposure**: Học cách expose internal services ra external network - kỹ năng cốt lõi của DevOps engineer.

**Security Understanding**: Hiểu về network security, firewall, và access control.

**Production Simulation**: Home lab có thể simulate production environment với external access.

**Service Discovery**: Nền tảng cho reverse proxy, load balancer, và service mesh.

---

## PHẦN A: KIẾN THỨC CƠ BẢN

### A.1 Port Forwarding là gì?

**Đơn giản**: Chuyển tiếp traffic từ Router's public IP → Internal server's private IP

**Ví dụ thực tế**:
```
Internet Request: 203.0.113.5:8080
       ↓ Router Port Forwarding
Internal Server: 192.168.1.100:80
```

### A.2 Các loại Port Forwarding phổ biến:

| Service Type | External Port | Internal Port | Use Case |
|-------------|---------------|---------------|----------|
| **Web Server** | 80, 443 | 80, 443 | Website, API |
| **SSH** | 2222 | 22 | Remote access |
| **FTP** | 21, 20 | 21, 20 | File transfer |
| **Database** | 3306, 5432 | 3306, 5432 | Remote DB access |
| **Custom Apps** | 8080, 8443 | Any | Development services |

### A.3 Security Best Practices:

**✅ DO:**
- Use non-standard external ports (2222 thay vì 22)
- Enable strong authentication
- Use VPN khi có thể
- Monitor access logs
- Firewall rules restrictive

**❌ DON'T:**
- Expose databases directly
- Use default ports cho critical services
- Open ports without authentication
- Forget to monitor

---

## PHẦN B: ROUTER SETUP (THỰC HÀNH)

### B.1 Xác định Router Model:

**Common Vietnamese ISP Routers:**
- **VNPT**: Gpon ONT (HG8145V5, HG8240H5)
- **Viettel**: Gpon ONT (G-97RG6, I-040GW)
- **FPT**: ZTE, Huawei models
- **Custom routers**: TP-Link, Asus, Netgear

### B.2 Router Access & Configuration:

#### B.2.1 Truy cập Router Admin:
```bash
# Tìm gateway IP
ip route | grep default
# Hoặc
netstat -rn | grep default

# Common router IPs:
# 192.168.1.1 (most common)
# 192.168.0.1
# 10.0.0.1
```

**Browser access**: `http://192.168.1.1`

**Default credentials** (tham khảo):
- VNPT: admin/admin hoặc admin/vnpt
- Viettel: admin/admin
- FPT: admin/fpt

#### B.2.2 Locate Port Forwarding Settings:

**Common menu paths:**
- `Advanced → NAT Forwarding → Virtual Servers`
- `Firewall → Port Forwarding`
- `Network → NAT → Port Forwarding`
- `Advanced Settings → Port Range Forwarding`

### B.3 Configuration Examples:

#### Example 1: Web Server (Nginx trong VM)
```
Service Name: Web-Server
External Port: 8080
Internal IP: 192.168.1.100
Internal Port: 80
Protocol: TCP
Enable: Yes
```

#### Example 2: SSH Access 
```
Service Name: SSH-Access
External Port: 2222
Internal IP: 192.168.1.100
Internal Port: 22
Protocol: TCP
Enable: Yes
```

#### Example 3: HTTPS với Custom Port
```
Service Name: HTTPS-App
External Port: 8443
Internal IP: 192.168.1.100
Internal Port: 443
Protocol: TCP
Enable: Yes
```

---

## PHẦN C: VM/SERVER SETUP

### C.1 Prepare Services trong ESXi VMs:

#### C.1.1 Nginx Web Server Setup:
```bash
# SSH vào VM
ssh root@192.168.1.100

# Install Nginx (Ubuntu/Debian)
apt update && apt install nginx -y

# Start và enable
systemctl start nginx
systemctl enable nginx

# Test local access
curl http://localhost

# Configure firewall
ufw allow 80/tcp
ufw allow 443/tcp
```

#### C.1.2 Custom Application Example:
```bash
# Simple Python web server cho testing
cat > /opt/test-server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
from datetime import datetime

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        html = f"""
        <html><body>
        <h1>DevOps Home Lab Server</h1>
        <p>Current time: {datetime.now()}</p>
        <p>Server IP: {self.server.server_address[0]}</p>
        <p>Requested path: {self.path}</p>
        <hr>
        <p>🚀 Port Forwarding Working!</p>
        </body></html>
        """
        self.wfile.write(html.encode())

PORT = 8080
with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    print(f"Server running at port {PORT}")
    httpd.serve_forever()
EOF

chmod +x /opt/test-server.py

# Create systemd service
cat > /etc/systemd/system/test-server.service << 'EOF'
[Unit]
Description=Test Web Server for Port Forwarding
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt
ExecStart=/opt/test-server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable test-server
systemctl start test-server
```

### C.2 Firewall Configuration:

#### C.2.1 Ubuntu/Debian (ufw):
```bash
# Check status
ufw status

# Allow specific ports
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow from 192.168.1.0/24 to any port 22

# Enable firewall
ufw enable
```

#### C.2.2 CentOS/RHEL (firewalld):
```bash
# Check status
firewall-cmd --state

# Add ports
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent
firewall-cmd --add-port=8080/tcp --permanent

# Reload
firewall-cmd --reload
```

---

## PHẦN D: TESTING & VALIDATION

### D.1 Internal Testing:

```bash
# Test từ ESXi host
curl http://192.168.1.100:80
curl http://192.168.1.100:8080

# Test từ client machine (same network)
curl http://192.168.1.100:80
```

### D.2 External Testing:

#### D.2.1 Tìm Public IP:
```bash
# Method 1: Command line
curl ipinfo.io/ip

# Method 2: Web
# Visit: whatismyip.com
```

#### D.2.2 Test Port Forwarding:
```bash
# From external network (mobile hotspot, different location)
curl http://[YOUR_PUBLIC_IP]:8080

# Browser test
http://[YOUR_PUBLIC_IP]:8080
```

### D.3 Advanced Testing Script:

**Tạo file `test-portforward.sh`:**
```bash
#!/bin/bash

# Port Forwarding Test Script
PUBLIC_IP="YOUR_PUBLIC_IP"
INTERNAL_IP="192.168.1.100"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Testing Port Forwarding Configuration"
echo "========================================"

# Test internal access
echo -e "\n${YELLOW}Testing internal access...${NC}"
if curl -s --connect-timeout 5 http://$INTERNAL_IP:80 > /dev/null; then
    echo -e "${GREEN}✅ Internal HTTP (80) - OK${NC}"
else
    echo -e "${RED}❌ Internal HTTP (80) - FAILED${NC}"
fi

if curl -s --connect-timeout 5 http://$INTERNAL_IP:8080 > /dev/null; then
    echo -e "${GREEN}✅ Internal Custom (8080) - OK${NC}"
else
    echo -e "${RED}❌ Internal Custom (8080) - FAILED${NC}"
fi

# Test external access (if PUBLIC_IP is set)
if [ "$PUBLIC_IP" != "YOUR_PUBLIC_IP" ]; then
    echo -e "\n${YELLOW}Testing external access...${NC}"
    
    if curl -s --connect-timeout 10 http://$PUBLIC_IP:8080 > /dev/null; then
        echo -e "${GREEN}✅ External Port Forward (8080) - OK${NC}"
    else
        echo -e "${RED}❌ External Port Forward (8080) - FAILED${NC}"
    fi
else
    echo -e "\n${YELLOW}Skipping external test - Please set PUBLIC_IP variable${NC}"
fi

echo -e "\n🔗 Quick URLs:"
echo "Internal: http://$INTERNAL_IP:80"
echo "Internal: http://$INTERNAL_IP:8080"
if [ "$PUBLIC_IP" != "YOUR_PUBLIC_IP" ]; then
    echo "External: http://$PUBLIC_IP:8080"
fi
```

---

## PHẦN E: PRODUCTION-READY EXAMPLES

### E.1 Reverse Proxy với Nginx:

**Configure Nginx trong VM làm reverse proxy:**
```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name your-domain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    # SSL certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Main application
    location / {
        proxy_pass http://192.168.1.101:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API services
    location /api/ {
        proxy_pass http://192.168.1.102:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Static files
    location /static/ {
        alias /var/www/static/;
        expires 1y;
    }
}
```

### E.2 Docker Services Setup:

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
    restart: unless-stopped

  app:
    image: node:16-alpine
    working_dir: /app
    volumes:
      - ./app:/app
    command: npm start
    ports:
      - "3000:3000"
    restart: unless-stopped

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"  # Only if needed externally
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

---

## PHẦN F: TROUBLESHOOTING

### F.1 Common Issues & Solutions:

**❌ Port không accessible từ external:**
```bash
# Check 1: Service running?
ss -tlnp | grep :8080
systemctl status nginx

# Check 2: Firewall blocking?
ufw status
iptables -L

# Check 3: Router settings correct?
# Double-check router port forwarding configuration

# Check 4: ISP blocking?
# Some ISPs block common ports, try different port numbers
```

**❌ Timeout khi access external:**
```bash
# Check from different network
# Use mobile hotspot để test

# Check ISP restrictions
# Some ISPs use CGNAT, không có true public IP

# Verify public IP
curl ipinfo.io/ip
```

**❌ SSL/HTTPS issues:**
```bash
# Check certificate
openssl s_client -connect your-domain.com:443

# Check nginx config
nginx -t

# Check file permissions
ls -la /etc/letsencrypt/live/your-domain.com/
```

### F.2 Monitoring & Logging:

**Setup access logging:**
```bash
# Nginx access log
tail -f /var/log/nginx/access.log

# Custom application log
journalctl -u test-server -f

# Router logs (if available)
# Check router admin panel for connection logs
```

---

## PHẦN G: SECURITY HARDENING

### G.1 Essential Security Measures:

```bash
# 1. Change default SSH port
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd

# 2. Install fail2ban
apt install fail2ban -y

# Configure fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 2222

[nginx-http-auth]
enabled = true
EOF

systemctl enable fail2ban
systemctl start fail2ban

# 3. Setup basic auth cho sensitive endpoints
htpasswd -c /etc/nginx/.htpasswd admin
# Add to nginx config:
# auth_basic "Restricted";
# auth_basic_user_file /etc/nginx/.htpasswd;
```

### G.2 VPN Alternative (WireGuard):

```bash
# Instead of exposing services directly, use VPN
apt install wireguard -y

# Generate keys
wg genkey | tee privatekey | wg pubkey > publickey

# Configure WireGuard
cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
EOF

# Enable và start
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

---

## PHẦN H: INTEGRATION VỚI AUTOMATION

### H.1 Tích hợp với Wake On LAN workflow:

**Enhanced macOS function trong `~/.zshrc`:**
```bash
# Enhanced server management với port forwarding check
wake-server-full() {
    SERVER_IP="192.168.1.50"
    SERVER_MAC="00:e0:25:30:50:7b"
    
    echo "[INFO] Starting full server workflow..."
    
    # 1. Wake server
    wake-server
    
    # 2. Wait for ESXi
    sleep 30
    
    # 3. Check VMs autostart
    echo "[INFO] Checking VM autostart..."
    ssh root@$SERVER_IP "esxcli vm process list"
    
    # 4. Test port forwarding
    echo "[INFO] Testing port forwarding..."
    sleep 60  # Wait for VMs to fully boot
    
    if curl -s --connect-timeout 10 http://192.168.1.100:80 > /dev/null; then
        echo "[SUCCESS] Web service accessible internally"
        
        # Test external if we have public IP
        PUBLIC_IP=$(curl -s ipinfo.io/ip)
        if curl -s --connect-timeout 10 http://$PUBLIC_IP:8080 > /dev/null; then
            echo "[SUCCESS] Port forwarding working - http://$PUBLIC_IP:8080"
        else
            echo "[WARNING] External access not working"
        fi
    else
        echo "[ERROR] Web service not accessible"
    fi
}
```

### H.2 Monitoring Script:

```bash
#!/bin/bash
# port-monitor.sh - Monitor port forwarding status

SERVICES=(
    "HTTP:80:192.168.1.100"
    "HTTPS:443:192.168.1.100"
    "Custom:8080:192.168.1.100"
    "SSH:2222:192.168.1.100"
)

PUBLIC_IP=$(curl -s ipinfo.io/ip)
LOG_FILE="/var/log/port-monitor.log"

echo "$(date): Starting port monitoring" >> $LOG_FILE

for service in "${SERVICES[@]}"; do
    IFS=':' read -r name ext_port internal_ip <<< "$service"
    
    # Test internal
    if nc -z $internal_ip $ext_port 2>/dev/null; then
        echo "$(date): ✅ $name - Internal OK" >> $LOG_FILE
    else
        echo "$(date): ❌ $name - Internal FAILED" >> $LOG_FILE
        continue
    fi
    
    # Test external (if applicable)
    if [[ "$ext_port" =~ ^(80|8080|443|8443)$ ]]; then
        if curl -s --connect-timeout 5 http://$PUBLIC_IP:$ext_port > /dev/null; then
            echo "$(date): ✅ $name - External OK" >> $LOG_FILE
        else
            echo "$(date): ❌ $name - External FAILED" >> $LOG_FILE
        fi
    fi
done
```

---

## 🎯 TÓM TẮT & BEST PRACTICES

### ✅ DevOps Learning Outcomes:

**Network Understanding**: Deep knowledge về NAT, routing, firewalls  
**Security Awareness**: Hiểu rủi ro và cách mitigation  
**Service Architecture**: Reverse proxy, load balancing concepts  
**Production Readiness**: SSL, monitoring, logging  
**Automation Integration**: Scripts, monitoring, alerting  

### 📋 Checklist Production-Ready:

- [ ] **Router**: Port forwarding configured correctly
- [ ] **Server**: Services running và accessible
- [ ] **Firewall**: Proper rules, not too permissive  
- [ ] **SSL**: HTTPS enabled với valid certificates
- [ ] **Monitoring**: Logs và health checks
- [ ] **Security**: Fail2ban, strong auth, non-default ports
- [ ] **Backup**: Config files backed up
- [ ] **Documentation**: Internal IPs, ports, credentials documented

### 🔐 Security First Approach:

```bash
# Recommended port mapping for home lab:
# SSH: 2222 → 22 (non-standard external port)
# HTTP: 8080 → 80 (development)
# HTTPS: 8443 → 443 (development)
# Custom apps: 9000+ → internal ports
```

---

## 🔗 Next Steps: Secure Remote Access

Port Forwarding expose services ra Internet, nhưng **security-conscious approach** là sử dụng **VPN tunnel** thay vì expose multiple ports. Đây là evolution tự nhiên cho production environments.

### 🔒 Recommended Next Guide: [OpenVPN Server với OVPM](OVPM.md)

**Why VPN is better than Port Forwarding:**

| Aspect | Port Forwarding | VPN Server |
|--------|----------------|------------|
| **Security** | Multiple exposed ports | Single encrypted tunnel |
| **Access Control** | Router-level rules | User-based authentication |
| **Audit Trail** | Limited logging | Complete user tracking |
| **Scalability** | Manual port management | Centralized user management |

**📋 Current capability**: 
```
WOL → Auto VMs → Services → External Access (multiple ports)
```

**🎯 Next level capability**: 
```
WOL → Auto VMs → Services → Secure VPN Access (single tunnel)
```

**What you'll learn**:
- ✅ **Enterprise Security**: PKI certificates, encryption, authentication
- ✅ **VPN Management**: OVPM web interface, user lifecycle
- ✅ **Network Architecture**: VPN tunneling, routing, firewall integration
- ✅ **Remote Development**: Secure access to entire home lab environment

**Perfect progression**: Basic exposure → Secure access → Enterprise-grade remote infrastructure! 🔒
