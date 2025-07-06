# Kubernetes Deployment - Tổng quan toàn diện

## Khái niệm cơ bản

**Deployment** là một K8s resource object dùng để **quản lý và triển khai ứng dụng stateless** một cách declarative. Nó là layer abstraction cao nhất để manage pods và ReplicaSets.

### Vai trò trong K8s hierarchy:
```
Deployment → ReplicaSet → Pods → Containers
```

---

## Tại sao cần Deployment?

### **Vấn đề khi chỉ dùng Pods:**
- Pod bị xóa → Mất hoàn toàn, không tự recover
- Không có mechanism để scale
- Không có rolling updates
- Không có rollback capability
- Khó quản lý multiple pods cho cùng 1 app

### **Deployment giải quyết:**
- ✅ **Self-healing:** Tự động recreate pods bị fail
- ✅ **Scaling:** Dễ dàng scale up/down
- ✅ **Rolling updates:** Update zero-downtime
- ✅ **Rollback:** Quay về version cũ nhanh chóng
- ✅ **Declarative management:** Describe desired state

---

## Kiến trúc Deployment

### **3-tier architecture:**

```yaml
# Level 1: Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3           # Desired number of pods
  selector:             # How to select pods to manage
    matchLabels:
      app: nginx
  template:             # Pod template
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
```

### **Mối quan hệ:**

1. **Deployment Controller** tạo và manage **ReplicaSet**
2. **ReplicaSet Controller** tạo và manage **Pods**  
3. **kubelet** chạy **containers** trong pods

```
Deployment (nginx-deployment)
    ↓ creates & manages
ReplicaSet (nginx-deployment-7d9c8f5b6c)
    ↓ creates & manages  
Pods (nginx-deployment-7d9c8f5b6c-abc12, nginx-deployment-7d9c8f5b6c-def34, ...)
    ↓ runs
Containers (nginx:1.20)
```

---

## Thành phần chính của Deployment

### **1. Metadata**
```yaml
metadata:
  name: web-app              # Tên deployment
  namespace: production      # Namespace chứa deployment
  labels:                   # Labels cho deployment
    app: web-app
    version: v1.0
    environment: prod
  annotations:              # Metadata bổ sung
    deployment.kubernetes.io/revision: "1"
```

### **2. Spec (Specification)**
```yaml
spec:
  replicas: 3               # Số lượng pods mong muốn
  strategy:                 # Chiến lược update
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:                 # Label selector cho pods
    matchLabels:
      app: web-app
  template:                 # Pod template
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-container
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

### **3. Status (Read-only)**
```yaml
status:
  replicas: 3               # Current number of pods
  readyReplicas: 3          # Number of ready pods
  availableReplicas: 3      # Number of available pods
  updatedReplicas: 3        # Number of updated pods
  conditions:               # Deployment conditions
  - type: Available
    status: "True"
    reason: MinimumReplicasAvailable
```

---

## Deployment Strategies

### **1. RollingUpdate (Default)**
**Cách hoạt động:** Update từng pod một cách tuần tự

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%    # Tối đa 25% pods có thể unavailable
      maxSurge: 25%         # Tối đa 25% pods mới được tạo thêm
```

**Ưu điểm:**
- Zero downtime
- Gradual transition
- Có thể rollback ngay khi detect issue

**Flow:**
```
Initial: Pod1, Pod2, Pod3 (v1.0)
Step 1:  Pod1, Pod2, Pod3-new (v1.1) 
Step 2:  Pod1, Pod2-new (v1.1), Pod3-new (v1.1)
Step 3:  Pod1-new (v1.1), Pod2-new (v1.1), Pod3-new (v1.1)
```

### **2. Recreate**
**Cách hoạt động:** Xóa tất cả pods cũ, sau đó tạo pods mới

```yaml
spec:
  strategy:
    type: Recreate
```

**Ưu điểm:**
- Simple và predictable
- Không có version conflicts
- Resource efficient

**Nhược điểm:**
- Có downtime trong quá trình update

**Use cases:**
- Ứng dụng không support multiple versions cùng lúc
- Database migrations
- Stateful applications cần clean state

---

## Lifecycle Management

### **Tạo Deployment:**
```bash
# Từ YAML file
kubectl apply -f deployment.yaml

# Imperative command
kubectl create deployment nginx --image=nginx:1.20 --replicas=3

# With resource limits
kubectl create deployment web-app --image=nginx:1.20 \
  --replicas=3 \
  --port=80 \
  --dry-run=client -o yaml > deployment.yaml
```

### **Update Deployment:**
```bash
# Update image
kubectl set image deployment/nginx-deployment nginx=nginx:1.21

# Edit deployment directly
kubectl edit deployment nginx-deployment

# Scale replicas
kubectl scale deployment nginx-deployment --replicas=5

# Apply updated YAML
kubectl apply -f updated-deployment.yaml
```

### **Monitor Updates:**
```bash
# Watch rollout status
kubectl rollout status deployment/nginx-deployment

# Check rollout history
kubectl rollout history deployment/nginx-deployment

# Check specific revision
kubectl rollout history deployment/nginx-deployment --revision=2
```

### **Rollback:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=2

# Pause rollout (emergency)
kubectl rollout pause deployment/nginx-deployment

