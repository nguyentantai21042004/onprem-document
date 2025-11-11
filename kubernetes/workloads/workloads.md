# Kubernetes Workloads Management

## Table of Contents

- [Introduction](#introduction)
- [Deployments](#deployments)
- [Services](#services)
- [ConfigMaps](#configmaps)
- [Secrets](#secrets)
- [Integration Patterns](#integration-patterns)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Introduction

Kubernetes workloads are the applications that run on your cluster. This comprehensive guide covers the core workload resources: Deployments for managing application instances, Services for network access, ConfigMaps for configuration data, and Secrets for sensitive information.

### Workload Hierarchy

```
Deployment → ReplicaSet → Pods → Containers
     ↓
  Service (Network Access)
     ↓
ConfigMap + Secret (Configuration)
```

---

## Deployments

### Overview

**Deployment** is the primary resource for managing stateless applications in Kubernetes. It provides declarative updates for pods and replica sets, enabling rolling updates, rollbacks, and scaling.

### Why Use Deployments?

#### Problems with Raw Pods
- Pod deletion results in permanent loss
- No automatic scaling capabilities
- No rolling update mechanism
- No rollback functionality
- Manual pod management complexity

#### Deployment Benefits
-  **Self-healing**: Automatic pod recreation on failure
-  **Scaling**: Easy horizontal scaling
-  **Rolling updates**: Zero-downtime deployments
-  **Rollback**: Quick reversion to previous versions
-  **Declarative management**: Define desired state

### Deployment Architecture

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

### Deployment Strategies

#### 1. RollingUpdate Strategy (Default)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%     # Maximum pods that can be unavailable
      maxSurge: 25%          # Maximum pods that can be created above desired
```

**How it works:**
```
Initial: [Pod-A-v1] [Pod-B-v1] [Pod-C-v1]
Step 1:  [Pod-A-v1] [Pod-B-v1] [Pod-C-v1] [Pod-D-v2]
Step 2:  [Pod-A-v1] [Pod-B-v1] [Pod-D-v2]
Step 3:  [Pod-A-v1] [Pod-B-v1] [Pod-D-v2] [Pod-E-v2]
Step 4:  [Pod-A-v1] [Pod-D-v2] [Pod-E-v2]
Step 5:  [Pod-A-v1] [Pod-D-v2] [Pod-E-v2] [Pod-F-v2]
Final:   [Pod-D-v2] [Pod-E-v2] [Pod-F-v2]
```

**Configuration examples:**
```yaml
# Zero downtime deployment
rollingUpdate:
  maxUnavailable: 0
  maxSurge: 1

# Fast deployment
rollingUpdate:
  maxUnavailable: 50%
  maxSurge: 50%

# Conservative deployment
rollingUpdate:
  maxUnavailable: 1
  maxSurge: 1
```

#### 2. Recreate Strategy

```yaml
spec:
  strategy:
    type: Recreate
```

**Use cases:**
- Applications that cannot run multiple versions simultaneously
- Shared storage that doesn't support concurrent access
- Quick deployments where downtime is acceptable

### Deployment Management

#### Scaling

```bash
# Scale deployment
kubectl scale deployment webapp-deployment --replicas=5

# Auto-scaling
kubectl autoscale deployment webapp-deployment --min=3 --max=10 --cpu-percent=80
```

#### Updates

```bash
# Update image
kubectl set image deployment/webapp-deployment webapp=webapp:v1.2.4

# Update with record
kubectl set image deployment/webapp-deployment webapp=webapp:v1.2.4 --record

# Edit deployment
kubectl edit deployment webapp-deployment
```

#### Rollbacks

```bash
# View rollout history
kubectl rollout history deployment/webapp-deployment

# Rollback to previous version
kubectl rollout undo deployment/webapp-deployment

# Rollback to specific revision
kubectl rollout undo deployment/webapp-deployment --to-revision=2

# Check rollout status
kubectl rollout status deployment/webapp-deployment
```

### Advanced Deployment Patterns

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

## Services

### Overview

**Services** provide stable network endpoints for accessing pods. They solve the problem of dynamic pod IP addresses and provide load balancing across multiple pod instances.

### Service Architecture

```
[Client] → [Service] → [Endpoints] → [Pods]
     ↓         ↓           ↓          ↓
   Request   Stable IP   Pod IPs   Containers
```

### Service Types

#### 1. ClusterIP (Default)

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
    port: 80          # Service port
    targetPort: 8080  # Pod port
```

**Characteristics:**
- Internal cluster access only
- Stable cluster IP address
- DNS name: `webapp-service.production.svc.cluster.local`
- Default service type

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
    nodePort: 30080   # Optional: K8s will assign if not specified
```

**Characteristics:**
- Exposes service on each node's IP
- Accessible via `<NodeIP>:<NodePort>`
- Port range: 30000-32767
- External traffic routing

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

**For on-premise (requires MetalLB or similar):**
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

### Service Discovery

#### DNS Resolution

```bash
# Within same namespace
curl http://webapp-service

# Cross-namespace
curl http://webapp-service.production

# Fully qualified domain name
curl http://webapp-service.production.svc.cluster.local
```

#### Environment Variables

```yaml
# Kubernetes automatically creates environment variables
WEBAPP_SERVICE_SERVICE_HOST=10.96.0.10
WEBAPP_SERVICE_SERVICE_PORT=80
```

### Advanced Service Configuration

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

#### Multi-Port Services

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

#### Headless Services

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

## ConfigMaps

### Overview

**ConfigMaps** store non-sensitive configuration data as key-value pairs, allowing you to separate configuration from application code.

### ConfigMap Creation

#### From Literal Values

```bash
kubectl create configmap webapp-config \
  --from-literal=database_host=db.company.com \
  --from-literal=database_port=5432 \
  --from-literal=log_level=INFO
```

#### From Files

```bash
# Create from single file
kubectl create configmap nginx-config --from-file=nginx.conf

# Create from directory
kubectl create configmap app-config --from-file=./config/

# Create from multiple files
kubectl create configmap app-config \
  --from-file=app.properties \
  --from-file=database.properties
```

#### From YAML Manifest

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
data:
  # Simple key-value pairs
  database_host: "db.company.com"
  database_port: "5432"
  redis_host: "redis.company.com"
  log_level: "INFO"
  
  # Configuration file
  app.properties: |
    database.host=db.company.com
    database.port=5432
    database.name=webapp
    cache.enabled=true
    cache.ttl=300
  
  # JSON configuration
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

### ConfigMap Usage

#### Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    # Use all ConfigMap keys as environment variables
    envFrom:
    - configMapRef:
        name: webapp-config
    # Use specific ConfigMap keys
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

#### Volume Mounts

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

#### Command Line Arguments

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

### ConfigMap Best Practices

#### 1. Immutable ConfigMaps

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

#### 2. Versioned ConfigMaps

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

#### 3. Environment-Specific ConfigMaps

```yaml
# Base configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-base
data:
  app_name: "webapp"
  timeout: "30s"
  
---
# Development overlay
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-dev
data:
  log_level: "DEBUG"
  database_host: "dev-db.company.com"
  
---
# Production overlay
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config-prod
data:
  log_level: "WARN"
  database_host: "prod-db.company.com"
```

---

## Secrets

### Overview

**Secrets** store sensitive data such as passwords, OAuth tokens, SSH keys, and TLS certificates. They are similar to ConfigMaps but designed for confidential data.

### Secret vs ConfigMap

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Purpose** | Configuration data | Sensitive data |
| **Encoding** | Plain text | Base64 encoded |
| **Storage** | etcd (plain text) | etcd (base64 encoded) |
| **Mount** | Disk | tmpfs (memory) |
| **Size limit** | 1MB | 1MB |

### Secret Types

#### 1. Opaque Secrets (Generic)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
data:
  username: YWRtaW4=                    # base64 encoded 'admin'
  password: cGFzc3dvcmQxMjM=            # base64 encoded 'password123'
  api-key: YWJjZGVmZ2hpamtsbW5vcA==    # base64 encoded API key
```

#### 2. TLS Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-tls
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...  # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi...  # base64 encoded private key
```

#### 3. Docker Registry Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJyZWdpc3RyeS5uZ3RhbnRhaS5wcm8iOiB7CiAgICAgICJ1c2VybmFtZSI6ICJhZG1pbiIsCiAgICAgICJwYXNzd29yZCI6ICJIYXJib3IxMjM0NSIsCiAgICAgICJhdXRoIjogIllXUnRhVzQ2U0dGeVltOXlNVEl6TkRVPSIKICAgIH0KICB9Cn0=
```

#### 4. SSH Key Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-key-secret
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: LS0tLS1CRUdJTi...  # base64 encoded private key
```

#### 5. Basic Auth Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
type: kubernetes.io/basic-auth
data:
  username: YWRtaW4=      # base64 encoded 'admin'
  password: cGFzc3dvcmQ=  # base64 encoded 'password'
```

### Secret Creation

#### From Command Line

```bash
# Create generic secret
kubectl create secret generic webapp-secrets \
  --from-literal=username=admin \
  --from-literal=password=password123

# Create TLS secret
kubectl create secret tls webapp-tls \
  --cert=server.crt \
  --key=server.key

# Create docker registry secret
kubectl create secret docker-registry harbor-secret \
  --docker-server=registry.ngtantai.pro \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@company.com
```

#### From Files

```bash
# Create from file
kubectl create secret generic ssl-certs \
  --from-file=tls.crt=/path/to/tls.crt \
  --from-file=tls.key=/path/to/tls.key

# Create from directory
kubectl create secret generic app-secrets \
  --from-file=./secrets/
```

### Secret Usage

#### Environment Variables

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

#### Volume Mounts

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

#### Image Pull Secrets

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

### Secret Security Best Practices

#### 1. Use External Secret Management

```yaml
# External Secrets Operator example
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

#### 2. Rotate Secrets Regularly

```bash
# Script to rotate secrets
#!/bin/bash
kubectl create secret generic webapp-secrets-new \
  --from-literal=username=admin \
  --from-literal=password=new-password123

# Update deployment to use new secret
kubectl patch deployment webapp-deployment \
  -p '{"spec":{"template":{"spec":{"volumes":[{"name":"secret-volume","secret":{"secretName":"webapp-secrets-new"}}]}}}}'

# Delete old secret after successful deployment
kubectl delete secret webapp-secrets
kubectl rename secret webapp-secrets-new webapp-secrets
```

#### 3. Limit Secret Access

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

## Integration Patterns

### Complete Application Stack

```yaml
# ConfigMap for configuration
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
# Secret for sensitive data
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
# Deployment using ConfigMap and Secret
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
# Service to expose the application
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

### Multi-Environment Pattern

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
            name: webapp-config-env  # Environment-specific
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: webapp-secrets-env  # Environment-specific
              key: database_password
```

---

## Best Practices

### 1. Resource Management

```yaml
# Always set resource requests and limits
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

### 2. Health Checks

```yaml
# Include liveness and readiness probes
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
# Use security context for containers
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

### 4. Labels and Annotations

```yaml
# Use consistent labeling
metadata:
  labels:
    app: webapp
    version: v1.2.3
    component: web
    part-of: ecommerce
    managed-by: helm
    environment: production
  annotations:
    description: "Production web application"
    contact: "devops@company.com"
    runbook: "https://runbook.company.com/webapp"
```

---

## Troubleshooting

### Common Issues

#### 1. Pod Startup Issues

```bash
# Check pod status
kubectl get pods -l app=webapp

# Describe pod for events
kubectl describe pod webapp-deployment-xxx

# Check logs
kubectl logs webapp-deployment-xxx

# Check previous container logs
kubectl logs webapp-deployment-xxx --previous
```

#### 2. Service Connectivity

```bash
# Test service DNS
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup webapp-service

# Test service connectivity
kubectl run debug --image=busybox --rm -it --restart=Never -- wget -O- webapp-service

# Check endpoints
kubectl get endpoints webapp-service

# Check service details
kubectl describe service webapp-service
```

#### 3. ConfigMap/Secret Issues

```bash
# Check ConfigMap contents
kubectl get configmap webapp-config -o yaml

# Check Secret contents (base64 encoded)
kubectl get secret webapp-secrets -o yaml

# Decode secret values
kubectl get secret webapp-secrets -o jsonpath='{.data.password}' | base64 -d

# Check volume mounts
kubectl describe pod webapp-deployment-xxx
```

#### 4. Deployment Issues

```bash
# Check deployment status
kubectl get deployment webapp-deployment

# Check deployment events
kubectl describe deployment webapp-deployment

# Check replica set
kubectl get replicaset -l app=webapp

# Check rollout status
kubectl rollout status deployment/webapp-deployment

# Check rollout history
kubectl rollout history deployment/webapp-deployment
```

### Debugging Commands

```bash
# Port forwarding for local testing
kubectl port-forward deployment/webapp-deployment 8080:8080

# Execute commands in pod
kubectl exec -it webapp-deployment-xxx -- /bin/bash

# Copy files to/from pod
kubectl cp webapp-deployment-xxx:/app/logs ./logs
kubectl cp ./config.yaml webapp-deployment-xxx:/app/config.yaml

# Monitor resource usage
kubectl top pods -l app=webapp
kubectl top nodes
```

---

## Next Steps

After mastering workload management:

1. **Learn Advanced Patterns**: StatefulSets, DaemonSets, Jobs
2. **Implement Ingress**: HTTP/HTTPS routing and load balancing
3. **Set up Monitoring**: Prometheus and Grafana integration
4. **Configure CI/CD**: Automated deployment pipelines
5. **Security Hardening**: RBAC, Network Policies, Pod Security Standards

For more advanced topics, refer to:
- [Cluster Setup](cluster-setup.md)
- [Kubernetes Concepts](kubernetes-concepts.md)
- [Management Tools](management-tools.md)
- [CI/CD Integration](cicd-integration.md)

---

## Conclusion

Kubernetes workloads form the foundation of container orchestration. Understanding how to properly configure Deployments, Services, ConfigMaps, and Secrets is essential for building robust, scalable, and maintainable applications.

The combination of these resources provides powerful capabilities for managing application lifecycle, network access, configuration management, and security. Regular practice with these concepts will improve your ability to design and operate complex containerized systems effectively. 