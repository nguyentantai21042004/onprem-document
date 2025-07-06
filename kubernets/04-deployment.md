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

## Deployment Strategies - Chi tiết toàn diện

Kubernetes hỗ trợ **2 chiến lược deployment** chính để update applications:
- **RollingUpdate** (default) - Update từng phần
- **Recreate** - Xóa hết rồi tạo mới

Mỗi strategy có **use cases**, **pros/cons** và **configuration** riêng biệt.

---

### **1. RollingUpdate Strategy**

#### **Khái niệm**
**RollingUpdate** thay thế pods cũ bằng pods mới **từng cái một** hoặc **từng batch nhỏ**, đảm bảo luôn có pods running để serve traffic.

#### **Cách thức hoạt động**

**Flow chi tiết:**
```
Initial State: 3 pods running v1.0
[Pod-A-v1] [Pod-B-v1] [Pod-C-v1]

Step 1: Tạo Pod mới v1.1
[Pod-A-v1] [Pod-B-v1] [Pod-C-v1] [Pod-D-v1.1]

Step 2: Xóa Pod cũ khi Pod mới ready
[Pod-A-v1] [Pod-B-v1] [Pod-D-v1.1]

Step 3: Tạo Pod mới tiếp theo
[Pod-A-v1] [Pod-B-v1] [Pod-D-v1.1] [Pod-E-v1.1]

Step 4: Xóa Pod cũ tiếp theo
[Pod-A-v1] [Pod-D-v1.1] [Pod-E-v1.1]

Step 5: Tạo Pod cuối cùng
[Pod-A-v1] [Pod-D-v1.1] [Pod-E-v1.1] [Pod-F-v1.1]

Final State: Tất cả pods v1.1
[Pod-D-v1.1] [Pod-E-v1.1] [Pod-F-v1.1]
```

#### **Configuration**

**Basic RollingUpdate:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%     # Tối đa 25% pods có thể down cùng lúc
      maxSurge: 25%          # Tối đa 25% pods mới được tạo thêm
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
        image: nginx:1.20
        ports:
        - containerPort: 80
```

**Advanced RollingUpdate với số cụ thể:**
```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2       # Chính xác 2 pods có thể down
      maxSurge: 3            # Tối đa 3 pods mới cùng lúc
```

#### **Tham số quan trọng**

**maxUnavailable**
- **Mục đích:** Giới hạn số pods có thể bị terminate cùng lúc
- **Giá trị:** Số nguyên hoặc phần trăm
- **Default:** 25%

```yaml
# Examples:
maxUnavailable: 1          # Chỉ 1 pod down tại một thời điểm
maxUnavailable: 25%        # 25% pods có thể down
maxUnavailable: 0          # Không pod nào down (zero downtime)
```

**maxSurge**
- **Mục đích:** Giới hạn số pods mới được tạo thêm
- **Giá trị:** Số nguyên hoặc phần trăm  
- **Default:** 25%

```yaml
# Examples:
maxSurge: 1               # Tạo thêm tối đa 1 pod
maxSurge: 50%            # Tạo thêm tối đa 50% pods
maxSurge: 0              # Không tạo thêm pods (resource constrained)
```

#### **Scenarios thực tế**

**Zero Downtime Deployment:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0       # Không pod nào down
    maxSurge: 1            # Tạo 1 pod mới, đợi ready, xóa 1 pod cũ
```

**Fast Deployment (có thể có brief downtime):**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 50%     # Có thể down 50% pods
    maxSurge: 50%          # Tạo thêm 50% pods
```

**Resource Constrained:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1       # Chỉ 1 pod down
    maxSurge: 0            # Không tạo thêm pods (tiết kiệm resources)
```

#### **Ưu điểm**
- ✅ **Zero/minimal downtime**
- ✅ **Gradual transition** - dễ detect issues sớm
- ✅ **Traffic shifting** - từ từ chuyển traffic sang version mới
- ✅ **Easy rollback** - có thể undo ngay khi phát hiện lỗi
- ✅ **Canary-like behavior** - test version mới với ít traffic trước

