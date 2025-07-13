# Harbor Container Registry Setup

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Installation Guide](#installation-guide)
- [Configuration](#configuration)
- [User Management](#user-management)
- [Project Management](#project-management)
- [Registry Operations](#registry-operations)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Integration with Other Services](#integration-with-other-services)

---

## Introduction

Harbor is an open-source container registry that secures artifacts with policies and role-based access control, ensures images are scanned and free from vulnerabilities, and signs images as trusted. This guide provides comprehensive instructions for setting up and managing Harbor registry.

### What is Harbor?

Harbor is a secure, performant, and scalable container registry that extends the open-source Docker Distribution. It provides:

- **Security**: Role-based access control, image vulnerability scanning, and content trust
- **Management**: Web-based UI, replication across registries, and activity auditing
- **Scalability**: High availability setup with load balancing capabilities
- **Compliance**: Helm chart repository, content trust, and policy enforcement

### Key Features

1. **Security & Compliance**
   - Role-based access control (RBAC)
   - Image vulnerability scanning with Trivy
   - Content signing and verification
   - Audit logging

2. **Multi-tenancy**
   - Project-based resource isolation
   - Quota management
   - User and group management

3. **Extensibility**
   - Webhook integration
   - API for automation
   - Multiple authentication backends

4. **High Availability**
   - Load balancing support
   - Database and storage backends
   - Replication across registries

---

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 40GB | 160GB+ |
| **Network** | 1 Gbps | 1 Gbps |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS
- **Docker**: 20.10.0 or later
- **Docker Compose**: 2.0.0 or later
- **OpenSSL**: For certificate generation
- **Domain**: DNS resolution for harbor domain

### Network Configuration

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| **HTTP** | 80 | TCP | Web UI (redirects to HTTPS) |
| **HTTPS** | 443 | TCP | Web UI and Docker registry |
| **PostgreSQL** | 5432 | TCP | Database (internal) |
| **Redis** | 6379 | TCP | Cache (internal) |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  Harbor Registry                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Load Balancer                           │ │
│  │                   (Nginx)                               │ │
│  │              registry.domain.com                        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                │                            │
│                                ▼                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Harbor Services                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │  │    Core     │  │   Portal    │  │  Job Service│    │ │
│  │  │    API      │  │   Web UI    │  │  (Scanning) │    │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │ │
│  │                                                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │  │ Registry    │  │   Notary    │  │    Trivy    │    │ │
│  │  │ (Storage)   │  │   (Signing) │  │ (Scanning)  │    │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                │                            │
│                                ▼                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Backend Services                           │ │
│  │  ┌─────────────────┐      ┌─────────────────┐          │ │
│  │  │   PostgreSQL    │      │      Redis      │          │ │
│  │  │   (Database)    │      │     (Cache)     │          │ │
│  │  └─────────────────┘      └─────────────────┘          │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Storage Backend                         │ │
│  │           (Local/S3/GCS/Azure Blob)                     │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Docker Clients      │
                    │                       │
                    │  • docker push        │
                    │  • docker pull        │
                    │  • helm install       │
                    └───────────────────────┘
```

---

## Installation Guide

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget gnupg lsb-release ca-certificates openssl

# Set timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Configure static IP (if needed)
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Apply network configuration
sudo netplan apply
```

### Step 2: Install Docker and Docker Compose

```bash
#!/bin/bash
# install-docker.sh

# Remove old versions
sudo apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official GPG key
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
docker compose version
```

### Step 3: Configure Docker Daemon

```bash
# Create Docker daemon configuration
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.ngtantai.pro"]
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### Step 4: Download Harbor

```bash
# Create Harbor directory
sudo mkdir -p /opt/harbor
cd /opt/harbor

# Download latest Harbor release
HARBOR_VERSION=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep -Po '"tag_name": "\K[^"]*')
wget https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz

# Extract Harbor
tar xzf harbor-offline-installer-${HARBOR_VERSION}.tgz
cd harbor/

# Set permissions
sudo chown -R $USER:$USER /opt/harbor
```

---

## Configuration

### Step 1: SSL Certificate Setup

```bash
# Create SSL directory
sudo mkdir -p /etc/harbor/ssl

# Generate private key
sudo openssl genrsa -out /etc/harbor/ssl/harbor.key 4096

# Create certificate signing request
sudo openssl req -new -key /etc/harbor/ssl/harbor.key -out /etc/harbor/ssl/harbor.csr -subj "/C=VN/ST=HCM/L=HCM/O=Harbor/CN=registry.ngtantai.pro"

# Generate self-signed certificate
sudo openssl x509 -req -days 365 -in /etc/harbor/ssl/harbor.csr -signkey /etc/harbor/ssl/harbor.key -out /etc/harbor/ssl/harbor.crt

# Set permissions
sudo chmod 600 /etc/harbor/ssl/harbor.key
sudo chmod 644 /etc/harbor/ssl/harbor.crt
```

### Step 2: Harbor Configuration

Create and configure `harbor.yml`:

```yaml
# Harbor configuration file
hostname: registry.ngtantai.pro

# HTTP configuration
http:
  port: 80

# HTTPS configuration
https:
  port: 443
  certificate: /etc/harbor/ssl/harbor.crt
  private_key: /etc/harbor/ssl/harbor.key

# Harbor admin password
harbor_admin_password: Harbor12345

# Database configuration
database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

# Data volume
data_volume: /data/harbor

# Trivy configuration
trivy:
  ignore_unfixed: false
  skip_update: false
  skip_java_db_update: false
  offline_scan: false
  security_check: vuln
  insecure: false
  timeout: 5m0s

# Job service configuration
jobservice:
  max_job_workers: 10
  max_job_duration_hours: 24
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1

# Webhook configuration
notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3

# Log configuration
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

# Proxy configuration
proxy:
  http_proxy:
  https_proxy:
  no_proxy:
  components:
    - core
    - jobservice
    - trivy

# Purge configuration
upload_purging:
  enabled: true
  age: 168h
  interval: 24h
  dryrun: false

# Cache configuration
cache:
  enabled: false
  expire_hours: 24

# Harbor version
_version: 2.13.0
```

### Step 3: Install Harbor

```bash
# Prepare Harbor
sudo ./prepare

# Install Harbor with all components
sudo ./install.sh --with-trivy --with-chartmuseum

# Verify installation
sudo docker compose ps
```

---

## User Management

### Admin User Setup

```bash
# Access Harbor web UI
# URL: https://registry.ngtantai.pro
# Username: admin
# Password: Harbor12345 (as configured)
```

### Create Users via UI

1. **Login as admin**
2. **Navigate to Users**
3. **Create New User**
   - Username: `developer`
   - Email: `developer@company.com`
   - Full Name: `Developer User`
   - Password: `SecurePassword123`
   - Confirm Password: `SecurePassword123`

### Create Users via API

```bash
# Create user via API
curl -X POST \
  'https://registry.ngtantai.pro/api/v2.0/users' \
  -H 'Content-Type: application/json' \
  -u 'admin:Harbor12345' \
  -d '{
    "username": "apiuser",
    "email": "apiuser@company.com",
    "password": "SecurePassword123",
    "realname": "API User"
  }'
```

---

## Project Management

### Create Projects

#### Via Web UI

1. **Navigate to Projects**
2. **Click "New Project"**
3. **Configure Project**:
   - Project Name: `myapp`
   - Access Level: `Private`
   - Storage Quota: `10GB`
   - Proxy Cache: `Disabled`

#### Via API

```bash
# Create project via API
curl -X POST \
  'https://registry.ngtantai.pro/api/v2.0/projects' \
  -H 'Content-Type: application/json' \
  -u 'admin:Harbor12345' \
  -d '{
    "project_name": "myapp",
    "public": false,
    "storage_limit": 10737418240,
    "registry_id": null
  }'
```

### Project Members

```bash
# Add member to project
curl -X POST \
  'https://registry.ngtantai.pro/api/v2.0/projects/myapp/members' \
  -H 'Content-Type: application/json' \
  -u 'admin:Harbor12345' \
  -d '{
    "role_id": 2,
    "member_user": {
      "username": "developer"
    }
  }'
```

### Project Roles

| Role | ID | Permissions |
|------|----|-----------| 
| **Project Admin** | 1 | Full project control |
| **Developer** | 2 | Push/pull images, manage repositories |
| **Guest** | 3 | Pull images only |
| **Maintainer** | 4 | Push/pull images, manage repositories |

---

## Registry Operations

### Docker Client Configuration

```bash
# Configure Docker to trust Harbor registry
sudo mkdir -p /etc/docker/certs.d/registry.ngtantai.pro
sudo cp /etc/harbor/ssl/harbor.crt /etc/docker/certs.d/registry.ngtantai.pro/ca.crt

# Restart Docker
sudo systemctl restart docker
```

### Image Operations

#### Login to Registry

```bash
# Login to Harbor registry
docker login registry.ngtantai.pro
# Username: admin
# Password: Harbor12345
```

#### Push Images

```bash
# Tag image for Harbor
docker tag nginx:latest registry.ngtantai.pro/myapp/nginx:latest

# Push image
docker push registry.ngtantai.pro/myapp/nginx:latest
```

#### Pull Images

```bash
# Pull image from Harbor
docker pull registry.ngtantai.pro/myapp/nginx:latest

# Run container
docker run -d -p 8080:80 registry.ngtantai.pro/myapp/nginx:latest
```

### Helm Chart Repository

```bash
# Add Harbor as Helm repository
helm repo add harbor https://registry.ngtantai.pro/chartrepo/myapp \
  --username admin \
  --password Harbor12345

# Update repositories
helm repo update

# Search charts
helm search repo harbor/

# Install chart
helm install my-app harbor/mychart
```

---

## Security Best Practices

### 1. SSL/TLS Configuration

```bash
# Use proper SSL certificates in production
# Let's Encrypt example:
sudo apt install -y certbot

# Generate certificate
sudo certbot certonly --standalone -d registry.ngtantai.pro

# Update harbor.yml with proper certificates
https:
  port: 443
  certificate: /etc/letsencrypt/live/registry.ngtantai.pro/fullchain.pem
  private_key: /etc/letsencrypt/live/registry.ngtantai.pro/privkey.pem
```

### 2. Access Control

```bash
# Configure RBAC policies
curl -X POST \
  'https://registry.ngtantai.pro/api/v2.0/projects/myapp/robot' \
  -H 'Content-Type: application/json' \
  -u 'admin:Harbor12345' \
  -d '{
    "name": "ci-robot",
    "description": "CI/CD Robot Account",
    "disable": false,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "myapp",
        "access": [
          {
            "resource": "repository",
            "action": "push"
          },
          {
            "resource": "repository", 
            "action": "pull"
          }
        ]
      }
    ]
  }'
