# Kubernetes Storage and Persistence

## Table of Contents
1. [Storage Overview](#storage-overview)
2. [Persistent Volumes](#persistent-volumes)
3. [Persistent Volume Claims](#persistent-volume-claims)
4. [Storage Classes](#storage-classes)
5. [ConfigMaps](#configmaps)
6. [Secrets](#secrets)
7. [Volume Types](#volume-types)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

## Storage Overview

### Kubernetes Storage Concepts

Kubernetes provides several mechanisms for handling storage:

- **Ephemeral Storage**: Temporary storage that exists only while a Pod is running
- **Persistent Storage**: Long-term storage that persists beyond Pod lifecycle
- **ConfigMaps**: Store configuration data as key-value pairs
- **Secrets**: Store sensitive data like passwords and certificates

### Storage Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Persistent    │    │   Storage       │
│      Pod        │◄──►│   Volume        │◄──►│   Backend       │
│                 │    │   Claim (PVC)   │    │   (PV)          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                  │
                       ┌─────────────────┐
                       │   Storage       │
                       │   Class         │
                       └─────────────────┘
```

## Persistent Volumes

### Static Persistent Volume

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

### NFS Persistent Volume

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

### iSCSI Persistent Volume

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

### Basic PVC

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

### Shared Storage PVC

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

### Using PVC in Deployment

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

### Dynamic Provisioning with Local Storage

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

### NFS Storage Class

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

### Fast SSD Storage Class

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

## ConfigMaps

### Basic ConfigMap

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

### Using ConfigMap in Pod

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

### ConfigMap from File

```bash
# Create ConfigMap from file
kubectl create configmap nginx-config --from-file=nginx.conf

# Create ConfigMap from directory
kubectl create configmap web-config --from-file=config/

# Create ConfigMap from literal values
kubectl create configmap app-settings \
  --from-literal=key1=value1 \
  --from-literal=key2=value2
```

## Secrets

### Basic Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  username: dXNlcm5hbWU=  # base64 encoded
  password: cGFzc3dvcmQ=  # base64 encoded
```

### TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi...  # base64 encoded private key
```

### Docker Registry Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJoYXJib3I...  # base64 encoded docker config
```

### Creating Secrets

```bash
# Create secret from literal values
kubectl create secret generic app-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Create TLS secret from files
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key

# Create Docker registry secret
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.ngtantai.pro \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com
```

### Using Secrets in Deployment

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

## Volume Types

### EmptyDir Volume

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

### HostPath Volume

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

## Best Practices

### Storage Management

1. **Use appropriate access modes**:
   - `ReadWriteOnce`: Single node read-write
   - `ReadOnlyMany`: Multiple nodes read-only
   - `ReadWriteMany`: Multiple nodes read-write

2. **Choose correct storage classes**:
   - Fast SSDs for databases
   - Network storage for shared data
   - Local storage for temporary data

3. **Implement proper backup strategies**:
   ```bash
   # Backup PVC data
   kubectl exec -n default pod-name -- tar czf - /data | gzip > backup.tar.gz
   
   # Snapshot PV (if supported)
   kubectl create volumesnapshot snapshot-name --claim=pvc-name
   ```

### Resource Quotas

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

### Security Best Practices

1. **Use secrets for sensitive data**:
   ```yaml
   # Never put passwords in ConfigMaps
   env:
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-secret
         key: password
   ```

2. **Enable encryption at rest**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: encrypted-secret
   type: Opaque
   data:
     key: <base64-encoded-encrypted-data>
   ```

3. **Use proper RBAC for storage access**:
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

### Performance Optimization

1. **Use local storage for high-performance workloads**:
   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: local-ssd
   provisioner: kubernetes.io/no-provisioner
   volumeBindingMode: WaitForFirstConsumer
   ```

2. **Configure appropriate I/O limits**:
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

## Troubleshooting

### Common Issues

#### 1. PVC Stuck in Pending State

```bash
# Check PVC status
kubectl describe pvc pvc-name

# Check available PVs
kubectl get pv

# Check storage class
kubectl describe storageclass storage-class-name

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### 2. Mount Issues

```bash
# Check pod events
kubectl describe pod pod-name

# Check volume mounts
kubectl exec pod-name -- df -h

# Check file permissions
kubectl exec pod-name -- ls -la /mount/path
```

#### 3. Storage Performance Issues

```bash
# Check I/O statistics
kubectl exec pod-name -- iostat -x 1

# Check disk usage
kubectl exec pod-name -- du -sh /data/*

# Monitor storage metrics
kubectl top pods --containers
```

### Debugging Commands

```bash
# List all storage resources
kubectl get pv,pvc,storageclass

# Check storage class details
kubectl describe storageclass

# Check PV details
kubectl describe pv pv-name

# Check PVC details
kubectl describe pvc pvc-name

# Check pod volume mounts
kubectl describe pod pod-name | grep -A 5 Volumes

# Check ConfigMap content
kubectl get configmap config-name -o yaml

# Check Secret content (base64 encoded)
kubectl get secret secret-name -o yaml
```

### Recovery Procedures

#### Recover from Failed PVC

```bash
# Delete stuck PVC
kubectl delete pvc pvc-name --force --grace-period=0

# Recreate PVC
kubectl apply -f pvc.yaml

# Check binding
kubectl get pvc pvc-name -w
```

#### Backup and Restore

```bash
# Backup ConfigMap
kubectl get configmap config-name -o yaml > config-backup.yaml

# Backup Secret
kubectl get secret secret-name -o yaml > secret-backup.yaml

# Restore from backup
kubectl apply -f config-backup.yaml
kubectl apply -f secret-backup.yaml
```

## Integration Examples

### MongoDB with Persistent Storage

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

### Application with ConfigMap and Secret

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

This comprehensive guide covers all aspects of Kubernetes storage and persistence, providing practical examples and best practices for managing data in your on-premise Kubernetes cluster. 