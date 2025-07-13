# 02-services - Core Services Setup

## Overview

This section covers the setup and configuration of core services that form the backbone of your on-premise server infrastructure. These services provide essential functionality including VPN access, database storage, container registry, and comprehensive monitoring.

## Services Included

### 🔐 VPN Server
- **Purpose**: Secure remote access to your infrastructure
- **Technology**: OpenVPN with OVPM management
- **Features**: Web-based management, user provisioning, certificate management
- **Documentation**: [VPN Server Setup](vpn-server.md)

### 🗄️ Database Services
- **MongoDB Replica Set**: High-availability NoSQL database cluster
- **PostgreSQL with Repmgr**: Relational database with automatic failover
- **Features**: Clustering, replication, backup strategies, monitoring
- **Documentation**: [MongoDB Setup](database-mongodb.md) | [PostgreSQL Setup](database-postgresql.md)

### 🐳 Container Registry
- **Purpose**: Private Docker image registry with security scanning
- **Technology**: Harbor with Trivy integration
- **Features**: RBAC, vulnerability scanning, Helm chart storage
- **Documentation**: [Container Registry Setup](container-registry.md)

### 📊 Monitoring Stack
- **Purpose**: Comprehensive infrastructure and application monitoring
- **Technology**: Prometheus, Grafana, Alertmanager
- **Features**: Metrics collection, visualization, alerting, dashboards
- **Documentation**: [Monitoring Setup](monitoring-setup.md)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Services Layer                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  VPN Services                           │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   OpenVPN   │  │    OVPM     │  │  Web Portal │     │ │
│  │  │   Server    │  │  Manager    │  │   :943      │     │ │
│  │  │   :1194     │  │   :8080     │  │             │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Database Services                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │  MongoDB    │  │  MongoDB    │  │  MongoDB    │     │ │
│  │  │  Primary    │  │ Secondary   │  │ Secondary   │     │ │
│  │  │   :27017    │  │   :27017    │  │   :27017    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │                                                         │ │
│  │  ┌─────────────┐  ┌─────────────┐                      │ │
│  │  │PostgreSQL   │  │PostgreSQL   │                      │ │
│  │  │  Primary    │  │   Standby   │                      │ │
│  │  │   :5432     │  │   :5432     │                      │ │
│  │  └─────────────┘  └─────────────┘                      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Container Registry                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Harbor    │  │   Trivy     │  │  Chartmuseum│     │ │
│  │  │   Core      │  │  Scanner    │  │    Helm     │     │ │
│  │  │   :443      │  │   :8080     │  │   Charts    │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Monitoring Stack                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │ Prometheus  │  │   Grafana   │  │Alertmanager │     │ │
│  │  │   :9090     │  │   :3000     │  │   :9093     │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Order

### Phase 1: VPN Setup (Priority: High)
1. **Start with VPN Server** - Essential for secure remote access
2. **Configure OpenVPN** - Basic VPN functionality
3. **Setup OVPM** - Web-based management interface
4. **Test connectivity** - Verify remote access works

### Phase 2: Database Services (Priority: High)
1. **MongoDB Replica Set** - NoSQL database cluster
2. **PostgreSQL with Repmgr** - SQL database with HA
3. **Configure replication** - Ensure data redundancy
4. **Setup backup strategies** - Data protection

### Phase 3: Container Registry (Priority: Medium)
1. **Harbor installation** - Private registry setup
2. **SSL configuration** - Secure registry access
3. **User management** - RBAC implementation
4. **Integration testing** - Docker push/pull operations

### Phase 4: Monitoring Stack (Priority: Medium)
1. **Prometheus setup** - Metrics collection
2. **Grafana configuration** - Dashboard creation
3. **Alertmanager setup** - Notification system
4. **Exporter deployment** - Metrics from all services

---

## Service Dependencies

### VPN Server
- **Dependencies**: None (standalone service)
- **Ports**: 1194 (OpenVPN), 943 (Web UI), 8080 (OVPM)
- **Integrates with**: All services (provides access)

### Database Services
- **Dependencies**: Network connectivity between nodes
- **Ports**: 27017 (MongoDB), 5432 (PostgreSQL)
- **Integrates with**: Applications, monitoring

### Container Registry
- **Dependencies**: Docker, SSL certificates
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Integrates with**: CI/CD, Kubernetes, monitoring

### Monitoring Stack
- **Dependencies**: All services (for monitoring)
- **Ports**: 9090 (Prometheus), 3000 (Grafana), 9093 (Alertmanager)
- **Integrates with**: All services, notification systems

---

## Configuration Files

### VPN Server
- `ovpn-server.conf` - OpenVPN server configuration
- `ovpm.conf` - OVPM management configuration
- `client.ovpn` - Client configuration template

