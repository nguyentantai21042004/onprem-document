# Đề xuất Tích hợp Giám sát Kubernetes (K8s)

## 1. Mục tiêu

Mục tiêu chính của đề xuất này là xây dựng một hệ thống giám sát toàn diện, tập trung vào việc thu thập, lưu trữ, và trực quan hóa mức tiêu thụ tài nguyên thực tế và cấu hình tài nguyên (Request/Limit) của từng Pod/Container trong cụm K8s.

**Các mục tiêu chi tiết:**
- **Trực quan hóa chi tiết:** Tạo một Dashboard Template chuẩn trong Grafana để giám sát các chỉ số quan trọng của Pod (CPU Usage, Memory Usage, Network I/O) so với Request/Limit đã cấu hình.
- **Hỗ trợ tối ưu hóa:** Cung cấp dữ liệu chính xác để các kỹ sư có thể đưa ra quyết định thông minh về việc đặt lại Request và Limit cho Pods, qua đó tối ưu hóa việc sử dụng tài nguyên cụm K8s và tránh các vấn đề như CPU Throttling hoặc OOMKill (Out-of-Memory Kill).
- **Khả năng tái sử dụng:** Đảm bảo Dashboard có thể tái sử dụng cho bất kỳ Pod nào thông qua việc sử dụng Variables (Biến) trong Grafana.

## 2. Thực trạng Hiện tại của Hệ thống

| Thành phần                | Vị trí (Location)                 | Trạng thái      | Điểm mạnh/Yếu                                                                                   |
|---------------------------|-----------------------------------|-----------------|-------------------------------------------------------------------------------------------------|
| Hệ thống Giám sát         | Chạy trên Docker (VM riêng biệt)  | Đã sẵn sàng     | Đã có Prometheus (lưu trữ) và Grafana (trực quan hóa), nhưng thiếu dữ liệu K8s.                 |
| Cụm Kubernetes            | Cài đặt bằng Kubeadm (1 Master, 2 Node) | Đã sẵn sàng     |   |

## 3. Các Thành phần Cần Cài đặt và Lý do

| Thành phần Cần Cài đặt       | Vị trí Cài đặt             | Lý do Cần thiết                                                                                                                                 |
|-----------------------------|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Kube-State-Metrics (KS-M)   | Trong cụm K8s (Deployment) | Cung cấp Request/Limit: KS-M thu thập dữ liệu về trạng thái và cấu hình K8s (Deployment, Pods, Services). Đây là nguồn duy nhất cung cấp các metrics quan trọng như `kube_pod_container_resource_limits` và `kube_pod_container_resource_requests` để tính toán phần trăm sử dụng. |
| Scrape Configs              | Tệp prometheus.yml          | Thu thập dữ liệu: Cấu hình các job trong Prometheus để:  
  - Scrape KS-M (lấy Requests/Limits).  
  - Scrape Kubelet trên từng Node (lấy dữ liệu sử dụng CPU/Mem/Network thực tế từ cAdvisor). |

## 4. Use Case Thực tế và Cách Xử lý

Đây là cách hệ thống giám sát hoạt động và xử lý các thay đổi trong môi trường K8s:

### 4.1. Use Case: Giám sát và Đặt Limit/Request

| Hành động         | Vai trò của Dashboard                                                                                                            | Kết quả Tối ưu hóa                                                   |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------|
| Phân tích CPU     | Xem biểu đồ "% Sử dụng CPU so với Limit". Nếu thường xuyên đạt 100% và biểu đồ "CPU Throttling" tăng cao.                        | Tăng CPU Limit để tránh bị K8s hạn chế hiệu năng (throttle).         |
| Phân tích Memory  | Xem biểu đồ "% Sử dụng Memory so với Limit" và kiểm tra "Memory OOM Kills". Nếu Pod bị OOM Kill và sử dụng gần 100% Limit.       | Tăng Memory Limit/Request để tránh Pod bị Kernel K8s kết thúc (Kill), đảm bảo độ ổn định của dịch vụ. |
| Kiểm tra lãng phí | Xem biểu đồ "% Sử dụng CPU so với Request". Nếu mức sử dụng thực tế (ví dụ: 100m) thấp hơn nhiều so với Request (ví dụ: 1 core). | Giảm Request (ví dụ: xuống 200m) để giải phóng tài nguyên CPU cho Pod khác. |

### 4.2. Xử lý khi Update/Đổi tên Pod/Deployment

Việc sử dụng các công cụ giám sát Prometheus/Grafana được thiết kế để xử lý các thay đổi động này một cách tự động:

