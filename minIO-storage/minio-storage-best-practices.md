# MinIO Storage Best Practices - PV & PVC Configuration

## Phân tích cấu hình hiện tại

### StorageClass Configuration
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-storage
provisioner: kubernetes.io/no-provisioner  # Local storage provisioner
reclaimPolicy: Retain                      # Dữ liệu được giữ lại sau khi xóa PVC
volumeBindingMode: WaitForFirstConsumer    # Bind khi pod được tạo
```

### PersistentVolume Pattern
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-kubernete-1-data1
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
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
              values:
                - kubernete-1
```

## Best Practices

### 1. **Storage Planning**

#### Capacity Planning
- **Minimum**: 4-6 PV cho MinIO distributed mode
- **Recommended**: 8-16 PV để đảm bảo high availability
- **Size**: Mỗi PV nên có kích thước đồng đều (20Gi như hiện tại là tốt)

#### Directory Structure
```bash
# Chuẩn bị directories trên node
sudo mkdir -p /mnt/minio-data/{data1,data2,data3,data4,data5,data6}
sudo chown -R 1000:1000 /mnt/minio-data/
sudo chmod -R 755 /mnt/minio-data/
```

### 2. **StorageClass Best Practices**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain  # CRITICAL: Giữ dữ liệu khi xóa PVC
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false  # Local volumes không hỗ trợ expand
```

**Key Points:**
- `Retain` policy: Bảo vệ dữ liệu quan trọng
- `WaitForFirstConsumer`: Đảm bảo pod và PV cùng node
- `no-provisioner`: Phù hợp cho local storage

### 3. **PersistentVolume Templates**

#### Single Node Setup (Development)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-node1-data${INDEX}
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage
  local:
    path: /mnt/minio-data/data${INDEX}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - kubernete-1  # Thay bằng tên node thực tế
```

#### Multi-Node Setup (Production)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv-node${NODE_INDEX}-data${DATA_INDEX}
spec:
  capacity:
    storage: 50Gi  # Tăng size cho production
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: minio-storage-ssd  # Sử dụng SSD cho performance
  local:
    path: /mnt/minio-data/data${DATA_INDEX}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - node-${NODE_INDEX}
        - matchExpressions:
            - key: node.kubernetes.io/instance-type
              operator: In
              values:
                - storage-optimized
```

### 4. **PVC Best Practices**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: export-minio-${INDEX}
  namespace: minio-system
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: minio-storage
  resources:
    requests:
      storage: 20Gi  # Phải match với PV capacity
```

**Key Considerations:**
- PVC `storage` phải ≤ PV `capacity`
- AccessMode phải match giữa PV và PVC
- StorageClassName phải match

### 5. **MinIO Deployment Patterns**

#### Distributed MinIO (Recommended)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
spec:
  serviceName: minio-svc
  replicas: 6  # Match với số lượng PV
  template:
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        command:
        - /bin/bash
        - -c
        args:
        - minio server /data{1...6} --console-address ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: "admin"
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /data1
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: minio-storage
      resources:
        requests:
          storage: 20Gi
```

### 6. **Monitoring & Maintenance**

#### Health Check Commands
```bash
# Kiểm tra PV status
kubectl get pv -l app=minio

# Kiểm tra PVC binding
kubectl get pvc -n minio-system

# Kiểm tra storage usage
kubectl exec -it minio-0 -n minio-system -- df -h

# MinIO cluster status
kubectl exec -it minio-0 -n minio-system -- mc admin info local
```

#### Backup Strategy
```yaml
# Backup PVC data
apiVersion: batch/v1
kind: CronJob
metadata:
  name: minio-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: minio/mc:latest
            command:
            - /bin/sh
            - -c
            - |
              mc alias set source http://minio-svc:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
              mc mirror source/my-bucket /backup/$(date +%Y%m%d)
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
```

### 7. **Performance Optimization**

#### Storage Performance
```yaml
# Sử dụng SSD StorageClass cho production
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: minio-storage-ssd
provisioner: kubernetes.io/no-provisioner
parameters:
  type: ssd
  iops: "3000"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

#### Node Optimization
```bash
# Tối ưu filesystem cho MinIO
sudo mkfs.ext4 -F -m 0 -E lazy_itable_init=0,lazy_journal_init=0 /dev/disk
sudo mount -o defaults,noatime,nodiratime /dev/disk /mnt/minio-data

# Kernel parameters
echo 'vm.swappiness=1' >> /etc/sysctl.conf
echo 'net.core.somaxconn=65535' >> /etc/sysctl.conf
sysctl -p
```

### 8. **Security Best Practices**

#### Directory Permissions
```bash
# Tạo user riêng cho MinIO
sudo useradd -r -s /bin/false minio-user
sudo chown -R minio-user:minio-user /mnt/minio-data
sudo chmod -R 750 /mnt/minio-data
```

#### Secret Management
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: minio-system
type: Opaque
data:
  password: <base64-encoded-strong-password>
  accesskey: <base64-encoded-access-key>
  secretkey: <base64-encoded-secret-key>
```

### 9. **Scaling Strategy**

#### Horizontal Scaling
```bash
# Thêm node mới
kubectl label node new-node storage-node=true

# Tạo PV cho node mới
kubectl apply -f new-node-pvs.yaml

# Scale StatefulSet
kubectl scale statefulset minio --replicas=8 -n minio-system
```

#### Vertical Scaling
```yaml
# Tăng resource limits
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 10. **Troubleshooting Common Issues**

#### PVC Pending
```bash
# Kiểm tra events
kubectl describe pvc export-minio-0 -n minio-system

# Kiểm tra node affinity
kubectl get pv -o yaml | grep -A 10 nodeAffinity

# Tạo PV manual nếu cần
kubectl apply -f missing-pv.yaml
```

#### Storage Full
```bash
# Cleanup old data
kubectl exec -it minio-0 -n minio-system -- mc rm --recursive --force local/bucket/old-data/

# Add more PVs
kubectl apply -f additional-pvs.yaml

# Rebalance data
kubectl exec -it minio-0 -n minio-system -- mc admin rebalance start local
```

## Kết luận

Cấu hình hiện tại của bạn đã khá tốt với:
- ✅ Sử dụng local storage với nodeAffinity
- ✅ ReclaimPolicy: Retain bảo vệ dữ liệu
- ✅ Distributed setup với 6 PVs
- ✅ LoadBalancer services đã cấu hình

**Recommendations để cải thiện:**
1. Tăng PV size lên 50Gi+ cho production
2. Thêm resource limits cho MinIO pods
3. Implement backup strategy
4. Monitor storage usage thường xuyên
5. Cân nhắc sử dụng dedicated storage nodes