# MinIO Storage cho Multi-Node Kubernetes

Hướng dẫn triển khai MinIO distributed storage trên cluster 3 worker nodes (4 pods MinIO).

## Quick Setup Guide
- [Chuẩn bị nodes](#chuẩn-bị-nodes)
- [StorageClass & PV](#storageclass--pv)
- [Deploy MinIO](#deploy-minio)
- [Kiểm tra và monitor](#kiểm-tra-và-monitor)

## Chuẩn bị nodes

### 1. Tạo thư mục storage trên tất cả nodes
```bash
# Chạy trên mỗi node worker
sudo mkdir -p /mnt/minio-data/{data1,data2}
sudo chown -R 1000:1000 /mnt/minio-data/
sudo chmod -R 755 /mnt/minio-data/
```

### 2. Label nodes cho MinIO
```bash
kubectl label node worker-1 minio-node=true
kubectl label node worker-2 minio-node=true
kubectl label node worker-3 minio-node=true
```

## StorageClass & PV

### StorageClass
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### PV cho setup 3 nodes (4 PVs total)
```bash
# Tạo 4 PVs phân bổ trên 3 worker nodes
cat << 'EOF' > create-minio-pvs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-worker-1-data1
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage
  local:
    path: /mnt/minio-data/data1
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
  name: minio-pv-worker-1-data2
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage
  local:
    path: /mnt/minio-data/data2
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
  name: minio-pv-worker-2-data1
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage
  local:
    path: /mnt/minio-data/data1
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
  name: minio-pv-worker-3-data1
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage
  local:
    path: /mnt/minio-data/data1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [worker-3]
EOF

kubectl apply -f create-minio-pvs.yaml
```

## Deploy MinIO

### 1. Tạo namespace và secret
```bash
kubectl create namespace minio-system
kubectl create secret generic minio-secret \
  --from-literal=rootUser=admin \
  --from-literal=rootPassword=minio123456 \
  -n minio-system
```

### 2. Deploy MinIO StatefulSet
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: minio-system
spec:
  serviceName: minio
  replicas: 4  # 3 worker nodes, 4 MinIO pods
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
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
                  values: [minio]
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: minio-node
                operator: In
                values: ["true"]
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - http://minio-{0...3}.minio.minio-system.svc.cluster.local/data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: rootUser
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: rootPassword
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: minio-storage
      resources:
        requests:
          storage: 50Gi
```

### 3. Services
```yaml
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio-system
spec:
  clusterIP: None
  ports:
  - port: 9000
    name: api
  - port: 9001
    name: console
  selector:
    app: minio
---
apiVersion: v1
kind: Service
metadata:
  name: minio-api
  namespace: minio-system
spec:
  type: LoadBalancer
  ports:
  - port: 9000
  selector:
    app: minio
---
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: minio-system
spec:
  type: LoadBalancer
  ports:
  - port: 9001
  selector:
    app: minio
```

## Kiểm tra và monitor

### Kiểm tra deployment
```bash
# Kiểm tra pods
kubectl get pods -n minio-system

# Kiểm tra PVCs
kubectl get pvc -n minio-system

# Kiểm tra services
kubectl get svc -n minio-system

# Access MinIO console
kubectl port-forward svc/minio-console 9001:9001 -n minio-system
# Truy cập: http://localhost:9001
```

### Health check cơ bản
```bash
# Kiểm tra cluster info
kubectl exec -it minio-0 -n minio-system -- \
  mc config host add local http://localhost:9000 admin minio123456

kubectl exec -it minio-0 -n minio-system -- \
  mc admin info local

# Kiểm tra storage usage
kubectl exec -it minio-0 -n minio-system -- df -h /data
```

## Scaling

### Setup mục tiêu: 3 worker nodes (4 PVs)
- Replicas: 4
- Phân bổ PVs: worker-1 (2), worker-2 (1), worker-3 (1)
- Command: `http://minio-{0...3}.minio.minio-system.svc.cluster.local/data`

## Common Issues

### PVC Pending
```bash
kubectl describe pvc data-minio-0 -n minio-system
kubectl get pv | grep Available
```

### Pod không start
```bash
kubectl logs minio-0 -n minio-system
kubectl describe pod minio-0 -n minio-system
```

### Cluster không healthy
```bash
kubectl exec -it minio-0 -n minio-system -- mc admin info local
```

## Quick Commands

```bash
# Tạo bucket
kubectl exec -it minio-0 -n minio-system -- mc mb local/test-bucket

# Upload file test  
kubectl exec -it minio-0 -n minio-system -- mc cp /etc/hostname local/test-bucket/

# List objects
kubectl exec -it minio-0 -n minio-system -- mc ls local/test-bucket

# Cluster status
kubectl exec -it minio-0 -n minio-system -- mc admin info local
```

Đó là setup đơn giản cho multi-node MinIO trong K8s! 