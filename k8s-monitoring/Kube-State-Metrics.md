## Cài đặt Kube-State-Metrics (KS-M)
KS-M rất quan trọng vì nó cung cấp metrics về Request/Limit (`kube_pod_container_resource_limits` và `kube_pod_container_resource_requests`).

### 1) Chuẩn bị
- Truy cập vào Master Node của K8s.
- Áp dụng các file manifest chính thức từ GitHub (nên kiểm tra phiên bản mới nhất, các URL dưới đây thường ổn định).

### 2) Cài đặt Kube-State-Metrics

```bash
# Tạo namespace nếu muốn tách riêng (có thể dùng kube-system)
kubectl create namespace monitoring || true

# Áp dụng các thành phần của Kube-State-Metrics (từ repo chính thức)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role-binding.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service-account.yaml
```

Xác minh (kube-state-metrics thường chạy trong `kube-system` theo manifest chính thức):

```bash
kubectl get pods -n kube-system | grep kube-state-metrics
```

### 3) Cài đặt Metrics Server (MS)
MS cần thiết cho `kubectl top` và HPA.

```bash
# Cài đặt Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Khắc phục sự cố (Kubeadm) — Kubelet thường dùng chứng chỉ tự ký, Metrics Server có thể từ chối kết nối. Patch để bỏ qua xác minh TLS:

```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
 
# (Khuyến nghị) Ưu tiên dùng InternalIP để giảm mismatch hostname/cert
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP"}]'
```

Xác minh sau 1–2 phút:

```bash
kubectl top node
kubectl top pod -n kube-system
```

Nếu hai lệnh trên trả về mức sử dụng CPU/Memory, Metrics Server đã hoạt động.

Lưu ý bảo mật về `--kubelet-insecure-tls`:
- Cờ này tắt xác minh chứng chỉ TLS khi Metrics Server gọi kubelet trên cổng 10250. Dữ liệu metrics vẫn đi qua HTTPS nhưng không kiểm tra danh tính máy chủ → có rủi ro MITM trong mạng không tin cậy.
- Phù hợp cho môi trường lab/POC hoặc mạng nội bộ tin cậy. Với production, nên cấp chứng chỉ kubelet hợp lệ (có IP/hostname trong SAN) để không cần cờ này.

Rollback (xóa cờ khi không cần nữa):
- Cách đơn giản và an toàn nhất: áp lại manifest chính thức để reset spec của Deployment.

```bash
# Re-apply manifest chính thức để reset Deployment về trạng thái gốc (không có cờ insecure)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deploy/metrics-server
```

- Nếu muốn bỏ chỉ 1 cờ mà không áp lại toàn bộ, bạn có thể `kubectl edit deploy/metrics-server -n kube-system` và xóa dòng `--kubelet-insecure-tls` trong `spec.template.spec.containers[0].args`, sau đó lưu lại. (Xóa bằng JSON patch cần chỉ số index chính xác trong mảng args, nên không khuyến nghị cho script tổng quát.)

### 4) Xác nhận metrics hoạt động

#### KS-M trả về đúng metric tên cần dùng

```bash
kubectl -n kube-system port-forward svc/kube-state-metrics 8080:8080
curl -s localhost:8080/metrics | \
  grep -E 'kube_pod_container_resource_(limits|requests)|kube_pod_labels|kube_deployment_labels'
```

Kỳ vọng thấy các metric: `kube_pod_container_resource_limits`, `kube_pod_container_resource_requests`, `kube_pod_labels`.

#### Prometheus đang scrape KS-M và có dữ liệu

Trong Prometheus UI hoặc Grafana Explore chạy:

```promql
up{job=~"kube-state-metrics"} == 1
```

Xác nhận có series cho request/limit:

```promql
kube_pod_container_resource_limits{resource="cpu"}
kube_pod_container_resource_limits{resource="memory"}
kube_pod_container_resource_requests{resource="cpu"}
kube_pod_container_resource_requests{resource="memory"}
```

Kiểm tra nhãn để map Service → Pod:

```promql
topk(5, count by (namespace, pod) (kube_pod_labels))
label_values(kube_pod_labels{namespace="your-ns"}, label_app)
```

Nếu dùng chuẩn nhãn khác:

```promql
label_values(kube_pod_labels{namespace="your-ns"}, label_app_kubernetes_io_name)
```

#### Có dữ liệu usage từ cAdvisor/Kubelet

```promql
rate(container_cpu_usage_seconds_total{container!=""}[5m])
container_memory_working_set_bytes{container!=""}
```

Nếu rỗng, kiểm tra Prometheus đã cấu hình scrape Kubelet/cAdvisor.

#### Sanity check công thức so sánh Usage vs Limit

```promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="your-ns", container!=""}[5m])
)
/ on(pod) group_left
sum by (pod) (
  kube_pod_container_resource_limits{namespace="your-ns", resource="cpu"}
)
```

Giá trị phải > 0 và biến động theo tải.

#### Troubleshooting nhanh

```bash
# KS-M pod/logs
kubectl -n kube-system get pods -l app.kubernetes.io/name=kube-state-metrics
kubectl -n kube-system logs deploy/kube-state-metrics

# Kiểm tra targets Prometheus (UI Targets) và job name kube-state-metrics
# Kiểm tra nhãn trên Deployment/Service phù hợp (ví dụ app) để "kube_pod_labels" hiển thị label_app
```

### 5) Cleanup (gỡ bỏ hoàn toàn khi cần)

Trong trường hợp cần rollback/cleanup, chạy các lệnh sau để xóa tất cả tài nguyên đã cài đặt từ các manifest ở trên.

```bash
# Gỡ Kube-State-Metrics (xóa theo đúng manifest đã apply)
kubectl delete -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service-account.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/deployment.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role-binding.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/cluster-role.yaml --ignore-not-found

# Gỡ Metrics Server
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --ignore-not-found

# (Tùy chọn) Nếu bạn đã tạo namespace riêng cho monitoring và không dùng nữa
kubectl delete namespace monitoring --ignore-not-found
```

Lưu ý:
- Nếu bạn đã chỉnh sửa manifest (ví dụ đổi namespace), hãy xóa theo đúng file/namespace đã áp dụng.
- Các tài nguyên cluster-scoped (ClusterRole, ClusterRoleBinding) cần xóa theo manifest tương ứng như trên.