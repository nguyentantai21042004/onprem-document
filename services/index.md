# Hướng Dẫn Triển Khai Services

## 📋 Tổng Quan

Phần này cung cấp tài liệu toàn diện để triển khai các dịch vụ cốt lõi trên infrastructure on-premise của bạn. Các hướng dẫn bao gồm VPN, databases, container registry, và monitoring stack hoàn chỉnh.

##  Tổng Quan Kiến Trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                      Tầng Services                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Bảo mật & VPN                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  OpenVPN    │  │    OVPM     │  │  Web GUI    │     │   │
│  │  │   Server    │  │ Management  │  │ Interface   │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Cơ sở Dữ liệu                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │   MongoDB   │  │ PostgreSQL  │  │ High Avail  │     │   │
│  │  │ Replica Set │  │   Repmgr    │  │ Clustering  │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Container Registry                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │   Harbor    │  │ Image Scan  │  │   Helm      │     │   │
│  │  │  Registry   │  │   Trivy     │  │  Charts     │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Monitoring Stack                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │ Prometheus  │  │   Grafana   │  │Alertmanager │     │   │
│  │  │  Metrics    │  │ Dashboards  │  │   Alerts    │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

##  Cấu Trúc Tài Liệu

### 1. [VPN Server](vpn-server.md)
**Tầng Bảo mật - Truy cập An toàn**
-  Cài đặt OpenVPN server với OVPM tool
-  Web interface cho user management
-  Certificate management tự động
-  User authentication và authorization
-  Network routing và firewall configuration
-  Performance tuning và monitoring

**Yêu cầu tiên quyết**: Ubuntu server với public IP

### 2. [MongoDB Database](database-mongodb.md)
**Tầng Dữ liệu - NoSQL High Availability**
-  MongoDB replica set với 3 nodes
-  Automatic failover và recovery
-  Data replication và consistency
-  Backup strategies và restore procedures
-  Performance monitoring và optimization
-  Security hardening và authentication

**Yêu cầu tiên quyết**: 3 Ubuntu servers cho HA setup

### 3. [PostgreSQL Database](database-postgresql.md)
**Tầng Dữ liệu - SQL High Availability**
-  PostgreSQL primary-standby với repmgr
-  Automatic failover với witness node
-  Streaming replication configuration
-  Connection pooling với pgbouncer
-  Backup automation với pg_dump
-  Performance tuning và monitoring

**Yêu cầu tiên quyết**: 3 Ubuntu servers cho cluster setup

### 4. [Harbor Container Registry](container-registry.md)
**Tầng Container - Image Management**
-  Harbor installation với Docker Compose
-  RBAC và project management
-  Container image vulnerability scanning
-  Helm chart repository support
-  Docker registry API compatibility
-  Integration với Kubernetes clusters

**Yêu cầu tiên quyết**: Docker và Docker Compose

### 5. [Monitoring Setup](monitoring-setup.md)
**Tầng Giám sát - Observability Stack**
-  Prometheus cho metrics collection
-  Grafana dashboards và visualization
-  Alertmanager cho notification routing
-  Node Exporter cho system metrics
-  Custom dashboards cho services
-  Alert rules và notification channels

**Yêu cầu tiên quyết**: Services đã deployed để monitor

##  Lộ Trình Triển Khai

### Giai đoạn 1: Dịch vụ Cốt lõi (Ngày 1-2)
1. **Bảo mật** → [vpn-server.md](vpn-server.md) - Thiết lập truy cập an toàn
2. **Database** → [database-mongodb.md](database-mongodb.md) - NoSQL cho applications
3. **Database** → [database-postgresql.md](database-postgresql.md) - SQL cho structured data
4. **Registry** → [container-registry.md](container-registry.md) - Container image storage

**Thời gian ước tính**: 1-2 ngày
**Cấp độ kỹ năng**: Trung cấp

### Giai đoạn 2: Monitoring & Optimization (Ngày 3)
1. **Monitoring** → [monitoring-setup.md](monitoring-setup.md) - Full observability stack
2. **Integration** → Tích hợp tất cả services với monitoring
3. **Testing** → Load testing và performance validation
4. **Documentation** → Hoàn thiện operational procedures

**Thời gian ước tính**: 1 ngày
**Cấp độ kỹ năng**: Nâng cao