### Database Services
- `mongod.conf` - MongoDB configuration
- `postgresql.conf` - PostgreSQL configuration
- `repmgr.conf` - Repmgr configuration

### Container Registry
- `harbor.yml` - Harbor configuration
- `docker-compose.yml` - Container orchestration

### Monitoring Stack
- `prometheus.yml` - Prometheus configuration
- `grafana.ini` - Grafana configuration
- `alertmanager.yml` - Alertmanager configuration

---

## Security Considerations

### Access Control
- **VPN**: Certificate-based authentication
- **Databases**: Role-based access control
- **Registry**: RBAC with project isolation
- **Monitoring**: Basic authentication with secure passwords

### Network Security
- **Firewall**: UFW rules for each service
- **SSL/TLS**: Encrypted communication
- **VPN**: Secure tunneling for remote access

### Data Protection
- **Databases**: Encryption at rest and in transit
- **Registry**: Image vulnerability scanning
- **Monitoring**: Secure metrics collection

---

## Monitoring Integration

Each service includes monitoring integration:

### Metrics Collection
- **Node Exporter**: System metrics for all VMs
- **Database Exporters**: MongoDB and PostgreSQL metrics
- **Harbor Metrics**: Registry-specific metrics
- **Custom Metrics**: Application-specific measurements

### Alerting Rules
- **System Alerts**: CPU, memory, disk usage
- **Service Alerts**: Database replication, VPN connectivity
- **Security Alerts**: Failed authentication attempts
- **Performance Alerts**: Response time degradation

### Dashboards
- **System Overview**: Infrastructure-wide metrics
- **Database Dashboard**: Database-specific metrics
- **Service Health**: Application status monitoring
- **Network Dashboard**: VPN and connectivity metrics

---

## Backup and Recovery

### VPN Server
- **Configuration backup**: OpenVPN and OVPM configs
- **Certificate backup**: CA and client certificates
- **User data backup**: User profiles and settings

### Database Services
- **Automated backups**: Daily database dumps
- **Replication**: Real-time data synchronization
- **Point-in-time recovery**: Transaction log archiving

### Container Registry
- **Image backup**: Registry storage backup
- **Configuration backup**: Harbor settings
- **Database backup**: Registry metadata

### Monitoring Stack
- **Metrics backup**: Prometheus data export
- **Dashboard backup**: Grafana dashboard exports
- **Configuration backup**: All service configs

---

## Troubleshooting

### Common Issues
1. **Service connectivity**: Network and firewall configuration
2. **Authentication failures**: Certificate and password issues
3. **Resource constraints**: CPU, memory, and disk limitations
4. **Configuration errors**: Syntax and parameter validation

### Debug Tools
- **Log analysis**: Centralized logging with monitoring
- **Network testing**: Connectivity verification tools
- **Performance monitoring**: Resource usage tracking
- **Health checks**: Service status validation

### Support Resources
- **Documentation**: Comprehensive setup guides
- **Community**: Open-source project communities
- **Professional support**: Enterprise support options

---

## Next Steps

After completing the 02-services setup:

1. **Proceed to 03-kubernetes**: Container orchestration setup
2. **Implement 04-cicd**: Continuous integration/deployment
3. **Configure integrations**: Service-to-service communication
4. **Security hardening**: Advanced security configurations
5. **Performance optimization**: Tuning for production workloads

---

## Quick Reference

### Service URLs
- **VPN Management**: `https://192.168.1.210:943`
- **OVPM Interface**: `http://192.168.1.210:8080`
- **Harbor Registry**: `https://registry.ngtantai.pro`
- **Grafana Dashboard**: `http://192.168.1.100:3000`
- **Prometheus**: `http://192.168.1.100:9090`

### Default Credentials
- **VPN Admin**: `admin` / `configured_password`
- **Harbor Admin**: `admin` / `Harbor12345`
- **Grafana**: `admin` / `admin123`
- **Database**: As configured during setup

### Health Check Commands
```bash
# VPN connectivity
ping 192.168.1.210

# Database connectivity
mongosh --host 192.168.1.20 --port 27017
psql -h 192.168.1.202 -U postgres

# Registry connectivity
docker login registry.ngtantai.pro

# Monitoring services
curl http://192.168.1.100:9090/-/healthy
```

---

## Conclusion

The 02-services layer provides the essential infrastructure services needed for a complete on-premise server setup. Each service is designed to be highly available, secure, and well-monitored. The modular approach allows for independent deployment and scaling of each component.

Follow the documentation for each service to ensure proper configuration and integration. The monitoring stack provides visibility into all services, enabling proactive maintenance and troubleshooting. 