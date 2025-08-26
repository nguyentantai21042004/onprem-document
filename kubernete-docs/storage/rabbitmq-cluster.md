# RabbitMQ Cluster cho Multi-Node Kubernetes (3 workers)

Hướng dẫn triển khai RabbitMQ distributed cluster trên K8s (3 pods RabbitMQ / 3 PV). Có sẵn Management UI.

## Quick Setup
- **Chuẩn bị nodes**
- **StorageClass & PV**
- **Deploy RabbitMQ**
- **Kiểm tra & quản trị**
- **Scaling & PDB**
- **Common Issues**

---

## Chuẩn bị nodes

### 1) Thư mục storage (mỗi worker)
```bash
sudo mkdir -p /mnt/rabbitmq-data/data
sudo chown -R 999:999 /mnt/rabbitmq-data
sudo chmod -R 750 /mnt/rabbitmq-data
```
999:999 là UID/GID mặc định của image rabbitmq. Nếu bạn dùng image khác, chỉnh lại cho khớp.

### 2) Label nodes
```bash
kubectl label node worker-1 rabbitmq-node=true
kubectl label node worker-2 rabbitmq-node=true
kubectl label node worker-3 rabbitmq-node=true
```

## StorageClass & PV

### StorageClass (local, không dynamic)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rabbitmq-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### PV (3 PV cho 3 pods)
```bash
cat << 'EOF' > create-rabbitmq-pvs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rabbitmq-pv-worker-1
spec:
  capacity:
    storage: 20Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: rabbitmq-storage
  local:
    path: /mnt/rabbitmq-data/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [worker-1]
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rabbitmq-pv-worker-2
spec:
  capacity:
    storage: 20Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: rabbitmq-storage
  local:
    path: /mnt/rabbitmq-data/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [worker-2]
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rabbitmq-pv-worker-3
spec:
  capacity:
    storage: 20Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: rabbitmq-storage
  local:
    path: /mnt/rabbitmq-data/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [worker-3]
EOF

kubectl apply -f create-rabbitmq-pvs.yaml
```

## Deploy RabbitMQ

### 1) Namespace & Secrets (cookie, user/pass)
```bash
kubectl create namespace rabbitmq-system

# Tạo Erlang cookie (32 ký tự A-Z) – PHẢI GIỐNG NHAU TRÊN TOÀN CỤM
COOKIE=$(tr -dc 'A-Z' </dev/urandom | head -c 32)
echo "COOKIE=$COOKIE"

kubectl -n rabbitmq-system create secret generic rabbitmq-erlang-cookie \
  --from-literal=erlang-cookie="$COOKIE"

# User quản trị cho Management UI & AMQP
kubectl -n rabbitmq-system create secret generic rabbitmq-auth \
  --from-literal=username=admin \
  --from-literal=password='StrongP@ssw0rd'
```

### 2) ConfigMap (rabbitmq.conf – bật peer discovery k8s)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rabbitmq-config
  namespace: rabbitmq-system
data:
  rabbitmq.conf: |
    loopback_users.guest = false
    listeners.tcp.default = 5672
    management.tcp.port = 15672
    management.load_definitions = /etc/rabbitmq/definitions.json

    # Khám phá peer qua Kubernetes
    cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
    cluster_formation.k8s.host = kubernetes.default.svc
    cluster_formation.k8s.address_type = hostname
    cluster_formation.node_cleanup.interval = 30
    cluster_formation.node_cleanup.only_log_warning = true

    # Chiến lược khi partition
    cluster_partition_handling = pause_minority

    # Tên node dài để khớp DNS
    use_longname = true
  definitions.json: |
    {
      "users": [],
      "vhosts": [{"name":"/"}],
      "permissions": [],
      "policies": [],
      "queues": [],
      "exchanges": [],
      "bindings": []
    }
```

### 3) Headless Service & Client/Management Services
```yaml
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: rabbitmq-system
spec:
  clusterIP: None
  publishNotReadyAddresses: true
  ports:
    - name: epmd
      port: 4369
    - name: dist
      port: 25672
    - name: amqp
      port: 5672
    - name: mgmt
      port: 15672
  selector:
    app: rabbitmq
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-amqp
  namespace: rabbitmq-system
spec:
  type: LoadBalancer   # hoặc NodePort nếu không có LB
  ports:
    - name: amqp
      port: 5672
      targetPort: 5672
  selector:
    app: rabbitmq
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-mgmt
  namespace: rabbitmq-system
spec:
  type: LoadBalancer   # hoặc NodePort
  ports:
    - name: mgmt
      port: 15672
      targetPort: 15672
  selector:
    app: rabbitmq
