## Cấu hình Prometheus (Trên VM Giám sát)
Do Prometheus của bạn chạy bên ngoài cụm K8s, chúng ta cần cấu hình nó để "nói chuyện" với K8s API một cách an toàn và tự động phát hiện (Service Discovery) các Node (cho cAdvisor) và Kube-State-Metrics.

### 1.1. Tạo ServiceAccount cho Prometheus (Trong K8s)
Bước này cấp cho Prometheus (chạy trên VM) quyền "chỉ đọc" cần thiết để khám phá các tài nguyên trong K8s.

Trên Master Node của K8s, tạo file `prometheus-rbac.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  # Namespace tuỳ chọn (không cần trùng với namespace của Kube-State-Metrics)
  # Có thể dùng 'monitoring' hoặc bất kỳ namespace nào bạn quản lý
  namespace: monitoring 
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - nodes/proxy
  - services
  - services/proxy
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics", "/metrics/cadvisor"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring # Phải khớp với namespace ở trên
```

Áp dụng file này:

```bash
kubectl apply -f prometheus-rbac.yaml
```

### 1.2. Lấy thông tin xác thực cho Prometheus (Trong K8s)
Prometheus trên VM cần 2 thông tin để kết nối vào K8s API:

URL của K8s API Server.

Token của ServiceAccount prometheus vừa tạo.

Lấy K8s API Server URL:

```bash
kubectl cluster-info
```

Bạn sẽ thấy output như: `Kubernetes control plane is running at https://192.168.1.100:6443`. Hãy lưu lại URL này.

Lấy Token (K8s v1.24+): Tạo một Secret cho ServiceAccount để lấy token vĩnh viễn.

```bash
# Tạo Secret cho ServiceAccount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-token
  namespace: monitoring # Phải khớp với namespace SA
  annotations:
    kubernetes.io/service-account.name: prometheus
type: kubernetes.io/service-account-token
EOF

# Chờ 1-2s rồi lấy token (base64 decoded)
TOKEN=$(kubectl get secret prometheus-token -n monitoring -o jsonpath='{.data.token}' | base64 -d)
echo $TOKEN
```

Hãy sao chép giá trị Token này.

### 1.3. Cập nhật file prometheus.yml (Trên VM)
Bây giờ, hãy mở file prometheus.yml trên VM giám sát (nơi chạy Docker) và thêm các scrape_configs sau.