# Resume rollout
kubectl rollout resume deployment/nginx-deployment
```

### **Các câu lệnh thông dụng khác:**

#### **Quản lý Replicas:**
```bash
# Cập nhật trực tiếp số lượng replicas
kubectl scale deployment <ten-deployment> --replicas=<so-replicas>

# Scale với điều kiện
kubectl scale deployment nginx-deployment --replicas=5 --current-replicas=3
```

#### **Xem thông tin chi tiết:**
```bash
# Xem chi tiết cụ thể về một Deployment
kubectl describe deployment -n <namespace>

# Xem cấu hình YAML của một Deployment
kubectl get deployment <ten-deployment> -o yaml

# Liệt kê các Pod được tạo bởi một Deployment cụ thể
kubectl get pods -l app=<ten-deployment> -n <namespace>
```

#### **Cập nhật Environment Variables:**
```bash
# Cập nhật biến môi trường cho các container trong Deployment
kubectl set env deployment/<ten-deployment> <key>=<value>

# Ví dụ:
kubectl set env deployment/nginx-deployment ENV=production
kubectl set env deployment/nginx-deployment DB_HOST=mysql-service
```

#### **Quản lý Image:**
```bash
# Cập nhật Deployment bằng cách thay đổi hình ảnh container
kubectl set image deployment/<ten-deployment> <ten-container>=<ten-image>:<tag-moi>

# Ví dụ:
kubectl set image deployment/nginx-deployment nginx=nginx:1.21
kubectl set image deployment/webapp-deployment webapp=myapp:v2.0
```

#### **Rollback và History:**
```bash
# Rollback Deployment về phiên bản trước
kubectl rollout undo deployment <ten-deployment>

# Rollback về phiên bản cụ thể
kubectl rollout undo deployment <ten-deployment> --to-revision=2

# Kiểm tra lịch sử các phiên bản của Deployment
kubectl rollout history deployment <ten-deployment>

# Xem chi tiết một revision cụ thể
kubectl rollout history deployment <ten-deployment> --revision=2
```

#### **Pause/Resume Rollout:**
```bash
# Tạm dừng rollout (trường hợp khẩn cấp)
kubectl rollout pause deployment <ten-deployment>

# Tiếp tục rollout
kubectl rollout resume deployment <ten-deployment>
```

---

## Scaling Strategies

### **Manual Scaling:**
```bash
# Scale up/down
kubectl scale deployment nginx-deployment --replicas=10

# Conditional scaling
kubectl scale deployment nginx-deployment --replicas=5 --current-replicas=3
```

### **Horizontal Pod Autoscaler (HPA):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Best Practices

### **1. Resource Management:**
```yaml
containers:
- name: app
  image: myapp:1.0
  resources:
    requests:              # Minimum guaranteed resources
      memory: "128Mi"
      cpu: "100m"
    limits:               # Maximum allowed resources
      memory: "256Mi"
      cpu: "500m"
```

### **2. Health Checks:**
```yaml
containers:
- name: app
  image: myapp:1.0
  ports:
  - containerPort: 8080
  livenessProbe:          # Restart container if fails
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:         # Don't send traffic if not ready
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
  startupProbe:           # For slow-starting containers
    httpGet:
      path: /startup
      port: 8080
    failureThreshold: 30
    periodSeconds: 10
```

### **3. Labels và Selectors:**
```yaml
metadata:
  labels:
    app: web-app
    version: v1.0
    component: frontend
    environment: production
spec:
  selector:
    matchLabels:
      app: web-app
      component: frontend
```

### **4. Security Context:**
```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

---

## Troubleshooting Commands

```bash
# Check deployment status
kubectl get deployments
kubectl describe deployment nginx-deployment

# Check pods created by deployment
kubectl get pods -l app=nginx

# Check ReplicaSet
kubectl get replicaset
kubectl describe replicaset nginx-deployment-xxx

# Debug deployment issues
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl logs deployment/nginx-deployment
kubectl logs -f deployment/nginx-deployment --all-containers=true

# Check resource usage
kubectl top pods -l app=nginx
kubectl describe node <node-name>
```

---

## So sánh với các workload khác

| Feature | Deployment | StatefulSet | DaemonSet | Job |
|---------|------------|-------------|-----------|-----|
| **Use Case** | Stateless apps | Stateful apps | System services | Batch processing |
| **Pod Identity** | Random | Ordered, persistent | One per node | Temporary |
| **Storage** | Ephemeral | Persistent | Usually ephemeral | Ephemeral |
| **Scaling** | Easy | Sequential | Auto (node-based) | No scaling |
| **Updates** | Rolling/Recreate | Rolling, ordered | Rolling | Immutable |
| **Examples** | Web servers, APIs | Databases | Log agents, monitoring | Data processing |

---

## Ví dụ thực tế

### **Web Application Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: production
  labels:
    app: webapp
    tier: frontend
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: webapp
      tier: frontend
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
        version: v2.1.0
    spec:
      containers:
      - name: webapp
        image: myregistry/webapp:v2.1.0
        ports:
        - containerPort: 8080
        env:
        - name: ENV
          value: "production"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
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
      imagePullSecrets:
      - name: registry-credentials
```

**Deployment** là foundation của container orchestration trong K8s, cung cấp powerful tools để manage application lifecycle một cách reliable và scalable.