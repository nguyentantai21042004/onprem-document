# Kubernetes Concepts and YAML Configuration

## Table of Contents

- [Introduction](#introduction)
- [YAML Configuration Basics](#yaml-configuration-basics)
- [Kubernetes Resource Structure](#kubernetes-resource-structure)
- [Namespaces](#namespaces)
- [Resource Quotas](#resource-quotas)
- [Labels and Selectors](#labels-and-selectors)
- [Annotations](#annotations)
- [Configuration Management](#configuration-management)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Introduction

Kubernetes uses declarative configuration to define the desired state of your applications and infrastructure. This guide covers the fundamental concepts and YAML structure needed to effectively work with Kubernetes resources.

### Configuration Formats

Kubernetes supports multiple configuration formats:

| Format | Usage | Advantages | Disadvantages |
|--------|-------|------------|---------------|
| **YAML** | Most common | Human-readable, easy to edit | Sensitive to indentation |
| **JSON** | Programmatic | Precise, machine-readable | Verbose, less readable |
| **XML** | Rare | Structured | Complex, not commonly used |

**YAML** is the recommended and most widely used format in the Kubernetes ecosystem.

---

## YAML Configuration Basics

### Basic YAML Syntax

```yaml
# Comments start with #
key: value
nested:
  key: value
  another_key: "quoted value"
list:
  - item1
  - item2
  - item3
boolean: true
number: 42
multiline_string: |
  This is a
  multiline string
folded_string: >
  This is a folded
  string on one line
```

### YAML Best Practices

1. **Use 2 spaces for indentation** (not tabs)
2. **Quote strings** when they contain special characters
3. **Use meaningful names** for resources
4. **Add comments** to explain complex configurations
5. **Validate YAML** before applying

---

## Kubernetes Resource Structure

### Universal Resource Format

Every Kubernetes resource follows this structure:

```yaml
apiVersion: [API version]
kind: [Resource type]
metadata:
  [Resource metadata]
spec:
  [Resource specification]
status:
  [Resource status - read-only]
```

### Field Explanations

#### apiVersion

Specifies the API version for the resource:

```yaml
# Core API (v1) - Stable, built-in resources
apiVersion: v1

# Apps API (apps/v1) - Application workloads
apiVersion: apps/v1

# Batch API (batch/v1) - Jobs and CronJobs
apiVersion: batch/v1

# Networking API (networking.k8s.io/v1) - Network policies, ingress
apiVersion: networking.k8s.io/v1

# RBAC API (rbac.authorization.k8s.io/v1) - Role-based access control
apiVersion: rbac.authorization.k8s.io/v1

# Policy API (policy/v1) - Pod disruption budgets
apiVersion: policy/v1

# Autoscaling API (autoscaling/v2) - Horizontal pod autoscaling
apiVersion: autoscaling/v2

# Storage API (storage.k8s.io/v1) - Storage classes, volume attachments
apiVersion: storage.k8s.io/v1
```

#### kind

Specifies the type of Kubernetes resource:

```yaml
# Workload Resources
kind: Pod                    # Single instance of containers
kind: Deployment            # Manages replica sets and rolling updates
kind: StatefulSet           # Manages stateful applications
kind: DaemonSet            # Ensures pods run on every node
kind: Job                  # Run-to-completion workloads
kind: CronJob              # Scheduled jobs

# Service Resources
kind: Service              # Exposes applications
kind: Ingress             # HTTP/HTTPS routing
kind: EndpointSlice       # Network endpoints

# Configuration and Storage
kind: ConfigMap           # Configuration data
kind: Secret             # Sensitive data
kind: PersistentVolume   # Storage resource
kind: PersistentVolumeClaim  # Storage request
kind: StorageClass       # Storage provisioner

# Namespace and Identity
kind: Namespace          # Virtual cluster
kind: ServiceAccount     # Pod identity
kind: Role               # Namespace-scoped permissions
kind: ClusterRole        # Cluster-scoped permissions
kind: RoleBinding        # Bind role to subjects
kind: ClusterRoleBinding # Bind cluster role to subjects
```

#### metadata

Contains resource identification and metadata:

```yaml
metadata:
  name: webapp-deployment        # Resource name (required)
  namespace: production          # Namespace (optional, defaults to 'default')
  labels:                       # Key-value pairs for organization
    app: webapp
    version: v1.2.3
    environment: production
    team: backend
  annotations:                  # Extended metadata
    description: "Production web application"
    contact: "devops@company.com"
    last-updated: "2024-01-15"
    kubernetes.io/managed-by: "helm"
  finalizers:                   # Cleanup hooks
    - kubernetes.io/pv-protection
  ownerReferences:              # Resource ownership
    - apiVersion: apps/v1
      kind: ReplicaSet
      name: webapp-rs-12345
      uid: 12345-67890-abcde
```

#### spec

Defines the desired state of the resource:

```yaml
spec:
  replicas: 3                   # Desired number of instances
  selector:                     # How to select pods
    matchLabels:
      app: webapp
  template:                     # Pod template
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        env:
        - name: ENV_VAR
          value: "production"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: webapp-config
```

---

## Namespaces

### Concept Overview

**Namespaces** provide a mechanism to divide cluster resources between multiple users or teams. They offer:

- **Resource isolation** within a cluster
- **Naming scope** for resources
- **Access control** boundaries
- **Resource quota** enforcement

### Default Namespaces

```bash
# List all namespaces
kubectl get namespaces
# or
kubectl get ns
```

| Namespace | Purpose |
|-----------|---------|
| **default** | Default namespace for user resources |
| **kube-system** | System components created by Kubernetes |
| **kube-public** | Resources accessible to all users |
| **kube-node-lease** | Node heartbeat information |

### Creating Namespaces

#### Declarative Approach (Recommended)

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    name: development
    environment: dev
    team: backend
  annotations:
    description: "Development environment for backend team"
    contact: "backend-team@company.com"
```

#### Imperative Approach

```bash
# Create namespace
kubectl create namespace development

# Apply namespace from file
kubectl apply -f namespace.yaml

# Delete namespace (WARNING: Deletes all resources in namespace)
kubectl delete namespace development
```

### Namespace Configuration

#### Resource Naming

```yaml
# Resources are namespaced by default
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
  namespace: development  # Explicitly specify namespace
spec:
  containers:
  - name: webapp
    image: nginx:1.21
```

#### Cross-Namespace Communication

```yaml
# Service in 'backend' namespace
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: backend
spec:
  selector:
    app: api
  ports:
  - port: 80
```

```yaml
# Pod in 'frontend' namespace accessing backend service
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  namespace: frontend
spec:
  containers:
  - name: frontend
    image: nginx:1.21
    env:
    - name: API_URL
      value: "http://api-service.backend.svc.cluster.local:80"
```

### DNS Resolution in Namespaces

```
# Service DNS format
<service-name>.<namespace>.svc.cluster.local

# Examples:
webapp.default.svc.cluster.local
api-service.backend.svc.cluster.local
database.production.svc.cluster.local

# Short forms (from same namespace):
webapp
webapp.default
webapp.default.svc
```

---

## Resource Quotas

### Purpose

Resource quotas prevent a single namespace from consuming excessive cluster resources, ensuring fair resource distribution across teams and projects.

### Quota Types

#### Compute Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: development
spec:
  hard:
    # CPU quotas
    requests.cpu: "4"           # 4 CPU cores requested
    limits.cpu: "8"             # 8 CPU cores limit
    
    # Memory quotas
    requests.memory: 8Gi        # 8GB memory requested
    limits.memory: 16Gi         # 16GB memory limit
    
    # GPU quotas (if available)
    requests.nvidia.com/gpu: "2"
    limits.nvidia.com/gpu: "4"
```

#### Storage Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: development
spec:
  hard:
    # Storage quotas
    requests.storage: 100Gi     # 100GB storage requested
    persistentvolumeclaims: "10" # Maximum 10 PVCs
    
    # Storage class specific quotas
    requests.storage.class.gold: 20Gi
    requests.storage.class.silver: 50Gi
    requests.storage.class.bronze: 100Gi
```

#### Object Count Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-quota
  namespace: development
spec:
  hard:
    # Workload objects
    pods: "10"                  # Maximum 10 pods
    deployments.apps: "5"       # Maximum 5 deployments
    statefulsets.apps: "3"      # Maximum 3 statefulsets
    daemonsets.apps: "2"        # Maximum 2 daemonsets
    jobs.batch: "5"             # Maximum 5 jobs
    
    # Service objects
    services: "5"               # Maximum 5 services
    ingresses.networking.k8s.io: "3"  # Maximum 3 ingresses
    
    # Configuration objects
    configmaps: "10"            # Maximum 10 configmaps
    secrets: "10"               # Maximum 10 secrets
    
    # Storage objects
    persistentvolumeclaims: "10" # Maximum 10 PVCs
```

### Comprehensive Resource Quota Example

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: comprehensive-quota
  namespace: production
spec:
  hard:
    # Compute resources
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    
    # Storage resources
    requests.storage: 500Gi
    
    # Object counts
    pods: "50"
    deployments.apps: "20"
    services: "20"
    configmaps: "50"
    secrets: "50"
    persistentvolumeclaims: "25"
    
    # Network resources
    ingresses.networking.k8s.io: "10"
    networkpolicies.networking.k8s.io: "5"
```

### Managing Resource Quotas

```bash
# Apply resource quota
kubectl apply -f resource-quota.yaml

# View resource quotas
kubectl get resourcequota -n development

# Describe quota usage
kubectl describe resourcequota comprehensive-quota -n production

# Monitor quota usage
kubectl get resourcequota -n production -o yaml
```

---

## Labels and Selectors

### Labels

Labels are key-value pairs attached to objects for identification and organization:

```yaml
metadata:
  name: webapp-pod
  labels:
    app: webapp                 # Application name
    version: v1.2.3            # Version
    environment: production    # Environment
    tier: frontend             # Application tier
    team: backend              # Owning team
    release: stable            # Release channel
    component: web-server      # Component type
```

### Label Naming Conventions

```yaml
# Standard labels (recommended)
metadata:
  labels:
    # Application identification
    app.kubernetes.io/name: webapp
    app.kubernetes.io/instance: webapp-prod
    app.kubernetes.io/version: v1.2.3
    app.kubernetes.io/component: web-server
    app.kubernetes.io/part-of: ecommerce-platform
    
    # Management information
    app.kubernetes.io/managed-by: helm
    app.kubernetes.io/created-by: devops-team
    
    # Environment and deployment
    environment: production
    tier: frontend
    release: stable
```

### Selectors

#### Equality-based Selectors

```yaml
# Deployment selector
spec:
  selector:
    matchLabels:
      app: webapp
      version: v1.2.3
      
# Service selector
spec:
  selector:
    app: webapp
    tier: frontend
```

#### Set-based Selectors

```yaml
spec:
  selector:
    matchExpressions:
    - key: app
      operator: In
      values:
      - webapp
      - api-server
    - key: environment
      operator: NotIn
      values:
      - development
      - testing
    - key: version
      operator: Exists
    - key: deprecated
      operator: DoesNotExist
```

### Selector Operations

```bash
# Select pods with specific labels
kubectl get pods -l app=webapp
kubectl get pods -l app=webapp,version=v1.2.3

# Select pods with label existence
kubectl get pods -l version

# Select pods with label non-existence
kubectl get pods -l '!deprecated'

# Set-based selection
kubectl get pods -l 'app in (webapp,api-server)'
kubectl get pods -l 'environment notin (development,testing)'
```

---

## Annotations

### Purpose

Annotations store additional metadata that's not used for selection but provides context:

```yaml
metadata:
  annotations:
    # Deployment information
    deployment.kubernetes.io/revision: "3"
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment"...}
    
    # Build information
    build.version: "1.2.3"
    build.commit: "abc123def456"
    build.date: "2024-01-15T10:30:00Z"
    build.branch: "main"
    
    # Contact information
    contact.email: "devops@company.com"
    contact.team: "backend-team"
    contact.slack: "#backend-alerts"
    
    # Documentation
    documentation.url: "https://docs.company.com/webapp"
    runbook.url: "https://runbook.company.com/webapp"
    
    # Monitoring
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
    
    # Security
    security.scan.date: "2024-01-15"
    security.scan.status: "passed"
    
    # Compliance
    compliance.required: "true"
    compliance.framework: "SOC2"
```

### Common Annotation Patterns

#### Ingress Annotations

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.class: "nginx"
```

#### Service Annotations

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    external-dns.alpha.kubernetes.io/hostname: "webapp.company.com"
```

---

## Configuration Management

### ConfigMap Usage Patterns

#### Environment Variables

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
data:
  database_host: "db.company.com"
  database_port: "5432"
  redis_host: "redis.company.com"
  log_level: "INFO"
  feature_flags: "feature_a=true,feature_b=false"
```

```yaml
# Using ConfigMap in Pod
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
spec:
  containers:
  - name: webapp
    image: webapp:v1.2.3
    envFrom:
    - configMapRef:
        name: webapp-config
    env:
    - name: SPECIFIC_CONFIG
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: database_host
```

#### Configuration Files

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /api {
            proxy_pass http://backend-service:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
```

```yaml
# Mount ConfigMap as volume
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

### Secret Management

#### Basic Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
data:
  database-password: cGFzc3dvcmQxMjM=  # base64 encoded
  api-key: YWJjZGVmZ2hpams=            # base64 encoded
```

#### TLS Secret

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

#### Docker Registry Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6... # base64 encoded docker config
```

---

## Best Practices

### YAML Structure

1. **Use meaningful names**: `webapp-deployment` instead of `deployment-1`
2. **Include namespace**: Always specify namespace explicitly
3. **Add labels consistently**: Use standard label schema
4. **Include annotations**: Add metadata for context
5. **Use proper indentation**: 2 spaces, no tabs
6. **Validate YAML**: Use tools like `yamllint` or `kubeval`

### Resource Organization

```yaml
# Good structure
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: production
  labels:
    app: webapp
    version: v1.2.3
    environment: production
    tier: frontend
  annotations:
    description: "Production web application"
    maintainer: "backend-team@company.com"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: v1.2.3
  template:
    metadata:
      labels:
        app: webapp
        version: v1.2.3
        environment: production
        tier: frontend
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

### Security Considerations

1. **Use Secrets for sensitive data**: Never put passwords in ConfigMaps
2. **Limit resource access**: Use ResourceQuotas and NetworkPolicies
3. **Set resource limits**: Prevent resource exhaustion
4. **Use non-root containers**: Improve security posture
5. **Regular security scanning**: Monitor for vulnerabilities

---

## Common Patterns

### Multi-Environment Configuration

```yaml
# Base configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-base
data:
  log_format: "json"
  timeout: "30s"
  
---
# Environment-specific overlay
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-production
data:
  log_level: "WARN"
  database_pool_size: "20"
  cache_ttl: "300s"
```

### Blue-Green Deployment Labels

```yaml
# Blue deployment
metadata:
  labels:
    app: webapp
    version: v1.2.3
    slot: blue
    
# Green deployment
metadata:
  labels:
    app: webapp
    version: v1.2.4
    slot: green
```

### Canary Deployment Pattern

```yaml
# Stable deployment
spec:
  replicas: 9
  selector:
    matchLabels:
      app: webapp
      track: stable
      
# Canary deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
```

---

## Troubleshooting

### Common YAML Issues

1. **Indentation errors**: Use 2 spaces consistently
2. **Missing required fields**: Ensure all required fields are present
3. **Invalid selectors**: Labels must match selectors exactly
4. **Namespace issues**: Resources must exist in the same namespace
5. **Resource limits**: Ensure requests don't exceed limits

### Debugging Commands

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f deployment.yaml

# Check resource status
kubectl get deployment webapp-deployment -o yaml

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Describe resource for details
kubectl describe deployment webapp-deployment

# Check resource quotas
kubectl describe resourcequota -n production
```

---

## Next Steps

After mastering Kubernetes concepts:

1. **Learn Workload Management**: Understand Deployments, Services, and more
2. **Explore Advanced Patterns**: StatefulSets, DaemonSets, Jobs
3. **Set up CI/CD**: Integrate with Jenkins or GitLab CI
4. **Implement Monitoring**: Add Prometheus and Grafana
5. **Security Hardening**: RBAC, Network Policies, Pod Security

For more advanced topics, refer to:
- [Cluster Setup](cluster-setup.md)
- [Workload Management](workloads.md)
- [Management Tools](management-tools.md)
- [CI/CD Integration](cicd-integration.md)

---

## Conclusion

Understanding Kubernetes concepts and YAML configuration is fundamental to successful container orchestration. The declarative nature of Kubernetes allows you to define your desired state and let the system maintain it automatically.

Proper use of namespaces, labels, annotations, and resource quotas provides the foundation for organized, scalable, and maintainable Kubernetes deployments. Regular practice with these concepts will improve your ability to design and manage complex containerized applications. 