# Lưu Trữ và Tính Bền Vững trong Kubernetes

## Mục Lục
1. [Tổng quan lưu trữ](#storage-overview)
2. [Persistent Volumes](#persistent-volumes)
3. [Persistent Volume Claims](#persistent-volume-claims)
4. [Storage Classes](#storage-classes)
5. [ConfigMap](#configmaps)
6. [Secret](#secrets)
7. [Các loại volume](#volume-types)
8. [Thực hành tốt](#best-practices)
9. [Khắc phục sự cố](#troubleshooting)

## Tổng quan lưu trữ

### Khái niệm lưu trữ trong Kubernetes

Kubernetes cung cấp nhiều cơ chế lưu trữ:

- **Ephemeral Storage**: Lưu trữ tạm thời, chỉ tồn tại khi Pod chạy
- **Persistent Storage**: Lưu trữ lâu dài, tồn tại ngoài vòng đời Pod
- **ConfigMap**: Lưu cấu hình dạng key-value
- **Secret**: Lưu dữ liệu nhạy cảm như mật khẩu, chứng chỉ

### Kiến trúc lưu trữ

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Application │    │ Persistent   │    │ Storage      │
│    Pod      │◄──►│ Volume Claim │◄──►│ Backend (PV) │
│             │    │   (PVC)      │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
                              │
                   ┌──────────────┐
                   │ Storage      │
                   │ Class        │
                   └──────────────┘
```

## Persistent Volumes

### Persistent Volume tĩnh

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
```

### Persistent Volume NFS

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.1.100
    path: /exported/path
  mountOptions:
    - nfsvers=4.1
    - hard
    - intr
```

### Persistent Volume iSCSI

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: iscsi-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  iscsi:
    targetPortal: 192.168.1.200:3260
    iqn: iqn.2001-04.com.example:storage.disk1
    lun: 0
    chapAuthSession: true
    secretRef:
      name: iscsi-secret
```

## Persistent Volume Claims

### PVC cơ bản

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd
```

### PVC dùng chung

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: nfs-storage
```

### Sử dụng PVC trong Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        - name: config-volume
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
      - name: config-volume
        configMap:
          name: mysql-config
```

## Storage Classes

### Dynamic Provisioning với Local Storage

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

### Storage Class NFS

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: cluster.local/nfs-subdir-external-provisioner
parameters:
  server: 192.168.1.100
  path: /srv/nfs
  onDelete: delete
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

### Storage Class SSD nhanh

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
parameters:
  type: ssd
  fsType: ext4
```

## ConfigMap

### ConfigMap cơ bản

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "mysql.default.svc.cluster.local"
  database_port: "3306"
  log_level: "INFO"
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
    database:
      host: mysql.default.svc.cluster.local
      port: 3306
      name: myapp
```

### Sử dụng ConfigMap trong Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

### Tạo ConfigMap từ file

```bash
# Tạo từ file
kubectl create configmap nginx-config --from-file=nginx.conf
# Tạo từ thư mục
kubectl create configmap web-config --from-file=config/
# Tạo từ giá trị trực tiếp
kubectl create configmap app-settings \
  --from-literal=key1=value1 \
  --from-literal=key2=value2
```

## Secret

### Secret cơ bản

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  username: dXNlcm5hbWU=  # base64
  password: cGFzc3dvcmQ=  # base64
```

### TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 cert
  tls.key: LS0tLS1CRUdJTi...  # base64 key
```

### Docker Registry Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJoYXJib3I...  # base64 docker config
```

### Tạo Secret

```bash
# Từ giá trị trực tiếp
kubectl create secret generic app-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123
# Tạo TLS secret từ file
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
# Tạo secret docker registry
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.ngtantai.pro \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com
```

### Sử dụng Secret trong Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: app
        image: harbor.ngtantai.pro/myproject/myapp:latest
        env:
        - name: DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        volumeMounts:
        - name: cert-volume
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: cert-volume
        secret:
          secretName: tls-secret
```

## Các loại volume

### EmptyDir

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
  volumes:
  - name: cache-volume
    emptyDir:
      sizeLimit: 1Gi
```

### HostPath

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /data
      type: DirectoryOrCreate
```

### CSI Volume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: csi-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: csi-storage
  csi:
    driver: csi.example.com
    volumeHandle: unique-volume-id
    fsType: ext4
```

## Thực hành tốt

### Quản lý lưu trữ

1. **Chọn access mode phù hợp**:
   - `ReadWriteOnce`: 1 node đọc/ghi
   - `ReadOnlyMany`: nhiều node chỉ đọc
   - `ReadWriteMany`: nhiều node đọc/ghi
2. **Chọn storage class đúng**:
   - SSD cho database
   - Network storage cho dữ liệu chia sẻ
   - Local storage cho dữ liệu tạm
3. **Backup đúng cách**:
   ```bash
   # Backup PVC
   kubectl exec -n default pod-name -- tar czf - /data | gzip > backup.tar.gz
   # Snapshot PV (nếu hỗ trợ)
   kubectl create volumesnapshot snapshot-name --claim=pvc-name
   ```

### Resource Quota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
spec:
  hard:
    requests.storage: "100Gi"
    persistentvolumeclaims: "10"
    count/persistentvolumeclaims: "10"
```

### Bảo mật

1. **Dùng secret cho dữ liệu nhạy cảm**:
   ```yaml
   # Không để mật khẩu trong ConfigMap
   env:
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-secret
         key: password
   ```
2. **Bật mã hóa khi lưu trữ**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: encrypted-secret
   type: Opaque
   data:
     key: <base64-encoded-encrypted-data>
   ```
3. **RBAC cho lưu trữ**:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: storage-reader
   rules:
   - apiGroups: [""]
     resources: ["persistentvolumes", "persistentvolumeclaims"]
     verbs: ["get", "list"]
   ```

### Tối ưu hiệu năng

1. **Dùng local storage cho workload hiệu năng cao**:
   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: local-ssd
   provisioner: kubernetes.io/no-provisioner
   volumeBindingMode: WaitForFirstConsumer
   ```
2. **Cấu hình giới hạn I/O**:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: io-limited-pod
   spec:
     containers:
     - name: app
       image: nginx
       resources:
         limits:
           ephemeral-storage: "2Gi"
         requests:
           ephemeral-storage: "1Gi"
   ```

## Khắc phục sự cố

### Vấn đề thường gặp

#### 1. PVC Pending

```bash
# Kiểm tra PVC
kubectl describe pvc pvc-name
# Kiểm tra PV
kubectl get pv
# Kiểm tra storage class
kubectl describe storageclass storage-class-name
# Kiểm tra event
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### 2. Lỗi mount

```bash
# Kiểm tra event pod
kubectl describe pod pod-name
# Kiểm tra volume mount
kubectl exec pod-name -- df -h
# Kiểm tra quyền file
kubectl exec pod-name -- ls -la /mount/path
```

#### 3. Lỗi hiệu năng lưu trữ

```bash
# Kiểm tra I/O
kubectl exec pod-name -- iostat -x 1
# Kiểm tra dung lượng
kubectl exec pod-name -- du -sh /data/*
# Theo dõi metric lưu trữ
kubectl top pods --containers
```

### Lệnh debug

```bash
# Liệt kê tài nguyên lưu trữ
kubectl get pv,pvc,storageclass
# Xem chi tiết storage class
kubectl describe storageclass
# Xem chi tiết PV
kubectl describe pv pv-name
# Xem chi tiết PVC
kubectl describe pvc pvc-name
# Xem volume mount pod
kubectl describe pod pod-name | grep -A 5 Volumes
# Xem nội dung ConfigMap
kubectl get configmap config-name -o yaml
# Xem nội dung Secret (base64)
kubectl get secret secret-name -o yaml
```

### Khôi phục

#### Khôi phục PVC lỗi

```bash
# Xóa PVC lỗi
kubectl delete pvc pvc-name --force --grace-period=0
# Tạo lại PVC
kubectl apply -f pvc.yaml
# Kiểm tra binding
kubectl get pvc pvc-name -w
```

#### Backup và restore

```bash
# Backup ConfigMap
kubectl get configmap config-name -o yaml > config-backup.yaml
# Backup Secret
kubectl get secret secret-name -o yaml > secret-backup.yaml
# Restore
kubectl apply -f config-backup.yaml
kubectl apply -f secret-backup.yaml
```

## Tích hợp

### MongoDB với lưu trữ bền vững

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:4.4
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
        - name: mongo-config
          mountPath: /data/configdb
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: password
  volumeClaimTemplates:
  - metadata:
      name: mongo-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
  - metadata:
      name: mongo-config
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi
```

### Ứng dụng với ConfigMap và Secret

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portfolio
  template:
    metadata:
      labels:
        app: portfolio
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: portfolio
        image: harbor.ngtantai.pro/personal/portfolio:latest
        ports:
        - containerPort: 80
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: database-url
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: api-key
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
        - name: static-volume
          mountPath: /app/static
      volumes:
      - name: config-volume
        configMap:
          name: portfolio-config
      - name: static-volume
        persistentVolumeClaim:
          claimName: static-content-pvc
```

Hướng dẫn này bao quát toàn bộ lưu trữ và tính bền vững trong Kubernetes, kèm ví dụ thực tế và thực hành tốt nhất cho môi trường on-premise. 