#### **Nhược điểm**
- ❌ **Resource overhead** - cần thêm resources trong quá trình update
- ❌ **Complexity** - nhiều pods versions cùng lúc
- ❌ **Slower** - mất thời gian hơn recreate
- ❌ **Mixed versions** - có thể có issues với incompatible versions

#### **Use Cases**
- **Web applications** - cần uptime cao
- **APIs** - không thể afford downtime
- **Microservices** - cần gradual deployment
- **Production workloads** - zero downtime requirement
- **Stateless applications** - dễ dàng scale và replace

---

### **2. Recreate Strategy**

#### **Khái niệm**
**Recreate** strategy **xóa tất cả pods cũ** trước, sau đó **tạo pods mới** với version mới. Có **downtime** trong quá trình chuyển đổi.

#### **Cách thức hoạt động**

**Flow chi tiết:**
```
Initial State: 3 pods running v1.0
[Pod-A-v1] [Pod-B-v1] [Pod-C-v1]

Step 1: Terminate tất cả pods cũ
[Terminating...] [Terminating...] [Terminating...]

Step 2: Chờ pods terminate hoàn toàn
[ ] [ ] [ ]  # No pods running - DOWNTIME

Step 3: Tạo tất cả pods mới cùng lúc
[Pod-D-v1.1] [Pod-E-v1.1] [Pod-F-v1.1] (Creating...)

Step 4: Chờ pods ready
[Pod-D-v1.1] [Pod-E-v1.1] [Pod-F-v1.1] (Ready!)

Final State: Tất cả pods v1.1 running
[Pod-D-v1.1] [Pod-E-v1.1] [Pod-F-v1.1]
```

#### **Configuration**

**Basic Recreate:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-deployment
spec:
  replicas: 1
  strategy:
    type: Recreate              # Chỉ cần specify type
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: "password"
        volumeMounts:
        - name: db-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: db-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

**Recreate với Pre/Post hooks:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-migration
spec:
  replicas: 3
  strategy:
    type: Recreate
  template:
    spec:
      initContainers:           # Chạy trước main container
      - name: db-migration
        image: migrate/migrate
        command: ['migrate', 'up']
      containers:
      - name: app
        image: myapp:v2.0
        lifecycle:
          preStop:              # Chạy trước khi container stop
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
```

#### **Timeline chi tiết**
```
Time: 0s    - Deployment update triggered
Time: 1s    - Begin terminating old pods
Time: 2-30s - Graceful shutdown period (terminationGracePeriodSeconds)
Time: 30s   - Force kill pods if not terminated
Time: 31s   - All old pods terminated - DOWNTIME BEGINS
Time: 32s   - Start creating new pods
Time: 33s   - New pods scheduled to nodes
Time: 34s   - Container images pulled (if not cached)
Time: 45s   - Containers started, running readiness checks
Time: 60s   - All pods ready - DOWNTIME ENDS

Total Downtime: ~29 seconds (time: 31s to 60s)
```

#### **Tối ưu Recreate để giảm downtime**

**Pre-pull images:**
```yaml
spec:
  template:
    spec:
      initContainers:
      - name: image-puller
        image: myapp:v2.0      # Pull image trước
        command: ['echo', 'Image pulled']
      containers:
      - name: app
        image: myapp:v2.0
```

**Fast startup configuration:**
```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:v2.0
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 1    # Reduce delay
          periodSeconds: 1          # Check frequently
          timeoutSeconds: 1
        livenessProbe:
          httpGet:
            path: /health  
            port: 8080
          initialDelaySeconds: 10   # Give time to start
          periodSeconds: 5