```

### 3. Vulnerability Scanning

```bash
# Enable automatic scanning
curl -X PUT \
  'https://registry.ngtantai.pro/api/v2.0/projects/myapp' \
  -H 'Content-Type: application/json' \
  -u 'admin:Harbor12345' \
  -d '{
    "metadata": {
      "auto_scan": "true",
      "severity": "low"
    }
  }'
```

### 4. Content Trust

```bash
# Enable content trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://registry.ngtantai.pro:4443

# Push signed image
docker push registry.ngtantai.pro/myapp/nginx:signed
```

---

## Monitoring and Maintenance

### Health Monitoring

```bash
#!/bin/bash
# harbor-health-check.sh

HARBOR_URL="https://registry.ngtantai.pro"
API_URL="$HARBOR_URL/api/v2.0"

echo "Harbor Health Check - $(date)"
echo "=================================="

# Check Harbor API
if curl -k -s "$API_URL/health" | grep -q "healthy"; then
    echo "✓ Harbor API is healthy"
else
    echo "✗ Harbor API is unhealthy"
fi

# Check registry service
if curl -k -s "$HARBOR_URL/v2/" | grep -q "{}"; then
    echo "✓ Registry service is responding"
else
    echo "✗ Registry service is not responding"
fi

# Check database connection
if docker compose -f /opt/harbor/harbor/docker-compose.yml exec database psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo "✓ Database connection is healthy"
else
    echo "✗ Database connection failed"
