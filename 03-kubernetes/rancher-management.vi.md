# Quản Lý Rancher

## Mục Lục
1. [Tổng quan Rancher](#rancher-overview)
2. [Yêu cầu tiên quyết](#prerequisites)
3. [Cài đặt](#installation)
4. [Cấu hình ban đầu](#initial-configuration)
5. [Quản lý cụm](#cluster-management)
6. [Quản lý người dùng](#user-management)
7. [Quản lý Project & Namespace](#project-and-namespace-management)
8. [Giám sát & cảnh báo](#monitoring-and-alerting)
9. [Thực hành tốt](#best-practices)
10. [Khắc phục sự cố](#troubleshooting)

## Tổng quan Rancher

Rancher là nền tảng quản lý container toàn diện, cung cấp bộ công cụ đầy đủ cho các đội nhóm triển khai container. Rancher giải quyết các thách thức vận hành và bảo mật khi quản lý nhiều cụm Kubernetes trên mọi hạ tầng.

### Tính năng nổi bật

- **Quản lý đa cụm**: Triển khai và quản lý nhiều cụm Kubernetes
- **Xác thực tập trung**: Tích hợp AD, LDAP, GitHub...
- **Đa nhiệm dự án**: Tổ chức tài nguyên theo project, RBAC
- **Tích hợp giám sát**: Monitoring, logging, alerting sẵn có
- **Catalog ứng dụng**: Triển khai từ Helm chart, catalog tùy chỉnh
- **Pipeline DevOps**: CI/CD tích hợp GitHub, GitLab

### Thành phần kiến trúc

- **Rancher Server**: Giao diện quản lý chính và API
- **Rancher Agent**: Chạy trên mỗi node cụm được quản lý
- **Cluster**: Cụm Kubernetes do Rancher quản lý
- **Project**: Nhóm logic các namespace trong cụm
- **Workload**: Deployment, StatefulSet, DaemonSet, Job, CronJob

## Yêu cầu tiên quyết

### Yêu cầu hệ thống

#### Rancher Server
- **CPU**: Tối thiểu 4 vCPU
- **RAM**: Tối thiểu 8GB
- **Lưu trữ**: Tối thiểu 50GB SSD
- **OS**: Ubuntu 20.04 LTS hoặc CentOS 8

#### Cụm được quản lý
- **CPU**: Tối thiểu 2 vCPU/node
- **RAM**: Tối thiểu 4GB/node
- **Lưu trữ**: Tối thiểu 20GB/node
- **Mạng**: Tất cả node phải kết nối được Rancher server

### Yêu cầu mạng

```bash
# Các cổng cần thiết cho Rancher server
# 80/443 - HTTP/HTTPS
# 6443 - Kubernetes API server
# 2379-2380 - etcd
# 10250 - Kubelet API
# 10251 - kube-scheduler
# 10252 - kube-controller-manager
```

## Cài đặt

### Cách 1: Cài bằng Docker (1 node)

```bash
# Tạo thư mục dữ liệu
sudo mkdir -p /opt/rancher
sudo chown -R 1000:1000 /opt/rancher

# Chạy Rancher server
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /opt/rancher:/var/lib/rancher \
  --privileged \
  rancher/rancher:latest

# Kiểm tra
sudo docker logs rancher
```

### Cách 2: Cài trên Kubernetes (HA)

```bash
# Thêm repo Helm Rancher
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Tạo namespace
kubectl create namespace cattle-system

# Cài cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Cài Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=your-email@domain.com

# Kiểm tra
kubectl -n cattle-system get pods
```

### Cách 3: Cài thủ công với lưu trữ riêng

```bash
# Chuẩn bị ổ đĩa
sudo fdisk -l
sudo mkfs.ext4 /dev/sdb
sudo mkdir /var/lib/rancher
sudo mount /dev/sdb /var/lib/rancher

# Gắn mount vĩnh viễn
echo "/dev/sdb /var/lib/rancher ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Cài Docker nếu chưa có
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable docker
sudo systemctl start docker

# Chạy Rancher với lưu trữ riêng
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /var/lib/rancher:/var/lib/rancher \
  -v /var/log/rancher:/var/log/rancher \
  --privileged \
  rancher/rancher:latest
```

## Cấu hình ban đầu

### Truy cập lần đầu

1. **Truy cập giao diện Rancher**:
   ```
   https://your-rancher-server
   ```
2. **Đặt mật khẩu admin**:
   ```bash
   # Lấy mật khẩu bootstrap nếu dùng Helm
   kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'
   ```
3. **Cấu hình URL server**:
   Đặt URL trùng domain hoặc IP

### Cấu hình SSL/TLS

```bash
# Tạo chứng chỉ tự ký
openssl req -x509 -newkey rsa:4096 -keyout rancher.key -out rancher.crt -days 365 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=rancher.yourdomain.com"

# Tạo secret trên Kubernetes
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=rancher.crt \
  --key=rancher.key

# Cập nhật Rancher
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set ingress.tls.source=secret \
  --set ingress.tls.secretName=tls-rancher-ingress
```

## Quản lý cụm

### Import cụm có sẵn

1. **Từ giao diện Rancher**:
   - Vào "Cluster Management"
   - Chọn "Import Existing"
   - Nhập tên, mô tả cụm
   - Copy lệnh được cung cấp
2. **Chạy trên cụm cần import**:
   ```bash
   # Áp dụng manifest
   kubectl apply -f https://rancher.yourdomain.com/v3/import/xxx.yaml
   ```

### Tạo cụm mới

#### Tạo cụm RKE2

```bash
# Tạo file cấu hình cụm
cat > cluster.yml << EOF
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: production-cluster
  namespace: fleet-default
spec:
  kubernetesVersion: v1.26.8+rke2r1
  rkeConfig:
    machineGlobalConfig:
      cni: calico
      disable-kube-proxy: false
      etcd-expose-metrics: false
    machinePools:
    - name: master-pool
      quantity: 3
      etcdRole: true
      controlPlaneRole: true
      workerRole: false
      machineConfigRef:
        kind: VmwarevsphereConfig
        name: master-config
    - name: worker-pool
      quantity: 3
      etcdRole: false
      controlPlaneRole: false
      workerRole: true
      machineConfigRef:
        kind: VmwarevsphereConfig
        name: worker-config
EOF

kubectl apply -f cluster.yml
```

### Nâng cấp cụm

```bash
# Liệt kê phiên bản Kubernetes khả dụng
kubectl get kontainerdriver
# Nâng cấp cụm
kubectl patch cluster production-cluster -p '{"spec":{"kubernetesVersion":"v1.27.5+rke2r1"}}' --type merge
# Theo dõi tiến trình
kubectl get cluster production-cluster -o yaml
```

## Quản lý người dùng

### Cấu hình xác thực

#### Tích hợp Active Directory

```yaml
apiVersion: management.cattle.io/v3
kind: ActiveDirectoryConfig
metadata:
  name: activedirectory
spec:
  servers:
  - "ldap://your-ad-server:389"
  serviceAccountUsername: "rancher@yourdomain.com"
  serviceAccountPassword: "password"
  userSearchBase: "ou=users,dc=yourdomain,dc=com"
  groupSearchBase: "ou=groups,dc=yourdomain,dc=com"
  userObjectClass: "person"
  userLoginAttribute: "sAMAccountName"
  userNameAttribute: "name"
  userEnabledAttribute: "userAccountControl"
  groupObjectClass: "group"
  groupNameAttribute: "name"
  groupMemberUserAttribute: "distinguishedName"
  groupMemberMapAttribute: "member"
  connectionTimeout: 5000
  requestTimeout: 5000
```

#### Xác thực GitHub

```yaml
apiVersion: management.cattle.io/v3
kind: GithubConfig
metadata:
  name: github
spec:
  clientId: "your-github-client-id"
  clientSecret: "your-github-client-secret"
  hostname: "github.com"
  tls: true
```

### RBAC

#### Global Role

```yaml
apiVersion: management.cattle.io/v3
kind: GlobalRole
metadata:
  name: custom-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

#### Cluster Role

```yaml
apiVersion: management.cattle.io/v3
kind: RoleTemplate
metadata:
  name: cluster-viewer
context: cluster
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
```

#### Project Role

```yaml
apiVersion: management.cattle.io/v3
kind: RoleTemplate
metadata:
  name: project-developer
context: project
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
```

## Quản lý Project & Namespace

### Tạo Project

```yaml
apiVersion: management.cattle.io/v3
kind: Project
metadata:
  name: production-project
  namespace: c-cluster-id
spec:
  clusterId: "c-cluster-id"
  displayName: "Production Project"
  description: "Môi trường production"
  resourceQuota:
    limit:
      requestsCpu: "10000m"
      requestsMemory: "20Gi"
      persistentvolumeclaims: "10"
```

### Quản lý Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production-app
  labels:
    field.cattle.io/projectId: "c-cluster-id:p-project-id"
  annotations:
    field.cattle.io/projectId: "c-cluster-id:p-project-id"
spec:
  finalizers:
  - controller.cattle.io/namespace-auth
```

### Resource Quota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production-app
spec:
  hard:
    requests.cpu: "4000m"
    requests.memory: "8Gi"
    limits.cpu: "8000m"
    limits.memory: "16Gi"
    persistentvolumeclaims: "5"
    pods: "10"
    services: "5"
```

## Giám sát & cảnh báo

### Bật monitoring

```bash
# Bật monitoring cụm
kubectl patch cluster production-cluster -p '{"spec":{"enableClusterMonitoring":true}}' --type merge
# Bật monitoring project
kubectl patch project production-project -p '{"spec":{"enableProjectMonitoring":true}}' --type merge
```

### Alert tùy chỉnh

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: cattle-monitoring-system
spec:
  groups:
  - name: cluster.rules
    rules:
    - alert: NodeDown
      expr: up{job="node-exporter"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Node {{ $labels.instance }} is down"
        description: "Node {{ $labels.instance }} đã down hơn 5 phút"
```

## Thực hành tốt

### Bảo mật

1. **Bật RBAC**: Luôn dùng kiểm soát truy cập
2. **Cập nhật thường xuyên**: Luôn update Rancher và agent
3. **Phân đoạn mạng**: Cô lập mạng cụm
4. **Bật audit log**: Theo dõi log audit
5. **Quản lý secret**: Dùng Secret cho dữ liệu nhạy cảm

### Vận hành

1. **Backup định kỳ**: Backup etcd và dữ liệu Rancher
2. **Giám sát**: Triển khai monitoring đầy đủ
3. **Giới hạn tài nguyên**: Đặt quota hợp lý
4. **Tổ chức cụm**: Dùng project cho đa nhiệm
5. **Tự động hóa**: Script hóa quản lý cụm

### Tối ưu hiệu năng

```yaml
# Tối ưu Rancher server
apiVersion: v1
kind: ConfigMap
metadata:
  name: rancher-config
  namespace: cattle-system
data:
  CATTLE_AGENT_LOGLEVEL: "info"
  CATTLE_SERVER_LOGLEVEL: "info"
  CATTLE_PROMETHEUS_METRICS: "true"
  CATTLE_FEATURES: "multi-cluster-management=true"
```

## Khắc phục sự cố

### Vấn đề thường gặp

#### 1. Import cụm lỗi

```bash
# Xem log agent
kubectl logs -n cattle-system deployment/cattle-cluster-agent
# Xem log node agent
kubectl logs -n cattle-system daemonset/cattle-node-agent
# Kiểm tra kết nối
curl -k https://rancher.yourdomain.com/ping
```

#### 2. Lỗi xác thực

```bash
# Xem log provider xác thực
kubectl logs -n cattle-system deployment/rancher
# Kiểm tra cấu hình xác thực
kubectl get authconfig -o yaml
```

#### 3. Lỗi hiệu năng

```bash
# Kiểm tra tài nguyên
kubectl top nodes
kubectl top pods -n cattle-system
# Theo dõi etcd
kubectl exec -n cattle-system etcd-xxx -- etcdctl endpoint status
```

### Lệnh chẩn đoán

```bash
# Kiểm tra trạng thái Rancher server
kubectl get pods -n cattle-system
kubectl describe pod -n cattle-system rancher-xxx
# Kiểm tra trạng thái cụm
kubectl get clusters
kubectl describe cluster production-cluster
# Kiểm tra project, namespace
kubectl get projects
kubectl get namespaces
# Backup cấu hình cụm
kubectl get cluster production-cluster -o yaml > cluster-backup.yaml
```

### Khôi phục

#### Khôi phục Rancher server

```bash
# Dừng container Rancher
sudo docker stop rancher
# Backup dữ liệu
sudo cp -r /var/lib/rancher /backup/rancher-$(date +%Y%m%d)
# Chạy lại Rancher với backup
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /backup/rancher-20240101:/var/lib/rancher \
  --privileged \
  rancher/rancher:latest
```

#### Khôi phục cụm

```bash
# Restore từ backup
kubectl apply -f cluster-backup.yaml
# Cài lại agent nếu cần
kubectl apply -f https://rancher.yourdomain.com/v3/import/xxx.yaml
```

## Tích hợp

### Tích hợp CI/CD

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rancher-pipeline-config
data:
  rancher-url: "https://rancher.yourdomain.com"
  cluster-id: "c-cluster-id"
  project-id: "p-project-id"
```

### Tích hợp monitoring

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: rancher-monitoring
spec:
  selector:
    matchLabels:
      app: rancher
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

Hướng dẫn này cung cấp mọi thứ cần thiết để triển khai và quản lý Rancher cho hạ tầng Kubernetes, theo triết lý: dùng GUI để hiểu, sau đó chuẩn hóa YAML cho production. 