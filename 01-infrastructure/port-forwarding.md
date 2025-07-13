# Port Forwarding & Network Services

## 📋 Mục lục
1. [Giới thiệu](#giới-thiệu)
2. [Kiến thức cơ bản](#kiến-thức-cơ-bản)
3. [Router Setup](#router-setup)
4. [VM/Server Setup](#vmserver-setup)
5. [Testing và Validation](#testing-và-validation)
6. [Security và Best Practices](#security-và-best-practices)

## Giới thiệu

Port Forwarding là **bước quan trọng thứ ba** trong journey DevOps home lab. Sau khi đã có Wake-on-LAN để bật server và Autostart để chạy VMs/services, bước tiếp theo là **expose services ra ngoài Internet** để có thể truy cập từ bất kỳ đâu.

### Tại sao Port Forwarding quan trọng cho DevOps?

- **Service Exposure**: Học cách expose internal services ra external network - kỹ năng cốt lõi của DevOps engineer
- **Security Understanding**: Hiểu về network security, firewall, và access control
- **Production Simulation**: Home lab có thể simulate production environment với external access
- **Service Discovery**: Nền tảng cho reverse proxy, load balancer, và service mesh

---

## Kiến thức cơ bản

### Port Forwarding là gì?

**Đơn giản**: Chuyển tiếp traffic từ Router's public IP → Internal server's private IP

**Ví dụ thực tế**:
```
Internet Request: 203.0.113.5:8080
       ↓ Router Port Forwarding
Internal Server: 192.168.1.100:80
```

### Các loại Port Forwarding phổ biến:

| Service Type | External Port | Internal Port | Use Case |
|-------------|---------------|---------------|----------|
| **Web Server** | 80, 443 | 80, 443 | Website, API |
| **SSH** | 2222 | 22 | Remote access |
| **FTP** | 21, 20 | 21, 20 | File transfer |
| **Database** | 3306, 5432 | 3306, 5432 | Remote DB access |
| **Custom Apps** | 8080, 8443 | Any | Development services |

### Security Best Practices:

#### ✅ DO:
- Use non-standard external ports (2222 thay vì 22)
- Enable strong authentication
- Use VPN khi có thể
- Monitor access logs
- Firewall rules restrictive

#### ❌ DON'T:
- Expose databases directly
- Use default ports cho critical services
- Open ports without authentication
- Forget to monitor

---

## Router Setup

### Xác định Router Model

#### Common Vietnamese ISP Routers:
- **VNPT**: Gpon ONT (HG8145V5, HG8240H5)
- **Viettel**: Gpon ONT (G-97RG6, I-040GW)
- **FPT**: ZTE, Huawei models
- **Custom routers**: TP-Link, Asus, Netgear

### Router Access & Configuration

#### Truy cập Router Admin:
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

#### Default credentials (tham khảo):
- **VNPT**: admin/admin hoặc admin/vnpt
- **Viettel**: admin/admin
- **FPT**: admin/fpt

#### Locate Port Forwarding Settings:

**Common menu paths:**
- `Advanced → NAT Forwarding → Virtual Servers`
- `Firewall → Port Forwarding`
- `Network → NAT → Port Forwarding`
- `Advanced Settings → Port Range Forwarding`

### Configuration Examples

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

#### Example 4: Multiple Services
```
# Web Server
External: 8080 → Internal: 192.168.1.100:80

# API Server
External: 8081 → Internal: 192.168.1.100:3000

# Database (careful with security)
External: 33060 → Internal: 192.168.1.100:3306

# SSH Access
External: 2222 → Internal: 192.168.1.100:22
```

---

## VM/Server Setup

### Prepare Services trong ESXi VMs

#### Nginx Web Server Setup:
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

#### Custom Application Example:
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

### Firewall Configuration

#### Ubuntu/Debian (ufw):
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

#### CentOS/RHEL (firewalld):
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

### Docker Services Setup

#### Docker Compose Example:
```yaml
# /opt/docker-services/docker-compose.yml
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    restart: unless-stopped
  
  api:
    image: node:alpine
    ports:
      - "3000:3000"
    volumes:
      - ./app:/app
    working_dir: /app
    command: node server.js
    restart: unless-stopped
  
  db:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: secure_password
      MYSQL_DATABASE: app_db
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped

volumes:
  mysql_data:
```

```bash
# Deploy services
cd /opt/docker-services
docker-compose up -d
```

---

## Testing và Validation

### Internal Testing

#### Test từ bên trong network:
```bash
# Test local services
curl http://192.168.1.100:80
curl http://192.168.1.100:8080
curl http://192.168.1.100:3000

# Test SSH access
ssh -p 22 root@192.168.1.100
```

#### Test routing:
```bash
# Check listening ports
netstat -tlnp | grep LISTEN
# hoặc
ss -tlnp | grep LISTEN

# Test connectivity
telnet 192.168.1.100 80
telnet 192.168.1.100 8080
```

### External Testing

#### Test từ internet:
```bash
# Get public IP
curl ifconfig.me

# Test external access (từ máy khác ngoài network)
curl http://YOUR_PUBLIC_IP:8080
curl http://YOUR_PUBLIC_IP:8081

# Test SSH
ssh -p 2222 root@YOUR_PUBLIC_IP
```

#### Online Testing Tools:
- **Port Checker**: https://www.portchecker.com/
- **Can You See Me**: https://canyouseeme.org/
- **Port Scanner**: https://www.yougetsignal.com/tools/open-ports/

### Monitoring và Logging

#### Access Logs:
```bash
# Nginx access logs
tail -f /var/log/nginx/access.log

# Custom application logs
tail -f /var/log/test-server.log

# System logs
journalctl -f -u nginx
journalctl -f -u test-server
```

#### Network Monitoring:
```bash
# Monitor connections
netstat -an | grep :80
ss -tuln | grep :80

# Monitor bandwidth
iftop -i eth0
nethogs
```

---

## Security và Best Practices

### Security Hardening

#### 1. Change Default Ports:
```bash
# SSH example: Change from 22 to 2222
# Edit /etc/ssh/sshd_config
Port 2222
systemctl restart sshd

# Update firewall
ufw delete allow 22
ufw allow 2222/tcp
```

#### 2. Implement Rate Limiting:
```bash
# Using fail2ban
apt install fail2ban

# Configure /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
```

#### 3. SSL/TLS Configuration:
```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Access Control

#### 1. IP-based Restrictions:
```bash
# Allow only specific IPs
ufw allow from 203.0.113.0/24 to any port 22
ufw allow from 198.51.100.0/24 to any port 80

# Deny all others
ufw default deny incoming
```

#### 2. VPN Integration:
```bash
# Only allow access through VPN
ufw allow from 10.8.0.0/24 to any port 22
ufw allow from 10.8.0.0/24 to any port 3306
```

### Monitoring và Alerting

#### 1. Log Analysis:
```bash
# Monitor failed login attempts
grep "Failed password" /var/log/auth.log

# Monitor successful connections
grep "Accepted" /var/log/auth.log

# Web server errors
grep "ERROR" /var/log/nginx/error.log
```

#### 2. Automated Monitoring:
```bash
# Script to monitor service health
#!/bin/bash
# /usr/local/bin/service-monitor.sh

SERVICES=("nginx" "ssh" "mysql")
DISCORD_WEBHOOK="YOUR_WEBHOOK_URL"

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet $service; then
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"content\":\"⚠️ Service $service is down on $(hostname)\"}" \
             "$DISCORD_WEBHOOK"
    fi
done
```

### Performance Optimization

#### 1. Connection Limits:
```nginx
# Nginx rate limiting
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
    
    server {
        limit_req zone=api burst=20 nodelay;
        limit_conn conn_limit_per_ip 10;
    }
}
```

#### 2. Caching:
```nginx
# Static content caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# API response caching
location /api/ {
    proxy_cache my_cache;
    proxy_cache_valid 200 60m;
    proxy_cache_key "$scheme$request_method$host$request_uri";
}
```

---

## Troubleshooting

### Common Issues

#### 1. Port not accessible from outside:
```bash
# Check if service is running
systemctl status nginx

# Check if port is listening
netstat -tlnp | grep :80

# Check firewall rules
ufw status verbose

# Check router configuration
# - Verify port forwarding rules
# - Check if router firewall is blocking
```

#### 2. Connection timeout:
```bash
# Check network connectivity
ping your-public-ip

# Check ISP restrictions
# Some ISPs block certain ports

# Check DNS resolution
nslookup your-domain.com
```

#### 3. SSL/TLS errors:
```bash
# Check certificate
openssl x509 -in cert.pem -text -noout

# Test SSL connection
openssl s_client -connect your-domain.com:443

# Check Nginx SSL configuration
nginx -t
```

### Performance Issues

#### 1. Slow response times:
```bash
# Check server resources
htop
iostat -x 1

# Check network latency
ping -c 10 your-public-ip

# Monitor connection counts
netstat -an | grep :80 | wc -l
```

#### 2. High bandwidth usage:
```bash
# Monitor bandwidth
iftop -i eth0
vnstat -i eth0

# Check for DDoS
netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
```

---

## Advanced Configuration

### Reverse Proxy Setup

#### Multi-service Reverse Proxy:
```nginx
# /etc/nginx/sites-available/reverse-proxy
upstream backend_web {
    server 192.168.1.100:80;
    server 192.168.1.101:80;
}

upstream backend_api {
    server 192.168.1.100:3000;
    server 192.168.1.101:3000;
}

server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://backend_web;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /api/ {
        proxy_pass http://backend_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Load Balancing

#### HAProxy Configuration:
```bash
# /etc/haproxy/haproxy.cfg
frontend web_frontend
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/yourdomain.pem
    redirect scheme https if !{ ssl_fc }
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk GET /health
    server web1 192.168.1.100:80 check
    server web2 192.168.1.101:80 check
    server web3 192.168.1.102:80 check
```

---

## Next Steps

Sau khi hoàn thành Port Forwarding setup, bạn có thể tiến tới:

1. **[VPN Server Setup](../02-services/vpn-server.md)** - Secure remote access
2. **[Monitoring Setup](../02-services/monitoring.md)** - Monitor services
3. **[SSL Certificate Management](../02-services/ssl-certificates.md)** - HTTPS setup

---

## Tham khảo

- [Nginx Documentation](https://nginx.org/en/docs/)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [HAProxy Documentation](https://www.haproxy.org/download/1.8/doc/configuration.txt)
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/) 