### Giai đoạn 3: Production Ready (Ongoing)
1. **Security** → Hardening tất cả services
2. **Backup** → Automated backup strategies
3. **Scaling** → Horizontal scaling configuration
4. **Optimization** → Performance tuning

**Thời gian ước tính**: Ongoing
**Cấp độ kỹ năng**: Expert

##  Tham Khảo Nhanh

### Địa chỉ IP Services
```bash
# VPN Server
VPN_SERVER="192.168.1.201"

# MongoDB Replica Set
MONGO_PRIMARY="192.168.1.20"
MONGO_SECONDARY_1="192.168.1.21"  
MONGO_SECONDARY_2="192.168.1.22"

# PostgreSQL Cluster
PG_PRIMARY="192.168.1.202"
PG_STANDBY="192.168.1.203"
PG_WITNESS="192.168.1.204"

# Harbor Registry
HARBOR_SERVER="192.168.1.205"

# Monitoring Stack
PROMETHEUS_SERVER="192.168.1.206"
GRAFANA_SERVER="192.168.1.207"
```

### Service URLs
```bash
# VPN Management
https://192.168.1.201:8080  # OVPM Web Interface

# Databases
mongodb://192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017
postgresql://192.168.1.202:5432

# Container Registry  
https://harbor.ngtantai.pro  # Harbor Web UI
docker login harbor.ngtantai.pro

# Monitoring
https://192.168.1.206:9090   # Prometheus
https://192.168.1.207:3000   # Grafana
https://192.168.1.206:9093   # Alertmanager
```

### Health Check Commands
```bash
# VPN Server Status
systemctl status openvpn-server@server
curl -k https://192.168.1.201:8080/api/status

# MongoDB Cluster Status
mongo --host rs0/192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017 \
  --eval "rs.status()"

# PostgreSQL Cluster Status
repmgr -f /etc/repmgr.conf cluster show

# Harbor Registry Status
curl -k https://harbor.ngtantai.pro/api/v2.0/health

# Monitoring Stack Status
curl http://192.168.1.206:9090/-/healthy
curl http://192.168.1.207:3000/api/health
```

##  Service Endpoints

### VPN Server Configuration
```bash
# OpenVPN Client Configuration
client
dev tun
proto udp
remote vpn.ngtantai.pro 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
cipher AES-256-CBC
auth SHA256
verb 3
```

### Database Connections
```javascript
// MongoDB Connection String
const mongoUri = "mongodb://username:password@192.168.1.20:27017,192.168.1.21:27017,192.168.1.22:27017/database_name?replicaSet=rs0";

// PostgreSQL Connection
const pgConfig = {
  host: '192.168.1.202',
  port: 5432,
  database: 'app_database',
  user: 'app_user',
  password: 'secure_password',
  ssl: true
};
```

### Container Registry Usage
```bash
# Login to Harbor
docker login harbor.ngtantai.pro
Username: admin
Password: Harbor12345

# Push image to Harbor
docker tag myapp:latest harbor.ngtantai.pro/myproject/myapp:latest
docker push harbor.ngtantai.pro/myproject/myapp:latest

# Pull image from Harbor
docker pull harbor.ngtantai.pro/myproject/myapp:latest
```

##  Checklist Validation

### VPN Server
- [ ] OpenVPN server đang chạy
- [ ] OVPM web interface accessible
- [ ] Client certificates generated
- [ ] Network routing configured
- [ ] Firewall rules applied
- [ ] User authentication working

### MongoDB Cluster
- [ ] 3 nodes cluster deployed
- [ ] Replica set configuration active
- [ ] Primary/secondary roles assigned
- [ ] Automatic failover tested
- [ ] Backup procedures configured
- [ ] Monitoring alerts setup

### PostgreSQL Cluster  
- [ ] Primary-standby replication working
- [ ] Repmgr automatic failover configured
- [ ] Connection pooling active
- [ ] Backup automation working
- [ ] Performance monitoring enabled
- [ ] Security hardening applied

### Harbor Registry
- [ ] Harbor web interface accessible
- [ ] Project và user management configured
- [ ] Container scanning enabled
- [ ] RBAC policies applied
- [ ] Helm chart repository working
- [ ] Integration với Docker tested

### Monitoring Stack
- [ ] Prometheus collecting metrics
- [ ] Grafana dashboards configured
- [ ] Alertmanager routing notifications
- [ ] All services monitored
- [ ] Alert rules configured
- [ ] Notification channels tested