```

### 4) StatefulSet (3 replicas = 3 nodes)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
  namespace: rabbitmq-system
spec:
  serviceName: rabbitmq
  replicas: 3
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values: ["rabbitmq"]
                topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: rabbitmq-node
                    operator: In
                    values: ["true"]
      containers:
        - name: rabbitmq
          image: rabbitmq:3.13-management
          env:
            - name: RABBITMQ_ERLANG_COOKIE
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-erlang-cookie
                  key: erlang-cookie
            - name: RABBITMQ_DEFAULT_USER
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-auth
                  key: username
            - name: RABBITMQ_DEFAULT_PASS
              valueFrom:
                secretKeyRef:
                  name: rabbitmq-auth
                  key: password
            - name: K8S_SERVICE_NAME
              value: "rabbitmq"
            - name: RABBITMQ_USE_LONGNAME
              value: "true"
          ports:
            - containerPort: 5672  # AMQP
            - containerPort: 15672 # Management
            - containerPort: 4369  # EPMD
            - containerPort: 25672 # Inter-node dist
          volumeMounts:
            - name: data
              mountPath: /var/lib/rabbitmq
            - name: config
              mountPath: /etc/rabbitmq
          readinessProbe:
            exec:
              command: ["rabbitmq-diagnostics", "ping"]
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["rabbitmq-diagnostics", "ping"]
            initialDelaySeconds: 30
            periodSeconds: 20
      volumes:
        - name: config
          configMap:
            name: rabbitmq-config
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: rabbitmq-storage
        resources:
          requests:
            storage: 20Gi
```

## Vì sao cookie quan trọng?
`RABBITMQ_ERLANG_COOKIE` là bí mật nội bộ của cluster Erlang. Phải giống nhau trên tất cả pod, và ổn định theo thời gian (đặt qua Secret) để node mới join được và node cũ restart không bị lệch cụm.

## Kiểm tra & quản trị

### Kiểm tra tài nguyên
```bash
kubectl -n rabbitmq-system get pods,pvc,svc
```

### Truy cập UI
- **Nếu dùng LoadBalancer**: vào `http://<EXTERNAL-IP>:15672`
- **Nếu cần tạm thời**:
```bash
kubectl -n rabbitmq-system port-forward svc/rabbitmq-mgmt 15672:15672
# http://localhost:15672  (user/pass trong secret rabbitmq-auth)
```

### Trạng thái cluster
```bash
# Vào 1 pod bất kỳ
kubectl -n rabbitmq-system exec -it rabbitmq-0 -- bash -lc "rabbitmq-diagnostics cluster_status"

# Health chi tiết
kubectl -n rabbitmq-system exec -it rabbitmq-0 -- rabbitmq-diagnostics status
kubectl -n rabbitmq-system exec -it rabbitmq-0 -- rabbitmqctl list_nodes
kubectl -n rabbitmq-system logs statefulset/rabbitmq
```

### Kiểm tra cookie đồng nhất (khi nghi ngờ)
```bash
# Xem cookie file thực tế trong pod
kubectl -n rabbitmq-system exec -it rabbitmq-0 -- cat /var/lib/rabbitmq/.erlang.cookie
kubectl -n rabbitmq-system exec -it rabbitmq-1 -- cat /var/lib/rabbitmq/.erlang.cookie
kubectl -n rabbitmq-system exec -it rabbitmq-2 -- cat /var/lib/rabbitmq/.erlang.cookie
```
Nếu các giá trị KHÁC nhau, xoá PVC + pod để tạo lại từ Secret cookie (hoặc sửa cookie cho đồng nhất).

## Scaling & PDB

### Tăng/giảm số node
- Sửa `spec.replicas` trong StatefulSet (vd: 5).
- Đảm bảo đủ PV/PVC tương ứng (với `WaitForFirstConsumer`, K8s sẽ bind đúng node có PV local).

### PodDisruptionBudget (khuyên dùng)
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: rabbitmq-pdb
  namespace: rabbitmq-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: rabbitmq
```

## Common Issues

### 1) Nodes không join cluster
- Nguyên nhân phổ biến:
  - Erlang cookie khác nhau giữa pods.
  - Thiếu/bị chặn port 4369, 25672 (inter-node), hoặc DNS headless service.
- Cách xử lý:
  - Đảm bảo tất cả pods đọc cùng Secret cookie và PVC không chứa cookie cũ sai lệch.
  - Xoá pod + PVC lỗi để tái tạo từ Secret:
```bash
kubectl -n rabbitmq-system delete pod rabbitmq-1
kubectl -n rabbitmq-system delete pvc data-rabbitmq-1
```
(Cẩn trọng vì mất dữ liệu trên node đó.)

### 2) Cookie bị “ghi đè” bởi dữ liệu cũ trong PVC
- Khi pod khởi động, nếu `/var/lib/rabbitmq/.erlang.cookie` đã tồn tại trong PVC, nó sẽ ghi đè giá trị env/Secret.
- Cách tốt nhất: ấn định cookie ngay từ đầu và không thay đổi. Nếu lỡ khác nhau → xóa PVC cũ để sạch state.

### 3) Partition network
- Đã cấu hình `cluster_partition_handling = pause_minority`. Tùy nhu cầu có thể đổi sang `autoheal` (có rủi ro mất message chưa replicate). Chỉ đổi khi hiểu rõ trade-off.

### 4) PVC Pending
```bash
kubectl describe pvc -n rabbitmq-system
kubectl get pv | grep rabbitmq
```