fi

# Check storage usage
STORAGE_USAGE=$(df -h /data/harbor | awk 'NR==2{print $5}' | sed 's/%//g')
if [ "$STORAGE_USAGE" -lt 80 ]; then
    echo "✓ Storage usage: ${STORAGE_USAGE}%"
else
    echo "⚠ Storage usage high: ${STORAGE_USAGE}%"
fi
```

### Backup Strategy

```bash
#!/bin/bash
# harbor-backup.sh

BACKUP_DIR="/backup/harbor"
DATE=$(date +%Y%m%d_%H%M%S)
HARBOR_DIR="/opt/harbor/harbor"

# Create backup directory
mkdir -p $BACKUP_DIR

# Stop Harbor
cd $HARBOR_DIR
docker compose down

# Backup database
docker compose up -d database
sleep 30
docker compose exec database pg_dump -U postgres registry > $BACKUP_DIR/harbor_db_$DATE.sql

# Backup configuration
cp harbor.yml $BACKUP_DIR/harbor_config_$DATE.yml
cp -r /etc/harbor/ssl $BACKUP_DIR/ssl_$DATE

# Backup data
tar -czf $BACKUP_DIR/harbor_data_$DATE.tar.gz /data/harbor

# Restart Harbor
docker compose up -d

# Compress SQL backup
gzip $BACKUP_DIR/harbor_db_$DATE.sql

