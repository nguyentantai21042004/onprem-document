# Prometheus Complete Guide

## Table of Contents
- [Prometheus Overview](#prometheus-overview)
- [Prometheus Architecture](#prometheus-architecture)
- [Prometheus Components](#prometheus-components)
- [Metrics and Data Model](#metrics-and-data-model)
- [Configuration](#configuration)
- [PromQL Query Language](#promql-query-language)
- [Service Discovery](#service-discovery)
- [Exporters](#exporters)
- [Alerting](#alerting)
- [Storage](#storage)
- [Best Practices](#best-practices)

## Prometheus Overview

### What is Prometheus?
Prometheus is an open-source monitoring and alerting toolkit developed by SoundCloud in 2012. It is designed to collect, store, and query metrics from distributed systems.

### Key Features

- **Pull-based Model**: Prometheus actively scrapes metrics from targets
- **Time-series Database**: Stores data as time-series with timestamps
- **Powerful Query Language**: PromQL for querying and analyzing data
- **No External Dependencies**: Operates independently, no external database needed
- **Multi-dimensional Data Model**: Uses labels to classify metrics
- **Service Discovery**: Automatically discovers targets to monitor

### Use Cases

- Infrastructure monitoring (CPU, memory, disk, network)
- Application performance monitoring
- Business metrics tracking
- Alerting and notification
- Capacity planning
- SLA monitoring

## Prometheus Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │    Exporters    │    │  Pushgateway    │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ HTTP/metrics         │ HTTP/metrics         │ HTTP/push
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │   Prometheus Server   │
                     │                       │
                     │  ┌─────────────────┐  │
                     │  │  Retrieval      │  │
                     │  │  (Scraping)     │  │
                     │  └─────────────────┘  │
                     │                       │
                     │  ┌─────────────────┐  │
                     │  │  Time Series    │  │
                     │  │  Database       │  │
                     │  └─────────────────┘  │
                     │                       │
                     │  ┌─────────────────┐  │
                     │  │  HTTP Server    │  │
                     │  │  (PromQL API)   │  │
                     │  └─────────────────┘  │
                     └───────────┬───────────┘
                                 │
                   ┌─────────────┼─────────────┐
                   │             │             │
       ┌───────────▼───────────┐ │ ┌───────────▼───────────┐
       │      Grafana          │ │ │    Alertmanager       │
       │                       │ │ │                       │
       │  ┌─────────────────┐  │ │ │  ┌─────────────────┐  │
       │  │  Dashboards     │  │ │ │  │  Alert Routing  │  │
       │  └─────────────────┘  │ │ │  └─────────────────┘  │
       │                       │ │ │                       │
       │  ┌─────────────────┐  │ │ │  ┌─────────────────┐  │
       │  │  Visualization  │  │ │ │  │  Notifications  │  │
       │  └─────────────────┘  │ │ │  └─────────────────┘  │
       └───────────────────────┘ │ └───────────────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │   External APIs       │
                     │                       │
                     │  • Slack              │
                     │  • PagerDuty          │
                     │  • Email              │
                     │  • Webhook            │
                     └───────────────────────┘
```

### Architecture Components
- **Prometheus Server**: Core component performing scraping, storing, and querying
- **Targets**: Applications, services, exporters providing metrics
- **Alertmanager**: Handles alerts from Prometheus server
- **Grafana**: Visualization layer for creating dashboards
- **Pushgateway**: Allows short-lived jobs to push metrics

## Prometheus Components

### 1. Prometheus Server
The Prometheus server is the main component that includes:

#### Retrieval Component
- Scrapes metrics from configured targets
- Supports HTTP/HTTPS protocols
- Configurable scrape intervals
- Target health checking

#### Time Series Database (TSDB)
- Custom storage engine optimized for time-series data
- Local storage on disk
- Compression algorithms for storage efficiency
- Retention policies

#### HTTP Server
- Exposes PromQL API
- Web UI for querying and debugging
- Configuration management
- Runtime information

### 2. Client Libraries
Prometheus provides client libraries for various languages:

```go
// Go example
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint"},
    )
    
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "Duration of HTTP requests",
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

### 3. Exporters
Exporters are applications that convert metrics from third-party systems to Prometheus format.

#### Official Exporters
- Node Exporter: System metrics (CPU, memory, disk, network)
- Blackbox Exporter: Probing endpoints over HTTP, HTTPS, DNS, TCP, ICMP
- SNMP Exporter: SNMP metrics from network devices
- Consul Exporter: Consul service discovery metrics

#### Third-party Exporters
- MySQL Exporter: Database metrics
- Redis Exporter: Redis metrics
- Nginx Exporter: Web server metrics
- JMX Exporter: Java JMX metrics

#### Custom Exporters Example
```python
# Python example
from prometheus_client import Counter, Histogram, start_http_server
import time
import random

REQUEST_COUNT = Counter('app_requests_total', 'Total app requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Request latency')

def process_request():
    REQUEST_COUNT.labels(method='GET', endpoint='/api').inc()
    with REQUEST_LATENCY.time():
        time.sleep(random.random())

if __name__ == '__main__':
    start_http_server(8000)
    while True:
        process_request()
        time.sleep(1)
```

## Metrics and Data Model

### Metric Types

#### 1. Counter
- Only increases monotonically (or resets to 0)
- Used for: requests, errors, tasks completed

```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",handler="/api"} 1027
http_requests_total{method="POST",handler="/api"} 3
```

#### 2. Gauge
- Can increase or decrease
- Used for: CPU usage, memory usage, temperature

```
# HELP node_memory_MemAvailable_bytes Memory available
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 1.234567e+09
```

#### 3. Histogram
- Distribution of observations in buckets
- Automatically creates _bucket, _count, _sum metrics

```
# HELP http_request_duration_seconds Request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 24054
http_request_duration_seconds_bucket{le="0.2"} 26451
http_request_duration_seconds_bucket{le="0.4"} 27760
http_request_duration_seconds_bucket{le="+Inf"} 27761
http_request_duration_seconds_sum 1.7560473e+05
http_request_duration_seconds_count 27761
```

#### 4. Summary
- Similar to histogram but calculates quantiles on client-side
- Exposes _count, _sum and quantile values

```
# HELP rpc_duration_seconds RPC latency quantiles
# TYPE rpc_duration_seconds summary
rpc_duration_seconds{quantile="0.5"} 0.232
rpc_duration_seconds{quantile="0.9"} 0.821
rpc_duration_seconds{quantile="0.99"} 2.1
rpc_duration_seconds_sum 8953.332
rpc_duration_seconds_count 27892
```

### Data Model
Prometheus stores data as time-series with format:
```
<metric_name>{<label_name>=<label_value>,...} <sample_value> [timestamp]
```

### Labels
Labels are key-value pairs to classify metrics:
```
api_http_requests_total{method="POST", handler="/messages"} 34
api_http_requests_total{method="GET", handler="/messages"} 119
```

#### Label Naming Conventions
- Metric names: `[a-zA-Z_:][a-zA-Z0-9_:]*`
- Label names: `[a-zA-Z_][a-zA-Z0-9_]*`
- Reserved labels: `__` prefix (internal use)

#### Best Practices for Labels
- Use labels to differentiate instances of the same metric
- Avoid high-cardinality labels (avoid unique values like user IDs)
- Label values should have bounded set of values
- Use consistent naming conventions

## Configuration

### Prometheus Configuration File
Prometheus uses YAML configuration file (prometheus.yml):

```yaml
global:
  scrape_interval: 15s      # Scrape targets every 15 seconds
  evaluation_interval: 15s  # Evaluate rules every 15 seconds
  external_labels:
    monitor: 'prometheus-prod'
    datacenter: 'us-east-1'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

# Rules files
rule_files:
  - "alert_rules.yml"
  - "recording_rules.yml"

# Scrape configurations
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node exporter
  - job_name: 'node'
    static_configs:
      - targets: 
        - 'node1:9100'
        - 'node2:9100'
    scrape_interval: 10s
    metrics_path: /metrics
    scheme: http

  # Application monitoring
  - job_name: 'app'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - production
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### Key Metrics
```
# HTTP probe metrics
probe_success{instance="http://example.com", job="blackbox"}
probe_duration_seconds{instance="http://example.com", job="blackbox"}
probe_http_status_code{instance="http://example.com", job="blackbox"}
probe_http_ssl{instance="https://example.com", job="blackbox"}
probe_http_redirects{instance="http://example.com", job="blackbox"}

# SSL certificate metrics
probe_ssl_earliest_cert_expiry{instance="https://example.com", job="blackbox"}
probe_http_ssl{instance="https://example.com", job="blackbox"}

# DNS metrics
probe_dns_lookup_time_seconds{instance="example.com", job="blackbox"}
```

## Alerting

### Alert Rules
Alert rules are defined in YAML files and evaluated by Prometheus server.

#### Basic Alert Rule
```yaml
# alert_rules.yml
groups:
  - name: example
    rules:
      - alert: HighRequestLatency
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 10m
        labels:
          severity: page
        annotations:
          summary: High request latency on {{ $labels.instance }}
          description: "{{ $labels.instance }} has a 99th percentile latency of {{ $value }} seconds for the last 10 minutes."
```

### Infrastructure Alerts
```yaml
groups:
  - name: infrastructure
    rules:
      # High CPU Usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }} for more than 5 minutes. Current value: {{ $value }}%"

      # High Memory Usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
          team: infrastructure
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 90% on {{ $labels.instance }}. Current value: {{ $value }}%"
```

### Application Alerts
```yaml
groups:
  - name: application
    rules:
      # High Error Rate
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (instance)
            /
            sum(rate(http_requests_total[5m])) by (instance)
          ) * 100 > 5
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% on {{ $labels.instance }}. Current value: {{ $value }}%"
```

### Alertmanager Configuration
```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@company.com'
  smtp_auth_username: 'alerts@company.com'
  smtp_auth_password: 'app_password'

# Templates for notifications
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# Route alerts to different receivers
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
    # Critical alerts go to PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty'
      group_wait: 5s
      repeat_interval: 5m

    # Infrastructure alerts go to Slack
    - match:
        team: infrastructure
      receiver: 'slack-infrastructure'
```

## Storage

### Local Storage
Prometheus uses a custom time-series database with local storage.

#### Storage Format
```
./data/
├── 01BKGV7JBM69T2G1BGBGM6KB12/     # Block directory
│   ├── chunks/                      # Chunk files
│   │   └── 000001
│   ├── tombstones                   # Deletion markers
│   ├── index                        # Series index
│   └── meta.json                    # Block metadata
├── 01BKGTZQ1SYQJTR4PB43C8PD98/
├── chunks_head/                     # Current block being written
├── lock                            # Lock file
└── wal/                            # Write-ahead log
    ├── 00000000
    ├── 00000001
    └── checkpoint.00000001
```

### Storage Configuration
```yaml
# prometheus.yml
storage:
  tsdb:
    path: /prometheus
    retention.time: 15d
    retention.size: 50GB
    min-block-duration: 2h
    max-block-duration: 25h
    no-lockfile: false
    allow-overlapping-blocks: false
    wal-compression: true
```

### Remote Storage
```yaml
# Remote Write
remote_write:
  - url: "https://prometheus-remote-write.example.com/api/v1/write"
    basic_auth:
      username: user
      password: pass
    write_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.*|prometheus_.*'
        action: drop

# Remote Read
remote_read:
  - url: "https://prometheus-remote-read.example.com/api/v1/read"
    basic_auth:
      username: user
      password: pass
    read_recent: true
```

## Best Practices

### Metric Design

#### Naming Conventions
```
# Good
http_requests_total
http_request_duration_seconds
process_cpu_seconds_total
node_memory_MemAvailable_bytes

# Bad
httpRequestsTotal  # camelCase
http-requests-total  # hyphens
requests  # not descriptive
api_latency_ms  # wrong unit suffix
```

#### Label Best Practices
```yaml
# Good - bounded cardinality
http_requests_total{method="GET", status_code="200", handler="/api/users"}

# Bad - unbounded cardinality
http_requests_total{user_id="12345", request_id="abc-123"}  # Don't do this!

# Good - use label values with known bounded set
database_connections{database="users", pool="readonly"}

# Bad - high cardinality
database_connections{query="SELECT * FROM users WHERE id = 123"}
```

### Query Optimization

#### Efficient PromQL Queries
```promql
# Good - specific label matching
rate(http_requests_total{job="api", status_code="200"}[5m])

# Bad - regex when not needed
rate(http_requests_total{job=~"api"}[5m])

# Good - aggregate early
sum by (job) (rate(http_requests_total[5m]))

# Bad - aggregate late
sum(rate(http_requests_total[5m])) by (job)
```

### Security

#### Authentication & Authorization
```yaml
# Web configuration
web:
  basic_auth_users:
    admin: '$2b$12$hNf2lSsxfm0.i4a.1kVpSOVyBCfIB51VRjgBUyv6kdnyTlgWj81Ay'  # bcrypt hash
    readonly: '$2b$12$hNf2lSsxfm0.i4a.1kVpSOVyBCfIB51VRjgBUyv6kdnyTlgWj81Ay'

# TLS Configuration
tls_server_config:
  cert_file: '/etc/prometheus/prometheus.crt'
  key_file: '/etc/prometheus/prometheus.key'
  client_ca_file: '/etc/prometheus/client_ca.crt'
  client_auth_type: 'RequireAndVerifyClientCert'
```

### Performance Tuning

#### Query Performance
```yaml
# Limit concurrent queries
--query.max-concurrency=20

# Query timeout
--query.timeout=2m

# Limit query samples
--query.max-samples=50000000
```

### Monitoring Prometheus Itself

#### Self-monitoring Metrics
```promql
# Prometheus health
up{job="prometheus"}

# Ingestion rate
rate(prometheus_tsdb_samples_appended_total[5m])

# Storage size
prometheus_tsdb_size_bytes

# Query performance
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket[5m]))
```

## Additional Resources

- [Official Prometheus Documentation](https://prometheus.io/docs/)
- [Prometheus GitHub Repository](https://github.com/prometheus/prometheus)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [PromQL Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/) 