## 🔗 Điểm Tích hợp

### Với Tầng Infrastructure
- Network configuration từ infrastructure setup
- VM placement và resource allocation
- Security certificates và domain setup
- Storage configuration cho data persistence

### Với Tầng Kubernetes
- Container images từ Harbor registry
- Database connections cho applications
- VPN access cho cluster management
- Monitoring integration cho K8s metrics

### Với Tầng CI/CD
- Harbor registry cho container storage
- Database setup cho application data
- VPN cho secure CI/CD access
- Monitoring cho pipeline health

##  Tối Ưu Performance

### Database Optimization
```sql
-- PostgreSQL Performance Tuning
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.7
wal_buffers = 16MB
```

```javascript
// MongoDB Performance Settings
db.adminCommand({
  setParameter: 1,
  wiredTigerConcurrentReadTransactions: 128,
  wiredTigerConcurrentWriteTransactions: 128
});
```

### Container Registry Optimization
```yaml
# Harbor Performance Configuration
storage:
  cache:
    blobdescriptor: redis
    blobdescriptorsize: 10000
  redirect:
    disable: true
```

### Monitoring Optimization
```yaml
# Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  
rule_files:
  - "alert_rules.yml"
  
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 5s
```

##  Best Practices Bảo mật

### Network Security
```bash
# UFW Firewall Rules
ufw allow from 192.168.1.0/24 to any port 27017  # MongoDB
ufw allow from 192.168.1.0/24 to any port 5432   # PostgreSQL
ufw allow 443/tcp                                 # HTTPS Harbor
ufw allow 1194/udp                                # OpenVPN
```

### Database Security
```sql
-- PostgreSQL Security
CREATE USER app_user WITH PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE app_db TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
```

```javascript
// MongoDB Security
use admin
db.createUser({
  user: "app_user",
  pwd: "strong_password", 
  roles: [
    { role: "readWrite", db: "app_database" }
  ]
});
```

### Container Security
```yaml
# Harbor Security Configuration
registry:
  auth:
    token:
      issuer: harbor-token-issuer
      service: harbor-registry
  validation:
    disabled: false
security:
  checkov: true
  trivy: true
```

##  Hỗ trợ và Troubleshooting

### Vấn đề Thường gặp

#### 1. VPN Connection Issues
```bash
# Check OpenVPN logs
journalctl -u openvpn-server@server -f

# Test VPN connectivity
ping 10.8.0.1
traceroute 10.8.0.1
```

#### 2. Database Connection Problems
```bash
# MongoDB connectivity
mongo --host 192.168.1.20:27017 --eval "db.runCommand('ping')"

# PostgreSQL connectivity  
psql -h 192.168.1.202 -U postgres -c "SELECT version();"
```

#### 3. Harbor Registry Issues
```bash
# Check Harbor services
docker-compose -f harbor.yml ps
docker-compose -f harbor.yml logs harbor-core
```

#### 4. Monitoring Problems
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify Grafana datasource
curl -X GET http://admin:admin@localhost:3000/api/datasources
```

### Recovery Procedures

#### Database Recovery
```bash
# MongoDB Replica Set Recovery
mongo --host 192.168.1.20:27017 --eval "rs.stepDown()"
mongo --host 192.168.1.21:27017 --eval "rs.slaveOk(); rs.status()"

# PostgreSQL Failover
repmgr -f /etc/repmgr.conf standby promote
repmgr -f /etc/repmgr.conf cluster show
```

#### Service Recovery
```bash
# Restart critical services
systemctl restart openvpn-server@server
systemctl restart mongod
systemctl restart postgresql
docker-compose -f harbor.yml restart
```

##  Bước Tiếp theo

Sau khi hoàn thành phần Services này, tiếp tục với:
1. **[03-Kubernetes](../03-kubernetes/index.md)** - Container orchestration platform
2. **[04-CI/CD](../04-cicd/index.md)** - Automated deployment pipelines
3. **[05-Config-Templates](../05-config-templates/index.md)** - Ready-to-use configurations

---

**Lưu ý**: Services là trái tim của infrastructure. Đảm bảo tất cả services hoạt động ổn định và có monitoring đầy đủ trước khi triển khai Kubernetes.

**Triết lý**: **Dịch vụ Ổn định → Dữ liệu An toàn → Giám sát Toàn diện → Tự động hóa Thông minh** 