# Remove old backups (keep last 7 days)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.yml" -mtime +7 -delete
find $BACKUP_DIR -name "ssl_*" -mtime +7 -exec rm -rf {} \;

echo "Backup completed: $DATE"
```

### Log Management

```bash
# View Harbor logs
cd /opt/harbor/harbor
docker compose logs -f

# View specific service logs
docker compose logs -f core
docker compose logs -f registry
docker compose logs -f jobservice

# Log rotation setup
sudo tee /etc/logrotate.d/harbor > /dev/null <<EOF
/var/log/harbor/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        docker compose -f /opt/harbor/harbor/docker-compose.yml restart log
    endscript
}
EOF
```

---

## Troubleshooting

### Common Issues

#### 1. Certificate Issues

```bash
# Check certificate validity
openssl x509 -in /etc/harbor/ssl/harbor.crt -text -noout

# Verify certificate chain
openssl verify -CAfile /etc/harbor/ssl/ca.crt /etc/harbor/ssl/harbor.crt

# Check Docker trust
docker system info | grep -i registry
```

#### 2. Storage Issues

```bash
# Check disk usage
df -h /data/harbor

# Clean up unused images
docker system prune -a

# Check Harbor storage
curl -k -u admin:Harbor12345 https://registry.ngtantai.pro/api/v2.0/statistics
```

#### 3. Database Issues

```bash
# Check database connectivity
docker compose exec database psql -U postgres -c "SELECT version();"

# Check database size
docker compose exec database psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('registry'));"

# Database vacuum
docker compose exec database psql -U postgres -c "VACUUM ANALYZE;"
```

#### 4. Performance Issues

```bash
# Check resource usage
docker stats

# Monitor Harbor services
docker compose top

# Check slow queries
docker compose exec database psql -U postgres -c "SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

---

## Integration with Other Services

### 1. CI/CD Integration

```yaml
# GitLab CI example
stages:
  - build
  - deploy

variables:
  REGISTRY: registry.ngtantai.pro
  IMAGE_NAME: $REGISTRY/myapp/app

build:
  stage: build
  script:
    - echo "$HARBOR_PASSWORD" | docker login -u "$HARBOR_USERNAME" --password-stdin $REGISTRY
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
    - docker push $IMAGE_NAME:latest
```

### 2. Kubernetes Integration

```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: app
        image: registry.ngtantai.pro/myapp/app:latest
        ports:
        - containerPort: 8080
```

### 3. Monitoring Integration

```yaml
# prometheus.yml
- job_name: 'harbor'
  static_configs:
    - targets: ['registry.ngtantai.pro:8080']
  metrics_path: '/api/v2.0/metrics'
  basic_auth:
    username: admin
    password: Harbor12345
```

---

## Next Steps

After successful Harbor setup:

1. **Configure Replication**: Set up image replication to other registries
2. **Implement Backup**: Schedule regular backups and test recovery
3. **Security Hardening**: Configure proper SSL certificates and access controls
4. **Performance Optimization**: Monitor and optimize based on usage patterns
5. **Integration Testing**: Test with CI/CD pipelines and Kubernetes

For more advanced topics, refer to:
- [VPN Server Setup](vpn-server.md)
- [Database Setup](database-mongodb.md)
- [Monitoring Setup](monitoring-setup.md)

---

## Conclusion

Harbor provides a robust, secure, and feature-rich container registry solution that integrates well with modern DevOps workflows. The setup described in this guide provides a solid foundation for managing container images in production environments.

Regular maintenance, monitoring, and security updates are essential for maintaining a healthy and secure registry. The comprehensive features of Harbor, including vulnerability scanning, content trust, and RBAC, make it an excellent choice for organizations requiring enterprise-grade container management capabilities. 