| Thay đổi xảy ra                     | Ảnh hưởng đến Metrics/Dashboard                                                                                              | Cách Hệ thống Xử lý                                                                                                                                                           |
|-------------------------------------|------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Đổi tên Pod (Do Deployment/ReplicaSet tự động tái tạo) | Tên Pod cũ biến mất, Pod mới có tên ngẫu nhiên (VD: app-v2-abc-**xyz**).                                                      | Prometheus Service Discovery và Variables Grafana tự động cập nhật. Prometheus sẽ ngừng scrape Pod cũ và bắt đầu scrape Pod mới. Variables `$pod` trong Grafana sẽ hiển thị tên Pod mới. |
| Update Deployment (Tăng/Giảm Pod)   | Số lượng Pod thay đổi.                                                                                                       | Kube-State-Metrics tự động gửi metrics mới về số lượng Pod. Prometheus sẽ tự động tìm và scrape các Pod mới thông qua Service Discovery (Kubernetes SD).                    |
| Cập nhật Request/Limit              | Giá trị Request/Limit cho Pod thay đổi.                                                                                      | Kube-State-Metrics theo dõi API Server và cập nhật ngay lập tức các metrics như `kube_pod_container_resource_limits`. Grafana sẽ hiển thị các giá trị cấu hình mới.        |

**Tóm lại:**  
Nhờ sử dụng Service Discovery của Prometheus và các metrics chuẩn (Kube-State-Metrics và cAdvisor), hệ thống giám sát của bạn sẽ hoàn toàn tự động theo dõi các thay đổi cấu hình và tên Pod/Deployment, đảm bảo Dashboard luôn hiển thị dữ liệu chính xác cho các Pod đang hoạt động.

## 5. Chọn Service → Tự động hiển thị N Pod (Grafana)

Mục tiêu: Khi chọn 1 Service, Dashboard tự liệt kê N Pod của Service đó và tạo N panel/row (mỗi panel/row đại diện 1 Pod) để so sánh Usage với Request/Limit.

### 5.1. Chuẩn hóa nhãn (khuyến nghị)

- Đặt cùng một nhãn (ví dụ `app`) trên Pod template của Deployment, và dùng nhãn đó làm selector của Service.
- Ví dụ:

```yaml
selector:
  app: my-service
```

Điều này giúp map Service → Pod một cách ổn định qua `kube_pod_labels` (kube-state-metrics).

### 5.2. Tạo Grafana Variables (lồng nhau)

1) Biến namespace

```promql
label_values(kube_namespace_labels, namespace)
```

2) Biến service (phụ thuộc namespace)

```promql
label_values(kube_service_labels{namespace="$namespace"}, service)
```

3) Biến pod (multi-value, include All) – lấy các Pod có nhãn trùng với Service đã chọn

Nếu dùng nhãn `app`:

```promql
label_values(kube_pod_labels{namespace="$namespace", label_app="$service"}, pod)
```

Nếu dùng chuẩn `app.kubernetes.io/name`:

```promql
label_values(kube_pod_labels{namespace="$namespace", label_app_kubernetes_io_name="$service"}, pod)
```

### 5.3. Lặp row/panel theo biến `$pod`

- Trong Row/Panel → Repeat options → Repeat by variable: chọn `$pod`.
- Tất cả truy vấn trong panel lọc theo `namespace="$namespace"` và `pod="$pod"` (và `container!=""` nếu dùng metrics container).

Ví dụ panel CPU usage (theo Pod):

```promql
rate(container_cpu_usage_seconds_total{namespace="$namespace", pod="$pod", container!=""}[5m])
```

So sánh Usage với CPU Limit (tỉ lệ):

```promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="$namespace", pod="$pod", container!=""}[5m])
)
/ on(pod) group_left
sum by (pod) (
  kube_pod_container_resource_limits{namespace="$namespace", pod="$pod", resource="cpu"}
)
```

Tương tự cho Memory (ví dụ % so với Limit):

```promql
sum by (pod) (
  container_memory_working_set_bytes{namespace="$namespace", pod="$pod", container!=""}
)
/ on(pod) group_left
sum by (pod) (
  kube_pod_container_resource_limits{namespace="$namespace", pod="$pod", resource="memory"}
)
```

Gợi ý thêm:
- Thêm biểu đồ CPU throttling: `rate(container_cpu_cfs_throttled_seconds_total{namespace="$namespace", pod="$pod"}[5m])`.
- Thêm thống kê OOMKill từ `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}` hoặc logs/alert tùy setup.

### 5.4. Trường hợp không có nhãn chung

Nếu Service không dùng nhãn trùng với Pod, có thể map thông qua selector của Service nhưng phức tạp hơn. Khuyến nghị tiêu chuẩn hóa nhãn (mục 5.1) để biến `$pod` trả về đúng N Pod của Service đã chọn và Dashboard hoạt động ổn định khi scale/rolling update.