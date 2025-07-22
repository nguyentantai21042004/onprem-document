# Các Khái Niệm Kubernetes và Cấu Hình YAML

## Mục Lục

- [Giới thiệu](#introduction)
- [Cơ bản về YAML](#yaml-configuration-basics)
- [Cấu trúc tài nguyên Kubernetes](#kubernetes-resource-structure)
- [Namespace](#namespaces)
- [Resource Quota](#resource-quotas)
- [Label và Selector](#labels-and-selectors)
- [Annotation](#annotations)
- [Quản lý cấu hình](#configuration-management)
- [Thực hành tốt](#best-practices)
- [Mẫu phổ biến](#common-patterns)
- [Khắc phục sự cố](#troubleshooting)

---

## Giới thiệu

Kubernetes sử dụng cấu hình khai báo để định nghĩa trạng thái mong muốn của ứng dụng và hạ tầng. Hướng dẫn này trình bày các khái niệm cơ bản và cấu trúc YAML cần thiết để làm việc hiệu quả với tài nguyên Kubernetes.

### Định dạng cấu hình

Kubernetes hỗ trợ nhiều định dạng cấu hình:

| Định dạng | Sử dụng | Ưu điểm | Nhược điểm |
|----------|---------|---------|------------|
| **YAML** | Phổ biến nhất | Dễ đọc, dễ chỉnh sửa | Nhạy cảm với thụt lề |
| **JSON** | Lập trình | Chính xác, máy đọc tốt | Dài dòng, khó đọc |
| **XML**  | Hiếm gặp | Có cấu trúc | Phức tạp, ít dùng |

**YAML** là định dạng khuyến nghị và phổ biến nhất trong hệ sinh thái Kubernetes.

---

## Cơ bản về YAML

### Cú pháp YAML cơ bản

```yaml
# Dòng chú thích bắt đầu bằng #
key: value
nested:
  key: value
  another_key: "giá trị có dấu nháy"
list:
  - item1
  - item2
  - item3
boolean: true
number: 42
multiline_string: |
  Đây là chuỗi nhiều dòng
folded_string: >
  Đây là chuỗi gập dòng
```

### Thực hành tốt với YAML

1. **Dùng 2 dấu cách để thụt lề** (không dùng tab)
2. **Dùng dấu nháy** khi chuỗi có ký tự đặc biệt
3. **Đặt tên ý nghĩa** cho tài nguyên
4. **Thêm chú thích** cho cấu hình phức tạp
5. **Kiểm tra YAML** trước khi áp dụng

---

## Cấu trúc tài nguyên Kubernetes

### Định dạng tài nguyên chung

Mọi tài nguyên Kubernetes đều theo cấu trúc:

```yaml
apiVersion: [Phiên bản API]
kind: [Loại tài nguyên]
metadata:
  [Thông tin metadata]
spec:
  [Đặc tả mong muốn]
status:
  [Trạng thái - chỉ đọc]
```

### Giải thích các trường

#### apiVersion

Chỉ định phiên bản API cho tài nguyên:

```yaml
# API lõi (v1) - Tài nguyên ổn định, tích hợp sẵn
apiVersion: v1

# Apps API (apps/v1) - Workload ứng dụng
apiVersion: apps/v1

# Batch API (batch/v1) - Job và CronJob
apiVersion: batch/v1

# Networking API (networking.k8s.io/v1) - Chính sách mạng, ingress
apiVersion: networking.k8s.io/v1

# RBAC API (rbac.authorization.k8s.io/v1) - Kiểm soát truy cập
apiVersion: rbac.authorization.k8s.io/v1

# Policy API (policy/v1) - Pod disruption budgets
apiVersion: policy/v1

# Autoscaling API (autoscaling/v2) - Tự động mở rộng pod
apiVersion: autoscaling/v2

# Storage API (storage.k8s.io/v1) - Lớp lưu trữ, volume
apiVersion: storage.k8s.io/v1
```

#### kind

Chỉ định loại tài nguyên Kubernetes:

```yaml
# Workload
kind: Pod                    # Đơn vị chứa container
kind: Deployment            # Quản lý replica set, rolling update
kind: StatefulSet           # Ứng dụng có trạng thái
kind: DaemonSet            # Đảm bảo pod chạy trên mọi node
kind: Job                  # Chạy một lần
kind: CronJob              # Chạy theo lịch

# Dịch vụ
kind: Service              # Cung cấp endpoint
kind: Ingress             # Định tuyến HTTP/HTTPS
kind: EndpointSlice       # Endpoint mạng

# Cấu hình & lưu trữ
kind: ConfigMap           # Dữ liệu cấu hình
kind: Secret             # Dữ liệu nhạy cảm
kind: PersistentVolume   # Lưu trữ
kind: PersistentVolumeClaim  # Yêu cầu lưu trữ
kind: StorageClass       # Lớp lưu trữ

# Namespace & định danh
kind: Namespace          # Không gian ảo
kind: ServiceAccount     # Định danh pod
kind: Role               # Quyền trong namespace
kind: ClusterRole        # Quyền toàn cụm
kind: RoleBinding        # Gán quyền
kind: ClusterRoleBinding # Gán quyền toàn cụm
```

#### metadata

Chứa thông tin nhận diện tài nguyên:

```yaml
metadata:
  name: webapp-deployment        # Tên tài nguyên (bắt buộc)
  namespace: production          # Namespace (tùy chọn, mặc định 'default')
  labels:                       # Nhãn tổ chức
    app: webapp
    version: v1.2.3
    environment: production
    team: backend
  annotations:                  # Metadata mở rộng
    description: "Ứng dụng web production"
    contact: "devops@company.com"
    last-updated: "2024-01-15"
    kubernetes.io/managed-by: "helm"
  finalizers:                   # Hook dọn dẹp
    - kubernetes.io/pv-protection
  ownerReferences:              # Quan hệ sở hữu
    - apiVersion: apps/v1
      kind: ReplicaSet
      name: webapp-rs-12345
      uid: 12345-67890-abcde
```

#### spec

Định nghĩa trạng thái mong muốn:

```yaml
spec:
  replicas: 3                   # Số lượng instance mong muốn
  selector:                     # Cách chọn pod
    matchLabels:
      app: webapp
  template:                     # Mẫu pod
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        env:
        - name: ENV_VAR
          value: "production"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: webapp-config
```

---

## Namespace

### Tổng quan

**Namespace** giúp chia tài nguyên cụm cho nhiều nhóm/người dùng. Lợi ích:

- **Cô lập tài nguyên** trong cụm
- **Phạm vi đặt tên**
- **Ranh giới kiểm soát truy cập**
- **Giới hạn tài nguyên**

### Namespace mặc định

```bash
# Liệt kê namespace
kubectl get namespaces
# hoặc
kubectl get ns
```

| Namespace | Mục đích |
|-----------|----------|
| **default** | Mặc định cho tài nguyên người dùng |
| **kube-system** | Thành phần hệ thống |
| **kube-public** | Ai cũng truy cập được |
| **kube-node-lease** | Thông tin heartbeat node |

### Tạo namespace

#### Khai báo (khuyến nghị)

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    name: development
    environment: dev
    team: backend
  annotations:
    description: "Môi trường phát triển cho backend"
    contact: "backend-team@company.com"
```

#### Lệnh trực tiếp

```bash
# Tạo namespace
kubectl create namespace development

# Áp dụng từ file
kubectl apply -f namespace.yaml

# Xóa namespace (CẢNH BÁO: xóa toàn bộ tài nguyên trong đó)
kubectl delete namespace development
```

### Cấu hình namespace

#### Đặt tên tài nguyên

```yaml
# Tài nguyên mặc định thuộc namespace
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
  namespace: development  # Chỉ rõ namespace
spec:
  containers:
  - name: webapp
    image: nginx:1.21
```

#### Giao tiếp giữa namespace

```yaml
# Service trong namespace 'backend'
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: backend
spec:
  selector:
    app: api
  ports:
  - port: 80
```

```yaml
# Pod ở 'frontend' truy cập service backend
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  namespace: frontend
spec:
  containers:
  - name: frontend
    image: nginx:1.21
    env:
    - name: API_URL
      value: "http://api-service.backend.svc.cluster.local:80"
```

### DNS trong namespace

```
# Định dạng DNS service
<service-name>.<namespace>.svc.cluster.local

# Ví dụ:
webapp.default.svc.cluster.local
api-service.backend.svc.cluster.local
database.production.svc.cluster.local

# Dạng rút gọn (cùng namespace):
webapp
webapp.default
webapp.default.svc
```

---

## Resource Quota

### Mục đích

Resource quota ngăn namespace chiếm quá nhiều tài nguyên, đảm bảo phân phối công bằng.

### Các loại quota

#### Quota tài nguyên tính toán

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: development
spec:
  hard:
    # CPU
    requests.cpu: "4"
    limits.cpu: "8"
    # RAM
    requests.memory: 8Gi
    limits.memory: 16Gi
    # GPU (nếu có)
    requests.nvidia.com/gpu: "2"
    limits.nvidia.com/gpu: "4"
```

#### Quota lưu trữ

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: development
spec:
  hard:
    # Lưu trữ
    requests.storage: 100Gi
    persistentvolumeclaims: "10"
    # Theo storage class
    requests.storage.class.gold: 20Gi
    requests.storage.class.silver: 50Gi
    requests.storage.class.bronze: 100Gi
```

#### Quota số lượng đối tượng

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-quota
  namespace: development
spec:
  hard:
    # Workload
    pods: "10"
    deployments.apps: "5"
    statefulsets.apps: "3"
    daemonsets.apps: "2"
    jobs.batch: "5"
    # Dịch vụ
    services: "5"
    ingresses.networking.k8s.io: "3"
    # Cấu hình
    configmaps: "10"
    secrets: "10"
    # Lưu trữ
    persistentvolumeclaims: "10"
```

### Quota tổng hợp

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: comprehensive-quota
  namespace: production
spec:
  hard:
    # Tính toán
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    # Lưu trữ
    requests.storage: 500Gi
    # Số lượng
    pods: "50"
    deployments.apps: "20"
    services: "20"
    configmaps: "50"
    secrets: "50"
    persistentvolumeclaims: "25"
    # Mạng
    ingresses.networking.k8s.io: "10"
    networkpolicies.networking.k8s.io: "5"
```

### Quản lý quota

```bash
# Áp dụng quota
kubectl apply -f resource-quota.yaml

# Xem quota
kubectl get resourcequota -n development

# Xem chi tiết quota
kubectl describe resourcequota comprehensive-quota -n production

# Theo dõi quota
kubectl get resourcequota -n production -o yaml
```

---

## Label và Selector

### Label

Label là cặp key-value gắn vào đối tượng để nhận diện, tổ chức:

```yaml
metadata:
  name: webapp-pod
  labels:
    app: webapp                 # Tên ứng dụng
    version: v1.2.3            # Phiên bản
    environment: production    # Môi trường
    tier: frontend             # Tầng ứng dụng
    team: backend              # Nhóm phụ trách
    release: stable            # Kênh phát hành
    component: web-server      # Loại thành phần
```

### Quy ước đặt label

```yaml
# Label chuẩn (khuyến nghị)
metadata:
  labels:
    # Nhận diện ứng dụng
    app.kubernetes.io/name: webapp
    app.kubernetes.io/instance: webapp-prod
    app.kubernetes.io/version: v1.2.3
    app.kubernetes.io/component: web-server
    app.kubernetes.io/part-of: ecommerce-platform
    # Quản lý
    app.kubernetes.io/managed-by: helm
    app.kubernetes.io/created-by: devops-team
    # Môi trường
    environment: production
    tier: frontend
    release: stable
```

### Selector

#### Selector dạng bằng

```yaml
# Selector trong deployment
spec:
  selector:
    matchLabels:
      app: webapp
      version: v1.2.3
# Selector trong service
spec:
  selector:
    app: webapp
    tier: frontend
```

#### Selector dạng tập hợp

```yaml
spec:
  selector:
    matchExpressions:
    - key: app
      operator: In
      values:
      - webapp
      - api-server
    - key: environment
      operator: NotIn
      values:
      - development
      - testing
    - key: version
      operator: Exists
    - key: deprecated
      operator: DoesNotExist
```

### Lệnh selector

```bash
# Chọn pod theo label
kubectl get pods -l app=webapp
kubectl get pods -l app=webapp,version=v1.2.3
# Theo sự tồn tại label
kubectl get pods -l version
# Theo không tồn tại label
kubectl get pods -l '!deprecated'
# Theo tập hợp
kubectl get pods -l 'app in (webapp,api-server)'
kubectl get pods -l 'environment notin (development,testing)'
```

---

## Annotation

### Mục đích

Annotation lưu metadata bổ sung không dùng để chọn lọc mà để cung cấp ngữ cảnh:

```yaml
metadata:
  annotations:
    # Thông tin triển khai
    deployment.kubernetes.io/revision: "3"
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment"...}
    # Thông tin build
    build.version: "1.2.3"
    build.commit: "abc123def456"
    build.date: "2024-01-15T10:30:00Z"
    build.branch: "main"
    # Liên hệ
    contact.email: "devops@company.com"
    contact.team: "backend-team"
    contact.slack: "#backend-alerts"
    # Tài liệu
    documentation.url: "https://docs.company.com/webapp"
    runbook.url: "https://runbook.company.com/webapp"
    # Giám sát
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
    # Bảo mật
    security.scan.date: "2024-01-15"
    security.scan.status: "passed"
    # Tuân thủ
    compliance.required: "true"
    compliance.framework: "SOC2"
```

### Mẫu annotation phổ biến

#### Annotation cho ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: "nginx"
```

#### Annotation cho service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    external-dns.alpha.kubernetes.io/hostname: "webapp.company.com"
```

---

## Quản lý cấu hình

### Mẫu sử dụng ConfigMap

#### Biến môi trường

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
data:
  database_host: "db.company.com"
  database_port: "5432"
  redis_host: "redis.company.com"
  log_level: "INFO"
  feature_flags: "feature_a=true,feature_b=false"
```

```yaml
# Sử dụng ConfigMap trong Pod
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    envFrom:
    - configMapRef:
        name: webapp-config
    env:
    - name: SPECIFIC_CONFIG
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_host
```

#### File cấu hình

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /api {
            proxy_pass http://backend-service:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
```

```yaml
# Mount ConfigMap làm volume
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

### Quản lý Secret

#### Secret cơ bản

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
data:
  database-password: cGFzc3dvcmQxMjM=  # base64 encoded
  api-key: YWJjZGVmZ2hpams=            # base64 encoded
```

#### TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-tls
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi...  # base64 encoded private key
```

#### Docker Registry Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6... # base64 encoded docker config
```

---

## Thực hành tốt

### Cấu trúc YAML

1. **Đặt tên ý nghĩa**: `webapp-deployment` thay vì `deployment-1`
2. **Luôn chỉ rõ namespace**
3. **Dán nhãn nhất quán**
4. **Thêm annotation**
5. **Thụt lề đúng chuẩn**: 2 dấu cách, không tab
6. **Kiểm tra YAML**: Dùng `yamllint` hoặc `kubeval`

### Tổ chức tài nguyên

```yaml
# Cấu trúc tốt
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: production
  labels:
    app: webapp
    version: v1.2.3
    environment: production
    tier: frontend
  annotations:
    description: "Ứng dụng web production"
    maintainer: "backend-team@company.com"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: v1.2.3
  template:
    metadata:
      labels:
        app: webapp
        version: v1.2.3
        environment: production
        tier: frontend
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Bảo mật

1. **Dùng Secret cho dữ liệu nhạy cảm**: Không để mật khẩu trong ConfigMap
2. **Giới hạn truy cập tài nguyên**: Dùng ResourceQuota, NetworkPolicy
3. **Đặt giới hạn tài nguyên**: Tránh cạn kiệt tài nguyên
4. **Chạy container không root**: Tăng bảo mật
5. **Quét bảo mật thường xuyên**

---

## Mẫu phổ biến

### Cấu hình đa môi trường

```yaml
# Cấu hình cơ bản
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-base
data:
  log_format: "json"
  timeout: "30s"
---
# Overlay cho môi trường
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-production
data:
  log_level: "WARN"
  database_pool_size: "20"
  cache_ttl: "300s"
```

### Label cho Blue-Green Deployment

```yaml
# Blue deployment
metadata:
  labels:
    app: webapp
    version: v1.2.3
    slot: blue
# Green deployment
metadata:
  labels:
    app: webapp
    version: v1.2.4
    slot: green
```

### Mẫu Canary Deployment

```yaml
# Stable deployment
spec:
  replicas: 9
  selector:
    matchLabels:
      app: webapp
      track: stable
# Canary deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
```

---

## Khắc phục sự cố

### Lỗi YAML thường gặp

1. **Lỗi thụt lề**: Dùng 2 dấu cách nhất quán
2. **Thiếu trường bắt buộc**
3. **Selector không hợp lệ**
4. **Namespace không đúng**
5. **Giới hạn tài nguyên**

### Lệnh debug

```bash
# Kiểm tra cú pháp YAML
kubectl apply --dry-run=client -f deployment.yaml

# Xem trạng thái tài nguyên
kubectl get deployment webapp-deployment -o yaml

# Xem sự kiện
kubectl get events --sort-by='.lastTimestamp'

# Xem chi tiết
kubectl describe deployment webapp-deployment

# Xem quota
kubectl describe resourcequota -n production
```

---

## Bước tiếp theo

Sau khi nắm vững các khái niệm Kubernetes:

1. **Quản lý workload**: Hiểu Deployment, Service...
2. **Mẫu nâng cao**: StatefulSet, DaemonSet, Job
3. **Thiết lập CI/CD**: Tích hợp Jenkins/GitLab CI
4. **Giám sát**: Thêm Prometheus, Grafana
5. **Bảo mật**: RBAC, Network Policy, Pod Security

Tham khảo thêm:
- [Thiết lập cụm](cluster-setup.md)
- [Quản lý workload](workloads.md)
- [Công cụ quản lý](management-tools.md)
- [Tích hợp CI/CD](cicd-integration.md)

---

## Kết luận

Hiểu các khái niệm Kubernetes và cấu hình YAML là nền tảng cho vận hành container thành công. Tính khai báo giúp bạn định nghĩa trạng thái mong muốn và hệ thống sẽ tự duy trì.

Sử dụng namespace, label, annotation, quota đúng cách giúp tổ chức, mở rộng và bảo trì hệ thống hiệu quả. Thực hành thường xuyên sẽ nâng cao kỹ năng thiết kế, quản lý hệ thống container phức tạp. 