```

#### **Ưu điểm**
- ✅ **Simple và predictable** - straightforward process
- ✅ **Clean state** - không có mixed versions
- ✅ **Resource efficient** - không cần extra resources
- ✅ **No version conflicts** - tránh compatibility issues
- ✅ **Database migrations** - phù hợp cho stateful apps
- ✅ **Complete refresh** - clear caches, connections

#### **Nhược điểm**
- ❌ **Downtime** - service unavailable trong quá trình update
- ❌ **All-or-nothing** - nếu fail thì toàn bộ app down
- ❌ **No gradual testing** - không thể test version mới từ từ
- ❌ **Rollback complexity** - cần deploy lại hoàn toàn
- ❌ **User impact** - users experience service interruption

#### **Use Cases**
- **Databases** - cần schema migrations
- **Stateful applications** - không support multiple versions
- **Resource-constrained environments** - không đủ resources cho rolling
- **Development/testing** - downtime acceptable
- **Batch processing** - không serve real-time traffic
- **Legacy applications** - không design cho rolling updates

---

### **So sánh chi tiết**

| Aspect | RollingUpdate | Recreate |
|--------|---------------|----------|
| **Downtime** | Zero/minimal | Có downtime (seconds to minutes) |
| **Resource Usage** | Cao hơn (cần extra pods) | Thấp hơn (chỉ cần resources cho replicas) |
| **Deployment Speed** | Chậm hơn | Nhanh hơn |
| **Risk Level** | Thấp (gradual) | Cao (all-or-nothing) |
| **Version Mixing** | Có (temporary) | Không |
| **Rollback** | Nhanh | Chậm (cần deploy lại) |
| **Database Migration** | Phức tạp | Đơn giản |
| **Complexity** | Cao | Thấp |
| **Production Suitability** | Cao | Trung bình |

---

### **Best Practices cho Deployment Strategies**

#### **Khi nào dùng RollingUpdate:**

```yaml
# Web applications
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 25%

# Critical APIs (zero downtime)
strategy:
  type: RollingUpdate  
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1

# High-traffic services
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 10%
    maxSurge: 50%
```

#### **Khi nào dùng Recreate:**

```yaml
# Databases with migrations
strategy:
  type: Recreate

# Single-instance apps
strategy:
  type: Recreate

# Legacy applications
strategy:
  type: Recreate
```

#### **Monitoring Deployments:**

```bash
# Watch deployment progress
kubectl rollout status deployment/webapp --timeout=300s

# Check deployment events
kubectl describe deployment webapp

# Monitor pods during update
watch kubectl get pods -l app=webapp

# Check rollout history
kubectl rollout history deployment/webapp
```

#### **Safety measures:**

**Health checks cho RollingUpdate:**
```yaml
containers:
- name: app
  readinessProbe:           # Đảm bảo pod ready trước khi receive traffic
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
  livenessProbe:           # Restart pod if unhealthy
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
```

**Resource limits:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi" 
    cpu: "500m"
```

**PodDisruptionBudget:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
spec:
  minAvailable: 2           # Luôn giữ ít nhất 2 pods available
  selector:
    matchLabels:
      app: webapp
```

---

### **Troubleshooting Deployment Strategies**

#### **Common RollingUpdate Issues:**

**Stuck deployment:**
```bash
# Check why deployment stuck
kubectl describe deployment webapp
kubectl get events --sort-by='.lastTimestamp'

# Common causes:
# - Resource limits
# - Failed health checks  
# - Image pull errors
# - Node capacity issues
```

**Failed readiness probe:**
```bash
# Check pod logs
kubectl logs deployment/webapp
kubectl describe pod <pod-name>

# Fix: Adjust probe timing
readinessProbe:
  initialDelaySeconds: 30  # Give more time
  timeoutSeconds: 5        # Longer timeout
```

#### **Common Recreate Issues:**

**Long downtime:**
```bash
# Pre-pull images on nodes
kubectl create job image-puller --image=myapp:v2.0 \
  --dry-run=client -o yaml | kubectl apply -f -

# Use faster startup
# Optimize application startup time
# Use smaller images
```

---

### **Kết luận về Deployment Strategies**

**Chọn strategy dựa trên:**

- **RollingUpdate** cho production workloads cần uptime cao
- **Recreate** cho development hoặc stateful applications
- **Combine** với proper health checks và monitoring
- **Test** cả 2 strategies trong staging environment

**Key takeaway:** Không có strategy nào perfect cho mọi use case. Hiểu rõ trade-offs và chọn phù hợp với requirements của application.

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

