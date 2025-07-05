# Hướng dẫn File YAML Configuration trong Kubernetes

## Tổng quan về File Configuration

Kubernetes hỗ trợ cấu hình qua nhiều định dạng file:
- **YAML** - Phổ biến nhất, dễ đọc và viết
- **JSON** - Hỗ trợ nhưng ít được sử dụng  
- **XML** - Hỗ trợ nhưng không thông dụng

**YAML** là định dạng được khuyến nghị và sử dụng rộng rãi nhất trong K8s ecosystem.

---

## Cấu trúc YAML cơ bản trong Kubernetes

Mọi resource YAML trong K8s đều có 4 thành phần chính:

```yaml
apiVersion: [version]
kind: [resource-type]
metadata:
  [metadata-info]
spec:
  [resource-specification]
```

---

## 1. apiVersion

Xác định phiên bản API để tạo object. Các giá trị phổ biến:

```yaml
# Core API
apiVersion: v1

# Apps API
apiVersion: apps/v1

# Batch API  
apiVersion: batch/v1

# Networking API
apiVersion: networking.k8s.io/v1

# Policy API
apiVersion: policy/v1

# RBAC API
apiVersion: rbac.authorization.k8s.io/v1

# Autoscaling API
apiVersion: autoscaling/v1

# Storage API
apiVersion: storage.k8s.io/v1
```

### Mapping apiVersion với Kind:

| apiVersion | Suitable for |
|------------|-------------|
| `v1` | Pod, Service, ConfigMap, Secret, PV, PVC |
| `apps/v1` | Deployment, StatefulSet, DaemonSet |
| `batch/v1` | Job, CronJob |
| `networking.k8s.io/v1` | Ingress, NetworkPolicy |
| `policy/v1` | PodDisruptionBudget |

---

## 2. kind

Xác định loại tài nguyên Kubernetes cần tạo:

```yaml
# Workload Resources
kind: Pod                    # Single container unit
kind: Deployment            # Manages ReplicaSets and Pods
kind: StatefulSet           # For stateful applications
kind: DaemonSet            # Ensures pods run on every node

# Service Resources  
kind: Service              # Expose applications
kind: Ingress             # HTTP/HTTPS routing

# Storage Resources
kind: PersistentVolume     # Cluster storage resource
kind: PersistentVolumeClaim # Request for storage

# Configuration Resources
kind: ConfigMap           # Non-sensitive configuration data
kind: Secret             # Sensitive data (passwords, tokens)

# Other Resources
kind: Namespace          # Virtual cluster isolation
kind: ServiceAccount     # Identity for processes in pods
```

---

## 3. metadata

Chứa thông tin meta của resource:

```yaml
metadata:
  name: my-app                    # Tên resource (bắt buộc)
  namespace: development          # Namespace chứa resource
  labels:                        # Key-value pairs để organize
    app: web-server
    version: v1.0
    environment: production
  annotations:                   # Key-value pairs để metadata
    description: "Main web application"
    managed-by: "DevOps Team"
    last-updated: "2025-01-15"
```

### Labels vs Annotations:

| Labels | Annotations |
|--------|-------------|
| Dùng để select/query objects | Metadata không dùng để select |
| Giới hạn 63 ký tự | Không giới hạn độ dài |
| Chỉ chấp nhận alphanumeric | Chấp nhận mọi ký tự |
| Dùng cho selectors | Dùng cho documentation |

---

## 4. spec

Mô tả chi tiết cấu hình của resource. Nội dung thay đổi tùy theo `kind`:

### Pod spec example:
```yaml
spec:
  containers:
  - name: web-server
    image: nginx:1.20
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "128Mi"
        cpu: "250m"
      limits:
        memory: "256Mi"
        cpu: "500m"
```

### Service spec example:
```yaml
spec:
  selector:
    app: web-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

---

## Kubernetes Namespaces

### Khái niệm

**Namespace** là cách tổ chức và phân tách tài nguyên trong cụm K8s để:
- Chia nhỏ tài nguyên thành các không gian logic
- Quản lý và vận hành dễ dàng hơn
- Cô lập môi trường (dev, staging, prod)
- Áp dụng policies và resource quotas

### Default Namespaces

```bash
# Xem tất cả namespaces
kubectl get namespaces
# hoặc
kubectl get ns
```

**Namespaces mặc định:**
- `default` - Namespace mặc định cho user objects
- `kube-system` - Chứa objects do K8s system tạo
- `kube-public` - Có thể đọc được bởi tất cả users
- `kube-node-lease` - Chứa lease objects của nodes

### Tạo Namespace

#### File `ns.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev
    team: backend
```

#### Áp dụng namespace:
```bash
kubectl apply -f ns.yaml
```

---

## Resource Quotas

Giới hạn tài nguyên trong namespace để tránh một team/project tiêu thụ quá nhiều tài nguyên.

### File `resourcequota.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    # Compute Resources
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8" 
    limits.memory: 16Gi
    
    # Storage Resources
    requests.storage: 100Gi
    persistentvolumeclaims: "4"
    
    # Object Count Quotas
    pods: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
```

### Áp dụng Resource Quota:
```bash
kubectl apply -f resourcequota.yaml
```

### Kiểm tra quota:
```bash
# Xem quota trong namespace
kubectl get quota -n development

# Xem chi tiết quota usage
kubectl describe quota dev-quota -n development
```

---

## Workflow thực tế

Từ command history có thể thấy workflow điển hình:

```bash
# 1. Kiểm tra nodes
kubectl get nodes

# 2. Kiểm tra pods và namespaces
kubectl get pods
kubectl get pods --namespace default
kubectl get ns

# 3. Tạo cấu trúc project
mkdir projects
cd projects
mkdir dev
cd dev

# 4. Tạo và áp dụng namespace
vi ns.yaml
kubectl apply -f ns.yaml
kubectl get ns

# 5. Tạo resource quota
vi resourcequota.yaml
kubectl apply -f resourcequota.yaml
```

---

## Best Practices

### Namespace Naming Convention:
```yaml
# Good examples
development
staging  
production
team-frontend
project-ecommerce
```

### File Organization:
```
projects/
├── dev/
│   ├── ns.yaml
│   ├── resourcequota.yaml
│   └── apps/
├── staging/
└── prod/
```

### Labels Strategy:
```yaml
metadata:
  labels:
    app: web-server           # Application name
    version: v1.2.3          # Version
    component: frontend      # Component type
    environment: production  # Environment
    team: platform          # Owning team
```

### Resource Management:
- Luôn set resource requests và limits
- Sử dụng ResourceQuota để control namespace
- Monitor resource usage thường xuyên
- Implement LimitRanges cho default values

---

## Các lệnh kubectl hữu ích

```bash
# Namespace operations
kubectl create namespace my-namespace
kubectl delete namespace my-namespace
kubectl config set-context --current --namespace=my-namespace

# Resource operations với namespace
kubectl get pods -n my-namespace
kubectl apply -f app.yaml -n my-namespace
kubectl delete -f app.yaml -n my-namespace

# Cross-namespace operations
kubectl get pods --all-namespaces
kubectl get services -A  # Short for --all-namespaces
```