Lưu ý: Thay thế `https://172.16.21.111:6443` (ví dụ: https://192.168.1.100:6443) và `YOUR_BEARER_TOKEN` bằng các giá trị bạn vừa lấy.

```yaml
# Global configuration (or within scrape_configs)
scrape_configs:

  # Scrape Kubelet via API proxy to get cAdvisor metrics (actual CPU/Memory usage)
  - job_name: 'kubernetes-kubelet-cadvisor'
    scheme: https

    # Skip TLS verification (required for kubeadm clusters using self-signed certs)
    tls_config:
      insecure_skip_verify: true

    # Provide token for authentication with K8s API
    bearer_token: 'YOUR_BEARER_TOKEN'

    # Service Discovery: Ask K8s API for list of 'nodes'
    kubernetes_sd_configs:
      - api_server: 'https://172.16.21.111:6443'
        role: node
        # TLS and token config for the discovery process itself
        tls_config:
          insecure_skip_verify: true
        bearer_token: 'YOUR_BEARER_TOKEN'

    # Relabeling: Important to use API Proxy
    relabel_configs:
      # Optionally ignore master nodes if you don't want to monitor them
      # - source_labels: [__meta_kubernetes_node_label_kubernetes_io_role]
      #   regex: master
      #   action: drop

      # Map node labels
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

      # Set scrape target address to K8s API server (host:port, no scheme)
      - target_label: __address__
        replacement: 172.16.21.111:6443

      # Build metrics_path using K8s API proxy to cAdvisor per node
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

  # Scrape Kube-State-Metrics (Request/Limit/Status)
  - job_name: 'kubernetes-kube-state-metrics'

    # Service Discovery: Ask K8s API for list of 'endpoints'
    kubernetes_sd_configs:
      - api_server: 'https://172.16.21.111:6443'
        role: endpoints
        tls_config:
          insecure_skip_verify: true
        bearer_token: 'YOUR_BEARER_TOKEN'

    # Relabeling: Only retain endpoints for the kube-state-metrics service
    relabel_configs:
      # Keep only endpoints belonging to service with label app.kubernetes.io/name=kube-state-metrics (standard chart label)
      - source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
        regex: kube-state-metrics
        action: keep

      # Keep only endpoints with port named 'http-metrics' (port 8080)
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        regex: http-metrics
        action: keep

      # Attach namespace label from K8s
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
```

### 1.4. Khởi động lại và Xác minh
Khởi động lại Prometheus: Nếu Prometheus chạy bằng Docker, hãy khởi động lại container:

```bash
docker restart ten_container_prometheus
```

Xác minh: Mở giao diện Prometheus (`http://VM_IP:9090`).

- Vào tab "Status" -> "Targets". Bạn sẽ thấy 2 job mới `kubernetes-kubelet-cadvisor` và `kubernetes-kube-state-metrics`.
- Chờ vài phút, đảm bảo chúng có trạng thái "UP" (màu xanh).
- Trong ô query, thử `kube_pod_container_resource_limits` và `container_cpu_usage_seconds_total`. Nếu có dữ liệu là OK.

## 2. Cấu hình Grafana (Theo Mục 5)
Bây giờ chúng ta sẽ xây dựng Dashboard trên Grafana (chạy trên VM) để hiện thực hóa Mục 5 trong đề xuất của bạn.

### 2.1. Kết nối Data Source
Vào Grafana (http://VM_IP:3000).

"Connections" -> "Data sources" -> "Add new data source".

Chọn "Prometheus".

Nhập URL của Prometheus (ví dụ: http://localhost:9090 hoặc http://prometheus:9090 nếu chúng cùng mạng Docker).

"Save & Test".

### 2.2. Tạo Dashboard và Variables (Biến)
Tạo một Dashboard mới ("Create" -> "Dashboard").

Vào "Dashboard settings" (biểu tượng bánh răng) -> "Variables".

Tạo 3 biến lồng nhau y hệt như trong đề xuất của bạn:

Biến 1: namespace

Name: namespace

Type: Query

Query: `label_values(kube_namespace_labels, namespace)`

Multi-value: (Tắt)

Include All: (Bật)

Biến 2: service

Name: service

Type: Query

Query: `label_values(kube_service_labels{namespace="$namespace"}, service)`

Multi-value: (Tắt)

Include All: (Bật)

Biến 3: pod

Name: pod

Type: Query

Query: `label_values(kube_pod_labels{namespace="$namespace", label_app="$service"}, pod)`
Lưu ý: yêu cầu nhãn `app` trên Pod khớp với tên Service.

Multi-value: (Bật)

Include All: (Bật)

Nhấn "Apply" để lưu các biến.

### 2.3. Cấu hình Lặp Panel (Repeating Panel)
Quay lại Dashboard. Nhấn "Add" -> "Panel" -> "Add new row".

Click vào tiêu đề của Row (ví dụ "Row 1") và chọn "Row options".

Trong "Repeat options", chọn "Repeat for variable": pod.

Nhấn "Update".

Bây giờ, Row này sẽ tự động lặp lại cho mỗi Pod được chọn trong biến $pod.

### 2.4. Thêm các Panel Giám sát (Sử dụng PromQL từ Đề xuất)
Bây giờ, hãy thêm các Panel (Biểu đồ) vào bên trong Row lặp lại (Repeating Row) đó.

Nhấn "Add panel" (bên trong Row lặp).

Panel 1: % CPU Usage (so với Limit)

Title: % CPU Usage vs Limit ($pod)

Query (PromQL):

```promql
(
  sum by (pod) (
    rate(container_cpu_usage_seconds_total{namespace="$namespace", pod="$pod", container!=""}[5m])
  )
  / on(pod) group_left
  sum by (pod) (
    kube_pod_container_resource_limits{namespace="$namespace", pod="$pod", resource="cpu"}
  )
) * 100
```
Visualization: Chọn "Time series".

Standard options (bên phải): Unit -> Percent (0-100). Max: 100.

Panel 2: % Memory Usage (so với Limit)

Title: % Memory Usage vs Limit ($pod)

Query (PromQL):

```promql
(
  sum by (pod) (
    container_memory_working_set_bytes{namespace="$namespace", pod="$pod", container!=""}
  )
  / on(pod) group_left
  sum by (pod) (
    kube_pod_container_resource_limits{namespace="$namespace", pod="$pod", resource="memory"}
  )
) * 100
```
Visualization: Chọn "Time series".

Standard options: Unit -> Percent (0-100). Max: 100.

Panel 3: CPU Throttling (Phát hiện Limit quá thấp)

Title: CPU Throttling ($pod)

Query (PromQL):

```promql
sum(rate(container_cpu_cfs_throttled_seconds_total{namespace="$namespace", pod="$pod", container!=""}[5m])) by (pod)
```
Giải thích: Nếu biểu đồ này > 0, có nghĩa là K8s đang "bóp" (throttle) CPU của bạn.

Panel 4: OOM Kills (Phát hiện Memory Limit quá thấp)

Title: OOM Kills ($pod)

Query (PromQL):

```promql
sum(kube_pod_container_status_last_terminated_reason{namespace="$namespace", pod=~"$pod", reason="OOMKilled"}) by (pod)
```
Visualization: Chọn "Stat" (Chỉ số) hoặc "Time series" đều được.

Sau khi lưu Dashboard, bạn có thể chọn Namespace, Service, và xem toàn bộ các Pod của Service đó được hiển thị, mỗi Pod có một bộ 4 biểu đồ riêng, y hệt như mục tiêu trong đề xuất của bạn.

Chúc mừng bạn đã hoàn thành việc thiết lập!

Bạn có muốn tôi hỗ trợ thêm về cách tạo Alert (cảnh báo) trong Grafana/Prometheus dựa trên các metrics này không?

## 3. Cleanup / Rollback (khi cần)

Nếu muốn gỡ các thay đổi đã áp dụng trong cụm K8s và trên Prometheus VM:

```bash
# Xoá Secret chứa token (nếu đã tạo)
kubectl delete secret prometheus-token -n monitoring --ignore-not-found

# Xoá RBAC và ServiceAccount (nếu bạn còn file manifest)
kubectl delete -f prometheus-rbac.yaml --ignore-not-found

# Hoặc xoá thủ công nếu không còn file manifest
kubectl delete clusterrolebinding prometheus --ignore-not-found
kubectl delete clusterrole prometheus --ignore-not-found
kubectl delete serviceaccount prometheus -n monitoring --ignore-not-found
```

Trên Prometheus VM:

```bash
# Khôi phục/prometheus.yml (hoặc bỏ các block scrape_configs đã thêm)
# Sau đó restart Prometheus
docker restart ten_container_prometheus
```