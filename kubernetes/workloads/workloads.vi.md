# Quản Lý Workloads Kubernetes

## Mục Lục

- [Giới thiệu](#introduction)
- [Triển khai (Deployments)](#deployments)
- [Dịch vụ (Services)](#services)
- [ConfigMap](#configmaps)
- [Secret](#secrets)
- [Mô hình tích hợp](#integration-patterns)
- [Thực hành tốt](#best-practices)
- [Khắc phục sự cố](#troubleshooting)

---

## Giới thiệu

Workload Kubernetes là các ứng dụng chạy trên cụm của bạn. Hướng dẫn này trình bày chi tiết các tài nguyên workload cốt lõi: Deployment để quản lý phiên bản ứng dụng, Service để truy cập mạng, ConfigMap cho cấu hình, và Secret cho dữ liệu nhạy cảm.

### Cấu trúc Workload

```
Deployment → ReplicaSet → Pods → Containers
     ↓
  Service (Truy cập mạng)
     ↓
ConfigMap + Secret (Cấu hình)
```

---

## Triển khai (Deployments)

### Tổng quan

**Deployment** là tài nguyên chính để quản lý ứng dụng không trạng thái trong Kubernetes. Nó cung cấp cập nhật khai báo cho pod và replica set, hỗ trợ rolling update, rollback và scaling.

### Vì sao nên dùng Deployment?

#### Vấn đề khi dùng Pod thuần
- Xóa pod là mất luôn
- Không tự động mở rộng
- Không có rolling update
- Không rollback được
- Quản lý thủ công phức tạp

#### Lợi ích của Deployment
-  **Tự phục hồi**: Pod tự động được tạo lại khi lỗi
-  **Mở rộng dễ dàng**: Scale ngang đơn giản
-  **Rolling update**: Cập nhật không downtime
-  **Rollback**: Quay lại phiên bản trước nhanh chóng
-  **Quản lý khai báo**: Định nghĩa trạng thái mong muốn

### Kiến trúc Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: production
  labels:
    app: webapp
    version: v1.2.3
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1.2.3
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        env:
        - name: ENVIRONMENT
          value: "production"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Chiến lược triển khai

#### 1. RollingUpdate (Mặc định)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%     # Số pod tối đa có thể unavailable
      maxSurge: 25%          # Số pod tối đa tạo thêm
```

**Cách hoạt động:**
```
Ban đầu: [Pod-A-v1] [Pod-B-v1] [Pod-C-v1]
B1:      [Pod-A-v1] [Pod-B-v1] [Pod-C-v1] [Pod-D-v2]
B2:      [Pod-A-v1] [Pod-B-v1] [Pod-D-v2]
B3:      [Pod-A-v1] [Pod-B-v1] [Pod-D-v2] [Pod-E-v2]
B4:      [Pod-A-v1] [Pod-D-v2] [Pod-E-v2]
B5:      [Pod-A-v1] [Pod-D-v2] [Pod-E-v2] [Pod-F-v2]
Kết:     [Pod-D-v2] [Pod-E-v2] [Pod-F-v2]
```

**Ví dụ cấu hình:**
```yaml
# Zero downtime
rollingUpdate:
  maxUnavailable: 0
  maxSurge: 1
# Nhanh
rollingUpdate:
  maxUnavailable: 50%
  maxSurge: 50%
# Thận trọng
rollingUpdate:
  maxUnavailable: 1
  maxSurge: 1
```

#### 2. Recreate

```yaml
spec:
  strategy:
    type: Recreate
```

**Dùng khi:**
- Ứng dụng không chạy song song nhiều phiên bản
- Dùng chung storage không hỗ trợ truy cập đồng thời
- Chấp nhận downtime

### Quản lý Deployment

#### Mở rộng

```bash
# Scale deployment
kubectl scale deployment webapp-deployment --replicas=5
# Auto-scaling
kubectl autoscale deployment webapp-deployment --min=3 --max=10 --cpu-percent=80
```

#### Cập nhật

```bash
# Cập nhật image
kubectl set image deployment/webapp-deployment webapp=webapp:v1.2.4
# Cập nhật có ghi lịch sử
kubectl set image deployment/webapp-deployment webapp=webapp:v1.2.4 --record
# Sửa trực tiếp
kubectl edit deployment webapp-deployment
```

#### Rollback

```bash
# Xem lịch sử rollout
kubectl rollout history deployment/webapp-deployment
# Quay lại phiên bản trước
kubectl rollout undo deployment/webapp-deployment
# Quay lại revision cụ thể
kubectl rollout undo deployment/webapp-deployment --to-revision=2
# Kiểm tra trạng thái rollout
kubectl rollout status deployment/webapp-deployment
```

### Mô hình triển khai nâng cao

#### Blue-Green Deployment

```yaml
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-blue
  labels:
    app: webapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: blue
  template:
    metadata:
      labels:
        app: webapp
        version: blue
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
```

```yaml
# Green deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-green
  labels:
    app: webapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: green
  template:
    metadata:
      labels:
        app: webapp
        version: green
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.4
```

#### Canary Deployment

```yaml
# Stable deployment (90% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: webapp
      track: stable
  template:
    metadata:
      labels:
        app: webapp
        track: stable
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
```

```yaml
# Canary deployment (10% traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
  template:
    metadata:
      labels:
        app: webapp
        track: canary
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.4
```

---

## Dịch vụ (Services)

### Tổng quan

**Service** cung cấp endpoint mạng ổn định cho pod. Nó giải quyết vấn đề IP động của pod và cân bằng tải giữa các instance.

### Kiến trúc Service

```
[Client] → [Service] → [Endpoints] → [Pods]
     ↓         ↓           ↓          ↓
   Request   Stable IP   Pod IPs   Containers
```

### Các loại Service

#### 1. ClusterIP (Mặc định)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80          # Cổng service
    targetPort: 8080  # Cổng pod
```

**Đặc điểm:**
- Chỉ truy cập nội bộ cụm
- IP ổn định trong cụm
- DNS: `webapp-service.production.svc.cluster.local`
- Loại mặc định

#### 2. NodePort

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-nodeport
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080   # Có thể chỉ định hoặc để K8s tự chọn
```

**Đặc điểm:**
- Mở cổng trên IP node
- Truy cập qua `<NodeIP>:<NodePort>`
- Port: 30000-32767
- Hỗ trợ truy cập ngoài

#### 3. LoadBalancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

**On-premise (cần MetalLB hoặc tương tự):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-loadbalancer
  annotations:
    metallb.universe.tf/address-pool: production-pool
spec:
  type: LoadBalancer
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

#### 4. ExternalName

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  type: ExternalName
  externalName: database.company.com
  ports:
  - protocol: TCP
    port: 5432
```

### Khám phá dịch vụ

#### DNS

```bash
# Cùng namespace
curl http://webapp-service
# Khác namespace
curl http://webapp-service.production
# Đầy đủ
curl http://webapp-service.production.svc.cluster.local
```

#### Biến môi trường

```yaml
# K8s tự tạo biến môi trường
WEBAPP_SERVICE_SERVICE_HOST=10.96.0.10
WEBAPP_SERVICE_SERVICE_PORT=80
```

### Cấu hình nâng cao

#### Session Affinity

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-sticky
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

#### Multi-Port

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-multiport
spec:
  selector:
    app: webapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  - name: https
    protocol: TCP
    port: 443
    targetPort: 8443
  - name: metrics
    protocol: TCP
    port: 9090
    targetPort: 9090
```

#### Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-headless
spec:
  clusterIP: None
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
```

---

## ConfigMap

### Tổng quan

**ConfigMap** lưu trữ dữ liệu cấu hình không nhạy cảm dạng key-value, giúp tách biệt cấu hình khỏi mã nguồn ứng dụng.

### Tạo ConfigMap

#### Từ giá trị trực tiếp

```bash
kubectl create configmap webapp-config \
  --from-literal=database_host=db.company.com \
  --from-literal=database_port=5432 \
  --from-literal=log_level=INFO
```

#### Từ file

```bash
# Từ 1 file
kubectl create configmap nginx-config --from-file=nginx.conf
# Từ thư mục
kubectl create configmap app-config --from-file=./config/
# Từ nhiều file
kubectl create configmap app-config \
  --from-file=app.properties \
  --from-file=database.properties
```

#### Từ YAML

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
data:
  # Key-value đơn giản
  database_host: "db.company.com"
  database_port: "5432"
  redis_host: "redis.company.com"
  log_level: "INFO"
  # File cấu hình
  app.properties: |
    database.host=db.company.com
    database.port=5432
    database.name=webapp
    cache.enabled=true
    cache.ttl=300
  # JSON
  features.json: |
    {
      "feature_a": true,
      "feature_b": false,
      "feature_c": {
        "enabled": true,
        "config": {
          "timeout": 30,
          "retries": 3
        }
      }
    }
```

### Sử dụng ConfigMap

#### Biến môi trường

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    # Dùng tất cả key làm biến môi trường
    envFrom:
    - configMapRef:
        name: webapp-config
    # Dùng key cụ thể
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_port
```

#### Mount volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
    - name: app-properties
      mountPath: /app/config/app.properties
      subPath: app.properties
  volumes:
  - name: config-volume
    configMap:
      name: webapp-config
  - name: app-properties
    configMap:
      name: webapp-config
      items:
      - key: app.properties
        path: app.properties
```

#### Tham số dòng lệnh

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    command: ["/app/webapp"]
    args: 
    - "--database-host=$(DATABASE_HOST)"
    - "--database-port=$(DATABASE_PORT)"
    - "--log-level=$(LOG_LEVEL)"
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_port
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: log_level
```

### Thực hành tốt với ConfigMap

#### 1. ConfigMap bất biến

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-v1
immutable: true
data:
  config.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
```

#### 2. ConfigMap version

```yaml
# Version 1
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-v1
  labels:
    version: v1
data:
  log_level: "INFO"
# Version 2
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-v2
  labels:
    version: v2
data:
  log_level: "DEBUG"
```

#### 3. ConfigMap theo môi trường

```yaml
# Cấu hình base
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-base
data:
  app_name: "webapp"
  timeout: "30s"
---
# Development
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-dev
data:
  log_level: "DEBUG"
  database_host: "dev-db.company.com"
---
# Production
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-prod
data:
  log_level: "WARN"
  database_host: "prod-db.company.com"
```

---

## Secret

### Tổng quan

**Secret** lưu trữ dữ liệu nhạy cảm như mật khẩu, token, SSH key, chứng chỉ TLS. Tương tự ConfigMap nhưng dành cho dữ liệu bí mật.

### So sánh Secret và ConfigMap

| Thuộc tính | ConfigMap | Secret |
|------------|-----------|--------|
| **Mục đích** | Dữ liệu cấu hình | Dữ liệu nhạy cảm |
| **Mã hóa** | Plain text | Base64 |
| **Lưu trữ** | etcd (plain) | etcd (base64) |
| **Mount** | Disk | tmpfs (memory) |
| **Giới hạn** | 1MB | 1MB |

### Các loại Secret

#### 1. Opaque (chung)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
data:
  username: YWRtaW4=                    # base64 'admin'
  password: cGFzc3dvcmQxMjM=            # base64 'password123'
  api-key: YWJjZGVmZ2hpamtsbW5vcA==    # base64 API key
```

#### 2. TLS

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-tls
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 cert
  tls.key: LS0tLS1CRUdJTi...  # base64 key
```

#### 3. Docker Registry

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJyZWdpc3RyeS5uZ3RhbnRhaS5wcm8iOiB7CiAgICAgICJ1c2VybmFtZSI6ICJhZG1pbiIsCiAgICAgICJwYXNzd29yZCI6ICJIYXJib3IxMjM0NSIsCiAgICAgICJhdXRoIjogIllXUnRhVzQ2U0dGeVltOXlNVEl6TkRVPSIKICAgIH0KICB9Cn0=
```

#### 4. SSH Key

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-key-secret
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: LS0tLS1CRUdJTi...  # base64 private key
```

#### 5. Basic Auth

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
type: kubernetes.io/basic-auth
data:
  username: YWRtaW4=      # base64 'admin'
  password: cGFzc3dvcmQ=  # base64 'password'
```

### Tạo Secret

#### Từ lệnh

```bash
# Secret generic
kubectl create secret generic webapp-secrets \
  --from-literal=username=admin \
  --from-literal=password=password123
# TLS
kubectl create secret tls webapp-tls \
  --cert=server.crt \
  --key=server.key
# Docker registry
kubectl create secret docker-registry harbor-secret \
  --docker-server=registry.ngtantai.pro \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@company.com
```

#### Từ file

```bash
# Từ file
kubectl create secret generic ssl-certs \
  --from-file=tls.crt=/path/to/tls.crt \
  --from-file=tls.key=/path/to/tls.key
# Từ thư mục
kubectl create secret generic app-secrets \
  --from-file=./secrets/
```

### Sử dụng Secret

#### Biến môi trường

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: webapp-secrets
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: webapp-secrets
          key: password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: webapp-secrets
          key: api-key
```

#### Mount volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
    - name: tls-volume
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: webapp-secrets
  - name: tls-volume
    secret:
      secretName: webapp-tls
```

#### Image Pull Secret

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  imagePullSecrets:
  - name: harbor-secret
  containers:
  - name: webapp
    image: registry.ngtantai.pro/webapp:v1.2.3
```

### Thực hành tốt với Secret

#### 1. Quản lý secret ngoài cụm

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
spec:
  provider:
    vault:
      server: "https://vault.company.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "webapp"
```

#### 2. Xoay vòng secret định kỳ

```bash
# Script xoay secret
#!/bin/bash
kubectl create secret generic webapp-secrets-new \
  --from-literal=username=admin \
  --from-literal=password=new-password123
# Update deployment dùng secret mới
kubectl patch deployment webapp-deployment \
  -p '{"spec":{"template":{"spec":{"volumes":[{"name":"secret-volume","secret":{"secretName":"webapp-secrets-new"}}]}}}}'
# Xóa secret cũ sau khi thành công
kubectl delete secret webapp-secrets
kubectl rename secret webapp-secrets-new webapp-secrets
```

#### 3. Giới hạn quyền truy cập secret

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["webapp-secrets"]
  verbs: ["get", "list"]
```

---

## Mô hình tích hợp

### Stack ứng dụng hoàn chỉnh

```yaml
# ConfigMap cấu hình
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  database_host: "db.company.com"
  database_port: "5432"
  redis_host: "redis.company.com"
  log_level: "INFO"
---
# Secret dữ liệu nhạy cảm
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
data:
  database_password: cGFzc3dvcmQxMjM=
  redis_password: cmVkaXNwYXNz
  jwt_secret: and0c2VjcmV0MTIz
---
# Deployment sử dụng ConfigMap và Secret
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: database_host
        - name: DATABASE_PORT
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: database_port
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: database_password
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: redis_host
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: redis_password
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: webapp-secrets
              key: jwt_secret
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: log_level
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Service expose ứng dụng
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
```

### Mô hình đa môi trường

```yaml
# Base deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:v1.2.3
        envFrom:
        - configMapRef:
            name: webapp-config-base
        - configMapRef:
            name: webapp-config-env  # Theo môi trường
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-env  # Theo môi trường
              key: database_password
```

---

## Thực hành tốt

### 1. Quản lý tài nguyên

```yaml
# Luôn đặt requests và limits
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

### 2. Health check

```yaml
# Thêm liveness và readiness probe
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
```

### 3. Security Context

```yaml
# Thiết lập security context cho container
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### 4. Label và Annotation

```yaml
# Dán nhãn nhất quán
metadata:
  labels:
    app: webapp
    version: v1.2.3
    component: web
    part-of: ecommerce
    managed-by: helm
    environment: production
  annotations:
    description: "Ứng dụng web production"
    contact: "devops@company.com"
    runbook: "https://runbook.company.com/webapp"
```

---

## Khắc phục sự cố

### Vấn đề thường gặp

#### 1. Pod không khởi động

```bash
# Kiểm tra trạng thái pod
kubectl get pods -l app=webapp
# Xem event
kubectl describe pod webapp-deployment-xxx
# Xem log
kubectl logs webapp-deployment-xxx
# Xem log container trước đó
kubectl logs webapp-deployment-xxx --previous
```

#### 2. Lỗi kết nối Service

```bash
# Test DNS service
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup webapp-service
# Test kết nối
kubectl run debug --image=busybox --rm -it --restart=Never -- wget -O- webapp-service
# Xem endpoints
kubectl get endpoints webapp-service
# Xem chi tiết service
kubectl describe service webapp-service
```

#### 3. Lỗi ConfigMap/Secret

```bash
# Xem nội dung ConfigMap
kubectl get configmap webapp-config -o yaml
# Xem nội dung Secret (base64)
kubectl get secret webapp-secrets -o yaml
# Giải mã secret
kubectl get secret webapp-secrets -o jsonpath='{.data.password}' | base64 -d
# Xem volume mount
kubectl describe pod webapp-deployment-xxx
```

#### 4. Lỗi Deployment

```bash
# Xem trạng thái deployment
kubectl get deployment webapp-deployment
# Xem event deployment
kubectl describe deployment webapp-deployment
# Xem replica set
kubectl get replicaset -l app=webapp
# Xem rollout status
kubectl rollout status deployment/webapp-deployment
# Xem lịch sử rollout
kubectl rollout history deployment/webapp-deployment
```

### Lệnh debug

```bash
# Port-forward để test local
kubectl port-forward deployment/webapp-deployment 8080:8080
# Exec vào pod
kubectl exec -it webapp-deployment-xxx -- /bin/bash
# Copy file từ/to pod
kubectl cp webapp-deployment-xxx:/app/logs ./logs
kubectl cp ./config.yaml webapp-deployment-xxx:/app/config.yaml
# Theo dõi tài nguyên
kubectl top pods -l app=webapp
kubectl top nodes
```

---

## Bước tiếp theo

Sau khi thành thạo quản lý workload:

1. **Tìm hiểu nâng cao**: StatefulSet, DaemonSet, Job
2. **Triển khai Ingress**: Định tuyến HTTP/HTTPS, cân bằng tải
3. **Thiết lập giám sát**: Prometheus, Grafana
4. **Cấu hình CI/CD**: Tự động triển khai
5. **Bảo mật**: RBAC, Network Policy, Pod Security

Tham khảo thêm:
- [Thiết lập cụm](cluster-setup.md)
- [Khái niệm Kubernetes](kubernetes-concepts.md)
- [Công cụ quản lý](management-tools.md)
- [Tích hợp CI/CD](cicd-integration.md)

---

## Kết luận

Workload Kubernetes là nền tảng cho điều phối container. Hiểu cách cấu hình Deployment, Service, ConfigMap, Secret là chìa khóa xây dựng ứng dụng bền vững, mở rộng và dễ bảo trì.

Kết hợp các tài nguyên này giúp quản lý vòng đời ứng dụng, truy cập mạng, cấu hình và bảo mật hiệu quả. Thực hành thường xuyên sẽ nâng cao kỹ năng thiết kế, vận hành hệ thống container phức tạp. 