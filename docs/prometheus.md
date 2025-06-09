# Hướng dẫn đầy đủ về Prometheus

## Mục lục
- [Tổng quan về Prometheus](#tổng-quan-về-prometheus)
- [Kiến trúc Prometheus](#kiến-trúc-prometheus)
- [Các thành phần của Prometheus](#các-thành-phần-của-prometheus)
- [Metrics và Mô hình dữ liệu](#metrics-và-mô-hình-dữ-liệu)
- [Cấu hình](#cấu-hình)
- [Ngôn ngữ truy vấn PromQL](#ngôn-ngữ-truy-vấn-promql)
- [Service Discovery](#service-discovery)
- [Exporters](#exporters)
- [Cảnh báo](#cảnh-báo)
- [Lưu trữ](#lưu-trữ)
- [Các phương pháp hay nhất](#các-phương-pháp-hay-nhất)

## Tổng quan về Prometheus

### Prometheus là gì?
Prometheus là một bộ công cụ giám sát và cảnh báo mã nguồn mở được phát triển bởi SoundCloud vào năm 2012. Nó được thiết kế để thu thập, lưu trữ và truy vấn các metrics từ các hệ thống phân tán.

### Tính năng chính

- **Mô hình Pull**: Prometheus chủ động scrape metrics từ các targets
- **Cơ sở dữ liệu chuỗi thời gian**: Lưu trữ dữ liệu dưới dạng chuỗi thời gian với timestamp
- **Ngôn ngữ truy vấn mạnh mẽ**: PromQL để truy vấn và phân tích dữ liệu
- **Không phụ thuộc bên ngoài**: Hoạt động độc lập, không cần cơ sở dữ liệu bên ngoài
- **Mô hình dữ liệu đa chiều**: Sử dụng labels để phân loại metrics
- **Service Discovery**: Tự động phát hiện các targets cần giám sát

### Các trường hợp sử dụng

- Giám sát cơ sở hạ tầng (CPU, bộ nhớ, ổ đĩa, mạng)
- Giám sát hiệu suất ứng dụng
- Theo dõi các chỉ số kinh doanh
- Cảnh báo và thông báo
- Lập kế hoạch năng lực
- Giám sát SLA

## Kiến trúc Prometheus

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
                    ┌────────────▼──────────┐
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
                   ┌────────────▼──────────┐
                   │   External APIs       │
                   │                       │
                   │  • Slack              │
                   │  • PagerDuty          │
                   │  • Email              │
                   │  • Webhook            │
                   └───────────────────────┘
```

### Các thành phần kiến trúc
- **Prometheus Server**: Thành phần cốt lõi thực hiện việc scraping, lưu trữ và truy vấn
- **Targets**: Các ứng dụng, dịch vụ, exporters cung cấp metrics
- **Alertmanager**: Xử lý cảnh báo từ Prometheus server
- **Grafana**: Lớp trực quan hóa để tạo dashboards
- **Pushgateway**: Cho phép các jobs ngắn hạn đẩy metrics

## Các thành phần của Prometheus

### 1. Prometheus Server
Prometheus server là thành phần chính bao gồm:

#### Thành phần Thu thập
- Scrape metrics từ các targets đã cấu hình
- Hỗ trợ giao thức HTTP/HTTPS
- Khoảng thời gian scrape có thể cấu hình
- Kiểm tra tình trạng target

#### Cơ sở dữ liệu chuỗi thời gian (TSDB)
- Storage engine tùy chỉnh được tối ưu hóa cho dữ liệu chuỗi thời gian
- Lưu trữ cục bộ trên ổ đĩa
- Thuật toán nén để tiết kiệm không gian lưu trữ
- Chính sách lưu giữ

#### HTTP Server
- Cung cấp API PromQL
- Giao diện Web để truy vấn và gỡ lỗi
- Quản lý cấu hình
- Thông tin thời gian chạy

### 2. Thư viện Client
Prometheus cung cấp thư viện client cho nhiều ngôn ngữ:

```go
// Ví dụ Go
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
            Help: "Tổng số request HTTP",
        },
        []string{"method", "endpoint"},
    )
    
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "Thời gian xử lý request HTTP",
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
Exporters là các ứng dụng chuyển đổi metrics từ hệ thống bên thứ ba sang định dạng Prometheus.

#### Exporters Chính thức
- Node Exporter: Metrics hệ thống (CPU, bộ nhớ, ổ đĩa, mạng)
- Blackbox Exporter: Kiểm tra endpoints qua HTTP, HTTPS, DNS, TCP, ICMP
- SNMP Exporter: Metrics SNMP từ thiết bị mạng
- Consul Exporter: Metrics service discovery từ Consul

#### Exporters của bên thứ ba
- MySQL Exporter: Metrics cơ sở dữ liệu
- Redis Exporter: Metrics Redis
- Nginx Exporter: Metrics máy chủ web
- JMX Exporter: Metrics Java JMX

#### Ví dụ Custom Exporter
```python
# Ví dụ Python
from prometheus_client import Counter, Histogram, start_http_server
import time
import random

REQUEST_COUNT = Counter('app_requests_total', 'Tổng số request của ứng dụng', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_latency_seconds', 'Độ trễ request')

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

## Metrics và Mô hình dữ liệu

### Các loại Metric

#### 1. Counter
- Chỉ tăng đơn điệu (hoặc reset về 0)
- Dùng cho: requests, lỗi, tasks hoàn thành

```
# HELP http_requests_total Tổng số request HTTP
# TYPE http_requests_total counter
http_requests_total{method="GET",handler="/api"} 1027
http_requests_total{method="POST",handler="/api"} 3
```

#### 2. Gauge
- Có thể tăng hoặc giảm
- Dùng cho: sử dụng CPU, sử dụng bộ nhớ, nhiệt độ

```
# HELP node_memory_MemAvailable_bytes Bộ nhớ khả dụng
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 1.234567e+09
```

#### 3. Histogram
- Phân phối các quan sát theo buckets
- Tự động tạo metrics _bucket, _count, _sum

```
# HELP http_request_duration_seconds Thời gian xử lý request
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 24054
http_request_duration_seconds_bucket{le="0.2"} 26451
http_request_duration_seconds_bucket{le="0.4"} 27760
http_request_duration_seconds_bucket{le="+Inf"} 27761
http_request_duration_seconds_sum 1.7560473e+05
http_request_duration_seconds_count 27761
```

#### 4. Summary
- Tương tự histogram nhưng tính quantiles ở phía client
- Cung cấp _count, _sum và giá trị quantile

```
# HELP rpc_duration_seconds Phân vị độ trễ RPC
# TYPE rpc_duration_seconds summary
rpc_duration_seconds{quantile="0.5"} 0.232
rpc_duration_seconds{quantile="0.9"} 0.821
rpc_duration_seconds{quantile="0.99"} 2.1
rpc_duration_seconds_sum 8953.332
rpc_duration_seconds_count 27892
```

### Mô hình dữ liệu
Prometheus lưu trữ dữ liệu dưới dạng chuỗi thời gian với định dạng:
```
<tên_metric>{<tên_nhãn>=<giá_trị_nhãn>,...} <giá_trị_mẫu> [timestamp]
```

### Labels
Labels là các cặp key-value để phân loại metrics:
```
api_http_requests_total{method="POST", handler="/messages"} 34
api_http_requests_total{method="GET", handler="/messages"} 119
```

#### Quy ước đặt tên Label
- Tên metrics: `[a-zA-Z_:][a-zA-Z0-9_:]*`
- Tên labels: `[a-zA-Z_][a-zA-Z0-9_]*`
- Labels dành riêng: tiền tố `__` (sử dụng nội bộ)

#### Phương pháp hay nhất cho Labels
- Sử dụng labels để phân biệt các instance của cùng một metric
- Tránh labels có tính đặc trưng cao (tránh các giá trị duy nhất như user IDs)
- Giá trị label nên có tập giá trị giới hạn
- Sử dụng quy ước đặt tên nhất quán

## Cấu hình

### File cấu hình Prometheus
Prometheus sử dụng file cấu hình YAML (prometheus.yml):

```yaml
global:
  scrape_interval: 15s      # Scrape targets mỗi 15 giây
  evaluation_interval: 15s  # Đánh giá rules mỗi 15 giây
  external_labels:
    monitor: 'prometheus-prod'
    datacenter: 'us-east-1'

# Cấu hình Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

# Files rules
rule_files:
  - "alert_rules.yml"
  - "recording_rules.yml"

# Cấu hình scrape
scrape_configs:
  # Tự giám sát Prometheus
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

  # Giám sát ứng dụng
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

### Metrics chính
```
# Metrics kiểm tra HTTP
probe_success{instance="http://example.com", job="blackbox"}
probe_duration_seconds{instance="http://example.com", job="blackbox"}
probe_http_status_code{instance="http://example.com", job="blackbox"}
probe_http_ssl{instance="https://example.com", job="blackbox"}
probe_http_redirects{instance="http://example.com", job="blackbox"}

# Metrics chứng chỉ SSL
probe_ssl_earliest_cert_expiry{instance="https://example.com", job="blackbox"}
probe_http_ssl{instance="https://example.com", job="blackbox"}

# Metrics DNS
probe_dns_lookup_time_seconds{instance="example.com", job="blackbox"}
```

## Cảnh báo

### Rules cảnh báo
Rules cảnh báo được định nghĩa trong files YAML và được đánh giá bởi Prometheus server.

#### Rule cảnh báo cơ bản
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
          summary: Độ trễ request cao trên {{ $labels.instance }}
          description: "{{ $labels.instance }} có độ trễ phân vị thứ 99 là {{ $value }} giây trong 10 phút qua."
```

### Cảnh báo cơ sở hạ tầng
```yaml
groups:
  - name: infrastructure
    rules:
      # Sử dụng CPU cao
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          team: infrastructure
        annotations:
          summary: "Phát hiện sử dụng CPU cao"
          description: "Sử dụng CPU trên {{ $labels.instance }} vượt quá 80% trong hơn 5 phút. Giá trị hiện tại: {{ $value }}%"

      # Sử dụng bộ nhớ cao
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
          team: infrastructure
        annotations:
          summary: "Phát hiện sử dụng bộ nhớ cao"
          description: "Sử dụng bộ nhớ trên {{ $labels.instance }} vượt quá 90%. Giá trị hiện tại: {{ $value }}%"
```

### Cảnh báo ứng dụng
```yaml
groups:
  - name: application
    rules:
      # Tỷ lệ lỗi cao
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
          summary: "Phát hiện tỷ lệ lỗi cao"
          description: "Tỷ lệ lỗi trên {{ $labels.instance }} vượt quá 5%. Giá trị hiện tại: {{ $value }}%"
```

### Cấu hình Alertmanager
```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@company.com'
  smtp_auth_username: 'alerts@company.com'
  smtp_auth_password: 'app_password'

# Templates cho thông báo
templates:
  - '/etc/alertmanager/templates/*.tmpl'

# Định tuyến cảnh báo đến các receivers
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
    # Cảnh báo nghiêm trọng đến PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty'
      group_wait: 5s
      repeat_interval: 5m

    # Cảnh báo cơ sở hạ tầng đến Slack
    - match:
        team: infrastructure
      receiver: 'slack-infrastructure'
```

## Lưu trữ

### Lưu trữ cục bộ
Prometheus sử dụng cơ sở dữ liệu chuỗi thời gian tùy chỉnh với lưu trữ cục bộ.

#### Định dạng lưu trữ
```
./data/
├── 01BKGV7JBM69T2G1BGBGM6KB12/     # Thư mục block
│   ├── chunks/                      # Files chunk
│   │   └── 000001
│   ├── tombstones                   # Đánh dấu xóa
│   ├── index                        # Chỉ mục series
│   └── meta.json                    # Metadata block
├── 01BKGTZQ1SYQJTR4PB43C8PD98/
├── chunks_head/                     # Block đang ghi
├── lock                            # File khóa
└── wal/                            # Write-ahead log
    ├── 00000000
    ├── 00000001
    └── checkpoint.00000001
```

### Cấu hình lưu trữ
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

### Lưu trữ từ xa
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

## Các phương pháp hay nhất

### Thiết kế Metric

#### Quy ước đặt tên
```
# Tốt
http_requests_total
http_request_duration_seconds
process_cpu_seconds_total
node_memory_MemAvailable_bytes

# Không tốt
httpRequestsTotal  # camelCase
http-requests-total  # dấu gạch ngang
requests  # không mô tả
api_latency_ms  # sai đơn vị hậu tố
```

#### Phương pháp hay nhất cho Labels
```yaml
# Tốt - tính đặc trưng giới hạn
http_requests_total{method="GET", status_code="200", handler="/api/users"}

# Không tốt - tính đặc trưng không giới hạn
http_requests_total{user_id="12345", request_id="abc-123"}  # Đừng làm thế này!

# Tốt - sử dụng giá trị label với tập giới hạn đã biết
database_connections{database="users", pool="readonly"}

# Không tốt - tính đặc trưng cao
database_connections{query="SELECT * FROM users WHERE id = 123"}
```

### Tối ưu hóa truy vấn

#### Truy vấn PromQL hiệu quả
```promql
# Tốt - khớp label cụ thể
rate(http_requests_total{job="api", status_code="200"}[5m])

# Không tốt - regex khi không cần thiết
rate(http_requests_total{job=~"api"}[5m])

# Tốt - tổng hợp sớm
sum by (job) (rate(http_requests_total[5m]))

# Không tốt - tổng hợp muộn
sum(rate(http_requests_total[5m])) by (job)
```

### Bảo mật

#### Xác thực & Phân quyền
```yaml
# Cấu hình Web
web:
  basic_auth_users:
    admin: '$2b$12$hNf2lSsxfm0.i4a.1kVpSOVyBCfIB51VRjgBUyv6kdnyTlgWj81Ay'  # hash bcrypt
    readonly: '$2b$12$hNf2lSsxfm0.i4a.1kVpSOVyBCfIB51VRjgBUyv6kdnyTlgWj81Ay'

# Cấu hình TLS
tls_server_config:
  cert_file: '/etc/prometheus/prometheus.crt'
  key_file: '/etc/prometheus/prometheus.key'
  client_ca_file: '/etc/prometheus/client_ca.crt'
  client_auth_type: 'RequireAndVerifyClientCert'
```

### Điều chỉnh hiệu năng

#### Hiệu năng truy vấn
```yaml
# Giới hạn truy vấn đồng thời
--query.max-concurrency=20

# Thời gian chờ truy vấn
--query.timeout=2m

# Giới hạn số lượng mẫu
--query.max-samples=50000000
```

### Giám sát Prometheus

#### Metrics tự giám sát
```promql
# Tình trạng Prometheus
up{job="prometheus"}

# Tốc độ nhập dữ liệu
rate(prometheus_tsdb_samples_appended_total[5m])

# Kích thước lưu trữ
prometheus_tsdb_size_bytes

# Hiệu năng truy vấn
histogram_quantile(0.95, rate(prometheus_http_request_duration_seconds_bucket[5m]))
```

## Tài nguyên bổ sung

- [Tài liệu chính thức Prometheus](https://prometheus.io/docs/)
- [Repository GitHub Prometheus](https://github.com/prometheus/prometheus)
- [Phương pháp hay nhất Prometheus](https://prometheus.io/docs/practices/naming/)
- [Ví dụ PromQL](https://prometheus.io/docs/prometheus/latest/querying/examples/) 