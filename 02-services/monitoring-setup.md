# Comprehensive Monitoring Setup with Prometheus Stack

## Table of Contents

- [Introduction](#introduction)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Infrastructure Setup](#infrastructure-setup)
- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Setup](#grafana-setup)
- [Alertmanager Configuration](#alertmanager-configuration)
- [Exporters and Metrics](#exporters-and-metrics)
- [Dashboard Creation](#dashboard-creation)
- [Alerting and Notifications](#alerting-and-notifications)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Integration with Other Services](#integration-with-other-services)

---

## Introduction

This guide provides a complete implementation of a centralized monitoring system using the Prometheus ecosystem. The setup includes Prometheus for metrics collection, Grafana for visualization, and Alertmanager for alerting, creating a robust monitoring solution for your infrastructure.

### What You'll Build

A complete monitoring stack that includes:

- **Prometheus Server**: Time-series database and metrics collection
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **Node Exporter**: System metrics collection
- **Custom Exporters**: Application-specific metrics
- **Discord/Slack Integration**: Alert notifications

### Key Benefits

1. **Centralized Monitoring**: Single pane of glass for all metrics
2. **Real-time Alerting**: Immediate notification of issues
3. **Historical Analysis**: Trend analysis and capacity planning
4. **Scalable Architecture**: Easy to add new services and metrics
5. **Rich Visualization**: Beautiful dashboards and reports

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ESXi Infrastructure                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Monitored Services                      │   │
│  │                                                      │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │    VPN     │  │  MongoDB   │  │PostgreSQL  │     │   │
│  │  │ :9100      │  │ :9216      │  │ :9187      │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  │                                                      │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │   Harbor   │  │   Nginx    │  │   Docker   │     │   │
│  │  │ :8080      │  │ :9113      │  │ :9323      │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                │                            │
│                                ▼                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Monitoring VM (192.168.1.100)               │   │
│  │                                                      │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │              Prometheus Stack                   │ │   │
│  │  │                                                 │ │   │
│  │  │  ┌────────────┐  ┌────────────┐  ┌──────────┐  │ │   │
│  │  │  │Prometheus  │  │  Grafana   │  │Alertmgr  │  │ │   │
│  │  │  │  :9090     │  │  :3000     │  │  :9093   │  │ │   │
│  │  │  └────────────┘  └────────────┘  └──────────┘  │ │   │
│  │  │                                                 │ │   │
│  │  │  ┌────────────┐  ┌────────────┐  ┌──────────┐  │ │   │
│  │  │  │Node Export │  │BlackBox    │  │  cAdvisor│  │ │   │
│  │  │  │  :9100     │  │  :9115     │  │  :8080   │  │ │   │
│  │  │  └────────────┘  └────────────┘  └──────────┘  │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │    Notification       │
                    │                       │
                    │  • Discord Webhook    │
                    │  • Slack Integration  │
                    │  • Email Alerts       │
                    │  • PagerDuty          │
                    └───────────────────────┘
```

---

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 50GB | 100GB+ |
| **Network** | 1 Gbps | 1 Gbps |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS
- **Docker**: 20.10.0 or later
- **Docker Compose**: 2.0.0 or later
- **Static IP**: For monitoring server

### Network Configuration

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| **Prometheus** | 9090 | TCP | Web UI and API |
| **Grafana** | 3000 | TCP | Web UI |
| **Alertmanager** | 9093 | TCP | Alert management |
| **Node Exporter** | 9100 | TCP | System metrics |
| **Blackbox Exporter** | 9115 | TCP | Endpoint monitoring |

---

## Infrastructure Setup

### Step 1: Create Monitoring VM

```bash
# VM Configuration in ESXi
VM_NAME="monitoring-vm"
RAM="4096"  # 4GB
CPU="2"     # 2 cores
DISK="50"   # 50GB
IP="192.168.1.100"
```

### Step 2: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget vim htop net-tools jq git

# Configure timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Configure static IP
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: false
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

# Apply network configuration
sudo netplan apply
```

### Step 3: Install Docker and Docker Compose

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

# Configure Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

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

### Step 4: Setup Project Structure

```bash
# Create project directory
sudo mkdir -p /opt/monitoring-stack
sudo chown $USER:$USER /opt/monitoring-stack
cd /opt/monitoring-stack

# Create directory structure
mkdir -p {prometheus,grafana,alertmanager,data,configs,dashboards}
mkdir -p grafana/provisioning/{datasources,dashboards}
mkdir -p data/{prometheus,grafana,alertmanager}

# Set proper permissions
sudo chown -R 472:472 data/grafana      # Grafana user
sudo chown -R 65534:65534 data/prometheus  # Nobody user
sudo chown -R 65534:65534 data/alertmanager

# Create logs directory
sudo mkdir -p /var/log/monitoring
sudo chown $USER:$USER /var/log/monitoring
```

---

## Prometheus Configuration

### Step 1: Prometheus Configuration File

Create `prometheus/prometheus.yml`:

```yaml
# Global configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s
  external_labels:
    monitor: 'production-monitor'
    datacenter: 'homelab'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

# Rule files
rule_files:
  - "alert_rules.yml"
  - "recording_rules.yml"

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: /metrics
    scrape_interval: 15s

  # Node Exporter (System metrics)
  - job_name: 'node-exporter'
    static_configs:
      - targets: 
        - '192.168.1.100:9100'  # Monitoring server
        - '192.168.1.210:9100'  # VPN server
        - '192.168.1.20:9100'   # MongoDB primary
        - '192.168.1.21:9100'   # MongoDB secondary
        - '192.168.1.22:9100'   # MongoDB secondary
        - '192.168.1.202:9100'  # PostgreSQL primary
        - '192.168.1.203:9100'  # PostgreSQL standby
    scrape_interval: 15s
    metrics_path: /metrics

  # MongoDB Exporter
  - job_name: 'mongodb'
    static_configs:
      - targets:
        - '192.168.1.20:9216'
        - '192.168.1.21:9216'
        - '192.168.1.22:9216'
    scrape_interval: 30s
    metrics_path: /metrics

  # PostgreSQL Exporter
  - job_name: 'postgresql'
    static_configs:
      - targets:
        - '192.168.1.202:9187'
        - '192.168.1.203:9187'
    scrape_interval: 30s
    metrics_path: /metrics

  # Harbor Registry
  - job_name: 'harbor'
    static_configs:
      - targets: ['192.168.1.100:8080']
    metrics_path: '/api/v2.0/metrics'
    scrape_interval: 30s
    basic_auth:
      username: 'admin'
      password: 'Harbor12345'

  # Docker containers
  - job_name: 'docker'
    static_configs:
      - targets:
        - '192.168.1.100:9323'
        - '192.168.1.210:9323'
    scrape_interval: 30s

  # Blackbox Exporter (Endpoint monitoring)
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://registry.ngtantai.pro
        - http://192.168.1.100:3000
        - http://192.168.1.210:943
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # Blackbox Exporter (ICMP monitoring)
  - job_name: 'blackbox-icmp'
    metrics_path: /probe
    params:
      module: [icmp]
    static_configs:
      - targets:
        - 192.168.1.1    # Gateway
        - 192.168.1.210  # VPN
        - 192.168.1.20   # MongoDB
        - 192.168.1.202  # PostgreSQL
        - 8.8.8.8        # External DNS
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  # Custom application metrics
  - job_name: 'custom-apps'
    static_configs:
      - targets:
        - '192.168.1.210:8080'  # Custom app metrics
    scrape_interval: 30s
    metrics_path: /metrics

# Remote write configuration (for long-term storage)
# remote_write:
#   - url: "http://thanos-receive:19291/api/v1/receive"
#     queue_config:
#       capacity: 2500
#       max_shards: 200
#       min_shards: 1
#       max_samples_per_send: 500
#       batch_send_deadline: 5s
#       min_backoff: 30ms
#       max_backoff: 100ms
```

### Step 2: Alert Rules

Create `prometheus/alert_rules.yml`:

```yaml
groups:
  - name: system.rules
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }}"

      # High Memory usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 80% on {{ $labels.instance }}"

      # Low disk space
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 10% on {{ $labels.instance }}"

      # Instance down
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instance is down"
          description: "{{ $labels.instance }} has been down for more than 5 minutes"

  - name: database.rules
    rules:
      # MongoDB replica set issues
      - alert: MongoDBReplicaSetDown
        expr: mongodb_replset_member_state != 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "MongoDB replica set member is down"
          description: "MongoDB replica set member {{ $labels.instance }} is in state {{ $value }}"

      # PostgreSQL replication lag
      - alert: PostgreSQLReplicationLag
        expr: pg_replication_lag > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL replication lag is high"
          description: "PostgreSQL replication lag is {{ $value }} seconds on {{ $labels.instance }}"

      # Database connection issues
      - alert: DatabaseConnectionHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connections"
          description: "PostgreSQL has {{ $value }} active connections on {{ $labels.instance }}"

  - name: application.rules
    rules:
      # Harbor registry issues
      - alert: HarborDown
        expr: up{job="harbor"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Harbor registry is down"
          description: "Harbor registry is not responding"

      # VPN server issues
      - alert: VPNServerDown
        expr: up{job="blackbox-http",instance="http://192.168.1.210:943"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "VPN server is down"
          description: "VPN server web interface is not responding"

      # SSL certificate expiry
      - alert: SSLCertificateExpiry
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "SSL certificate will expire soon"
          description: "SSL certificate for {{ $labels.instance }} expires in {{ $value | humanizeDuration }}"

  - name: network.rules
    rules:
      # Network connectivity issues
      - alert: NetworkConnectivityLoss
        expr: probe_success{job="blackbox-icmp"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Network connectivity lost"
          description: "Cannot reach {{ $labels.instance }}"

      # High network traffic
      - alert: HighNetworkTraffic
        expr: rate(node_network_receive_bytes_total[5m]) > 100000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High network traffic"
          description: "Network traffic is high on {{ $labels.instance }}"
```

### Step 3: Recording Rules

Create `prometheus/recording_rules.yml`:

```yaml
groups:
  - name: cpu.rules
    interval: 30s
    rules:
      - record: instance:cpu_usage:rate5m
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

      - record: instance:cpu_usage:rate1m
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)

  - name: memory.rules
    interval: 30s
    rules:
      - record: instance:memory_usage:percentage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

      - record: instance:memory_usage:bytes
        expr: node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

  - name: disk.rules
    interval: 30s
    rules:
      - record: instance:disk_usage:percentage
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

      - record: instance:disk_usage:bytes
        expr: node_filesystem_size_bytes - node_filesystem_avail_bytes

  - name: network.rules
    interval: 30s
    rules:
      - record: instance:network_receive:rate5m
        expr: rate(node_network_receive_bytes_total[5m])

      - record: instance:network_transmit:rate5m
        expr: rate(node_network_transmit_bytes_total[5m])
```

---

## Grafana Setup

### Step 1: Grafana Provisioning

Create `grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 30s
      queryTimeout: 60s
      httpMethod: POST
      exemplarTraceIdDestinations:
        - name: traceID
          datasourceUid: jaeger
    secureJsonData: {}
```

Create `grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    folderUid: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

### Step 2: Grafana Configuration

Create `grafana/grafana.ini`:

```ini
[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db

[session]
provider = file
provider_config = sessions

[security]
admin_user = admin
admin_password = admin123
secret_key = SW2YcwTIb9zpOOhoPsMm
disable_gravatar = true
disable_brute_force_login_protection = false

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = console
level = info

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[smtp]
enabled = false
host = smtp.gmail.com:587
user = your-email@gmail.com
password = your-app-password
from_address = your-email@gmail.com
from_name = Grafana
skip_verify = false

[unified_alerting]
enabled = true
execute_alerts = true
```

---

## Alertmanager Configuration

### Step 1: Alertmanager Configuration

Create `alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      continue: true
    - match:
        alertname: InstanceDown
      receiver: 'instance-down-alerts'
      continue: true
    - match:
        job: mongodb
      receiver: 'database-alerts'
      continue: true
    - match:
        job: postgresql
      receiver: 'database-alerts'
      continue: true

receivers:
  - name: 'default-receiver'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_URL'
        title: 'Monitoring Alert'
        message: |
          **Alert:** {{ .GroupLabels.alertname }}
          **Severity:** {{ .GroupLabels.severity }}
          **Instance:** {{ .GroupLabels.instance }}
          **Description:** {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        color: 16711680

  - name: 'critical-alerts'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_CRITICAL_WEBHOOK_URL'
        title: '🚨 CRITICAL ALERT'
        message: |
          **CRITICAL ALERT TRIGGERED**
          **Alert:** {{ .GroupLabels.alertname }}
          **Instance:** {{ .GroupLabels.instance }}
          **Description:** {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
          **Time:** {{ .CommonAnnotations.time }}
        color: 16711680
    email_configs:
      - to: 'admin@company.com'
        subject: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        html: |
          <h2>Critical Alert Triggered</h2>
          <p><strong>Alert:</strong> {{ .GroupLabels.alertname }}</p>
          <p><strong>Instance:</strong> {{ .GroupLabels.instance }}</p>
          <p><strong>Description:</strong> {{ range .Alerts }}{{ .Annotations.description }}{{ end }}</p>
          <p><strong>Time:</strong> {{ .CommonAnnotations.time }}</p>

  - name: 'instance-down-alerts'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_INSTANCE_DOWN_WEBHOOK_URL'
        title: '⚠️ Instance Down Alert'
        message: |
          **Instance Down Detected**
          **Instance:** {{ .GroupLabels.instance }}
          **Job:** {{ .GroupLabels.job }}
          **Description:** {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        color: 16753920

  - name: 'database-alerts'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_DATABASE_WEBHOOK_URL'
        title: '🗄️ Database Alert'
        message: |
          **Database Alert**
          **Alert:** {{ .GroupLabels.alertname }}
          **Database:** {{ .GroupLabels.job }}
          **Instance:** {{ .GroupLabels.instance }}
          **Description:** {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        color: 16776960

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

---

## Exporters and Metrics

### Step 1: Node Exporter Setup

Create installation script for Node Exporter:

```bash
#!/bin/bash
# install-node-exporter.sh

# Download and install Node Exporter
NODE_EXPORTER_VERSION="1.6.1"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# Create node_exporter user
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes \
    --collector.interrupts \
    --collector.tcpstat \
    --collector.meminfo_numa \
    --web.listen-address=0.0.0.0:9100

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Verify installation
systemctl status node_exporter
curl http://localhost:9100/metrics | head -20
```

### Step 2: MongoDB Exporter Setup

```bash
#!/bin/bash
# install-mongodb-exporter.sh

# Download MongoDB Exporter
MONGODB_EXPORTER_VERSION="0.39.0"
cd /tmp
wget https://github.com/percona/mongodb_exporter/releases/download/v${MONGODB_EXPORTER_VERSION}/mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp mongodb_exporter-${MONGODB_EXPORTER_VERSION}.linux-amd64/mongodb_exporter /usr/local/bin/

# Create mongodb_exporter user
sudo useradd --no-create-home --shell /bin/false mongodb_exporter
sudo chown mongodb_exporter:mongodb_exporter /usr/local/bin/mongodb_exporter

# Create systemd service
sudo tee /etc/systemd/system/mongodb_exporter.service > /dev/null <<EOF
[Unit]
Description=MongoDB Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=mongodb_exporter
Group=mongodb_exporter
Type=simple
ExecStart=/usr/local/bin/mongodb_exporter \
    --mongodb.uri=mongodb://admin:password@localhost:27017/admin \
    --web.listen-address=0.0.0.0:9216 \
    --collect-all

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable mongodb_exporter
sudo systemctl start mongodb_exporter

# Verify installation
systemctl status mongodb_exporter
curl http://localhost:9216/metrics | head -20
```

### Step 3: PostgreSQL Exporter Setup

```bash
#!/bin/bash
# install-postgresql-exporter.sh

# Download PostgreSQL Exporter
POSTGRES_EXPORTER_VERSION="0.13.2"
cd /tmp
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter /usr/local/bin/

# Create postgres_exporter user
sudo useradd --no-create-home --shell /bin/false postgres_exporter
sudo chown postgres_exporter:postgres_exporter /usr/local/bin/postgres_exporter

# Create environment file
sudo tee /etc/default/postgres_exporter > /dev/null <<EOF
DATA_SOURCE_NAME="postgresql://postgres:password@localhost:5432/postgres?sslmode=disable"
PG_EXPORTER_EXTEND_QUERY_PATH="/etc/postgres_exporter/queries.yml"
EOF

# Create custom queries
sudo mkdir -p /etc/postgres_exporter
sudo tee /etc/postgres_exporter/queries.yml > /dev/null <<EOF
pg_replication:
  query: "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) as lag"
  master: true
  metrics:
    - lag:
        usage: "GAUGE"
        description: "Replication lag behind master in seconds"

pg_database:
  query: "SELECT datname, pg_database_size(datname) as size FROM pg_database"
  metrics:
    - datname:
        usage: "LABEL"
        description: "Database name"
    - size:
        usage: "GAUGE"
        description: "Database size in bytes"
EOF

# Create systemd service
sudo tee /etc/systemd/system/postgres_exporter.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
EnvironmentFile=/etc/default/postgres_exporter
ExecStart=/usr/local/bin/postgres_exporter \
    --web.listen-address=0.0.0.0:9187

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable postgres_exporter
sudo systemctl start postgres_exporter

# Verify installation
systemctl status postgres_exporter
curl http://localhost:9187/metrics | head -20
```

---

## Docker Compose Configuration

### Step 1: Main Docker Compose File

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - ./data/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--storage.tsdb.retention.size=10GB'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
      - '--log.level=info'
    networks:
      - monitoring
    depends_on:
      - alertmanager

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini
      - ./dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_DISABLE_GRAVATAR=true
    networks:
      - monitoring
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager:/etc/alertmanager
      - ./data/alertmanager:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
      - '--log.level=info'
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    restart: unless-stopped
    ports:
      - "9115:9115"
    volumes:
      - ./blackbox:/etc/blackbox_exporter
    command:
      - '--config.file=/etc/blackbox_exporter/config.yml'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
```

### Step 2: Blackbox Exporter Configuration

Create `blackbox/config.yml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      method: GET
      headers:
        Host: vhost.example.com
        Accept-Language: en-US
      no_follow_redirects: false
      fail_if_ssl: false
      fail_if_not_ssl: false
      fail_if_matches_regexp:
        - "Could not connect to database"
      fail_if_not_matches_regexp:
        - "Download the latest version here"
      tls_config:
        insecure_skip_verify: false
      preferred_ip_protocol: "ip4"
      ip_protocol_fallback: false

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      headers:
        Content-Type: application/json
      body: '{}'

  tcp_connect:
    prober: tcp
    timeout: 5s

  pop3s_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^+OK"
      tls: true
      tls_config:
        insecure_skip_verify: false

  ssh_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^SSH-2.0-"

  irc_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - send: "NICK prober"
        - send: "USER prober prober prober :prober"
        - expect: "PING :([^ ]+)"
          send: "PONG ${1}"
        - expect: "^:[^ ]+ 001"

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
      source_ip_address: "127.0.0.1"
```

---

## Dashboard Creation

### Step 1: System Overview Dashboard

Create `dashboards/system-overview.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "System Overview",
    "tags": ["system", "overview"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Load",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(node_load1)",
            "legendFormat": "Load 1m"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 0.8},
                {"color": "red", "value": 1.2}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "instance:memory_usage:percentage",
            "legendFormat": "{{ instance }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "percent"
          }
        }
      },
      {
        "id": 3,
        "title": "CPU Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "instance:cpu_usage:rate5m",
            "legendFormat": "{{ instance }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

### Step 2: Database Dashboard

Create `dashboards/database-dashboard.json`:

```json
{
  "dashboard": {
    "id": null,
    "title": "Database Monitoring",
    "tags": ["database", "mongodb", "postgresql"],
    "panels": [
      {
        "id": 1,
        "title": "MongoDB Replica Set Status",
        "type": "stat",
        "targets": [
          {
            "expr": "mongodb_replset_member_state",
            "legendFormat": "{{ instance }}"
          }
        ]
      },
      {
        "id": 2,
        "title": "PostgreSQL Connections",
        "type": "timeseries",
        "targets": [
          {
            "expr": "pg_stat_activity_count",
            "legendFormat": "{{ instance }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Database Operations",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(mongodb_op_counters_total[5m])",
            "legendFormat": "MongoDB - {{ type }}"
          },
          {
            "expr": "rate(pg_stat_database_xact_commit[5m])",
            "legendFormat": "PostgreSQL - Commits"
          }
        ]
      }
    ]
  }
}
```

---

## Deployment and Management

### Step 1: Start the Stack

```bash
# Navigate to project directory
cd /opt/monitoring-stack

# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Check individual service logs
docker compose logs prometheus
docker compose logs grafana
docker compose logs alertmanager
```

### Step 2: Initial Setup

```bash
# Access Grafana
# URL: http://192.168.1.100:3000
# Username: admin
# Password: admin123

# Access Prometheus
# URL: http://192.168.1.100:9090

# Access Alertmanager
# URL: http://192.168.1.100:9093

# Test alert
curl -X POST http://192.168.1.100:9093/api/v1/alerts
```

### Step 3: Health Check Script

Create `health-check.sh`:

```bash
#!/bin/bash
# health-check.sh

SERVICES=("prometheus:9090" "grafana:3000" "alertmanager:9093")
MONITORING_HOST="192.168.1.100"

echo "Monitoring Stack Health Check - $(date)"
echo "=========================================="

for service in "${SERVICES[@]}"; do
    IFS=':' read -r name port <<< "$service"
    
    if curl -s -f "http://$MONITORING_HOST:$port" > /dev/null; then
        echo "✓ $name is healthy"
    else
        echo "✗ $name is not responding"
    fi
done

# Check node exporters
NODE_EXPORTERS=("192.168.1.100:9100" "192.168.1.210:9100" "192.168.1.20:9100")

echo ""
echo "Node Exporter Status:"
for exporter in "${NODE_EXPORTERS[@]}"; do
    if curl -s -f "http://$exporter/metrics" > /dev/null; then
        echo "✓ $exporter is healthy"
    else
        echo "✗ $exporter is not responding"
    fi
done
```

---

## Security Best Practices

### Step 1: Authentication Setup

```yaml
# Add to docker-compose.yml for Grafana
environment:
  - GF_AUTH_BASIC_ENABLED=true
  - GF_AUTH_DISABLE_LOGIN_FORM=false
  - GF_AUTH_DISABLE_SIGNOUT_MENU=false
  - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
```

### Step 2: Network Security

```bash
# Configure firewall
sudo ufw allow from 192.168.1.0/24 to any port 9090
sudo ufw allow from 192.168.1.0/24 to any port 3000
sudo ufw allow from 192.168.1.0/24 to any port 9093
sudo ufw deny 9090
sudo ufw deny 3000
sudo ufw deny 9093
```

### Step 3: SSL Configuration

```bash
# Generate SSL certificates
sudo mkdir -p /etc/monitoring/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/monitoring/ssl/monitoring.key \
    -out /etc/monitoring/ssl/monitoring.crt \
    -subj "/C=VN/ST=HCM/L=HCM/O=Monitoring/CN=monitoring.local"
```

---

## Troubleshooting

### Common Issues

#### 1. Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
docker compose logs prometheus

# Check target status
curl http://192.168.1.100:9090/api/v1/targets

# Test connectivity
curl http://192.168.1.210:9100/metrics
```

#### 2. Grafana Dashboard Issues

```bash
# Check Grafana logs
docker compose logs grafana

# Reset Grafana password
docker compose exec grafana grafana-cli admin reset-admin-password admin123
```

#### 3. Alertmanager Not Sending Alerts

```bash
# Check Alertmanager logs
docker compose logs alertmanager

# Test webhook
curl -X POST https://discord.com/api/webhooks/YOUR_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message"}'
```

---

## Integration with Other Services

### Step 1: Kubernetes Integration

```yaml
# Add to prometheus.yml
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
```

### Step 2: Cloud Integration

```yaml
# Add cloud monitoring
- job_name: 'aws-cloudwatch'
  ec2_sd_configs:
    - region: us-east-1
      port: 9100
```

### Step 3: Custom Metrics

```python
# Example Python application metrics
from prometheus_client import Counter, Histogram, start_http_server
import time

REQUEST_COUNT = Counter('app_requests_total', 'Total requests')
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Request latency')

@REQUEST_LATENCY.time()
def process_request():
    REQUEST_COUNT.inc()
    time.sleep(1)

if __name__ == '__main__':
    start_http_server(8000)
    while True:
        process_request()
```

---

## Next Steps

After successful monitoring setup:

1. **Custom Dashboards**: Create application-specific dashboards
2. **Advanced Alerting**: Set up complex alerting rules
3. **Long-term Storage**: Configure remote storage for metrics
4. **High Availability**: Set up Prometheus HA configuration
5. **Automated Deployment**: Create CI/CD pipelines for monitoring

For more advanced topics, refer to:
- [VPN Server Setup](vpn-server.md)
- [Database Setup](database-mongodb.md)
- [Container Registry](container-registry.md)

---

## Conclusion

This comprehensive monitoring setup provides a robust foundation for infrastructure monitoring with Prometheus, Grafana, and Alertmanager. The stack offers real-time metrics collection, powerful visualization capabilities, and flexible alerting mechanisms.

The configuration is designed to be scalable and maintainable, allowing for easy addition of new services and metrics. Regular monitoring of the monitoring stack itself is essential for maintaining operational visibility and ensuring system reliability. 