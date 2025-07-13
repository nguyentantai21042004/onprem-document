# Configuration Templates

## 📋 Overview

This section contains ready-to-use configuration templates for all components of your on-premise server infrastructure. These templates are organized by service type and include examples from real deployments.

## 🗂️ Directory Structure

```
05-config-templates/
├── index.md                    # This file
├── kubernetes/                 # Kubernetes resource templates
│   ├── deployments/           # Application deployments
│   ├── services/              # Service definitions
│   ├── ingress/               # Ingress configurations
│   ├── storage/               # Storage configurations
│   ├── rbac/                  # RBAC configurations
│   └── monitoring/            # Monitoring configurations
├── jenkins/                   # Jenkins configuration files
│   ├── pipelines/             # Pipeline templates
│   ├── jobs/                  # Job configurations
│   └── plugins/               # Plugin configurations
├── infrastructure/            # Infrastructure templates
│   ├── systemd/               # Systemd service files
│   ├── network/               # Network configurations
│   └── certificates/          # Certificate templates
└── applications/              # Application-specific configs
    ├── portfolio/             # Portfolio application
    ├── cv/                    # CV application
    └── monitoring/            # Monitoring configurations
```

## 🚀 Quick Start

### Using Templates

1. **Navigate to the appropriate directory**
2. **Copy the template file**
3. **Customize the values** (marked with `<REPLACE_ME>`)
4. **Apply the configuration**

```bash
# Example: Deploy portfolio application
cp 05-config-templates/applications/portfolio/deployment.yaml ./
# Edit the file with your values
kubectl apply -f deployment.yaml
```

### Template Variables

Common variables used across templates:
- `<NAMESPACE>`: Target namespace (e.g., `personal`, `production`)
- `<DOMAIN>`: Your domain name (e.g., `ngtantai.pro`)
- `<REGISTRY>`: Harbor registry URL (e.g., `harbor.ngtantai.pro`)
- `<IMAGE_TAG>`: Docker image tag (e.g., `latest`, `v1.0.0`)
- `<CLUSTER_IP>`: Kubernetes cluster IP range
- `<NODE_IP>`: Node IP addresses

## 📚 Template Categories

### 1. Kubernetes Resources

#### Deployments
- **Basic Deployment**: Simple application deployment
- **Stateful Deployment**: Database deployments with persistent storage
- **Multi-container Deployment**: Applications with sidecars
- **Highly Available Deployment**: Multi-replica with anti-affinity

#### Services
- **ClusterIP Service**: Internal service access
- **NodePort Service**: External access via node ports
- **LoadBalancer Service**: External load balancer integration
- **Headless Service**: For StatefulSets

#### Ingress
- **Basic Ingress**: Simple HTTP routing
- **TLS Ingress**: HTTPS with certificates
- **Multi-host Ingress**: Multiple domains
- **Path-based Ingress**: URL path routing

#### Storage
- **PersistentVolume**: Storage definitions
- **PersistentVolumeClaim**: Storage claims
- **StorageClass**: Dynamic provisioning
- **ConfigMap**: Configuration data

#### RBAC
- **ServiceAccount**: Service account definitions
- **Role**: Namespace-specific permissions
- **ClusterRole**: Cluster-wide permissions
- **RoleBinding**: Role assignments

### 2. Jenkins Configurations

#### Pipelines
- **Build Pipeline**: Basic build and test
- **Deploy Pipeline**: Build, test, and deploy
- **Multi-stage Pipeline**: Complex workflows
- **GitOps Pipeline**: GitOps-style deployments

#### Jobs
- **Freestyle Job**: Simple job configuration
- **Pipeline Job**: Pipeline as code
- **Multi-branch Pipeline**: Branch-based builds
- **Parameterized Job**: Jobs with parameters

### 3. Infrastructure Templates

#### Systemd Services
- **Application Service**: Run applications as services
- **Database Service**: Database service management
- **Monitoring Service**: Monitoring agent services
- **Backup Service**: Automated backup services

#### Network
- **Firewall Rules**: iptables configurations
- **Load Balancer**: HAProxy configurations
- **VPN Configuration**: OpenVPN settings
- **DNS Configuration**: DNS server settings

### 4. Application Templates

#### Portfolio Application
- **Frontend Deployment**: React/Vue.js applications
- **Backend API**: Node.js/Python APIs
- **Database**: PostgreSQL/MongoDB
- **Cache**: Redis configurations

#### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Alertmanager**: Alert routing
- **Exporters**: Metric exporters

## 🔧 Template Usage Examples

### Deploy Portfolio Application

```bash
# 1. Copy template
cp 05-config-templates/applications/portfolio/deployment.yaml portfolio-deployment.yaml

# 2. Edit variables
sed -i 's/<NAMESPACE>/personal/g' portfolio-deployment.yaml
sed -i 's/<DOMAIN>/ngtantai.pro/g' portfolio-deployment.yaml
sed -i 's/<REGISTRY>/harbor.ngtantai.pro/g' portfolio-deployment.yaml

# 3. Apply configuration
kubectl apply -f portfolio-deployment.yaml
```

### Setup Jenkins Pipeline

```bash
# 1. Copy Jenkinsfile template
cp 05-config-templates/jenkins/pipelines/build-deploy.groovy Jenkinsfile

# 2. Customize for your project
vim Jenkinsfile

# 3. Commit to your repository
git add Jenkinsfile
git commit -m "Add Jenkins pipeline"
git push origin main
```

### Create Ingress with TLS

```bash
# 1. Copy ingress template
cp 05-config-templates/kubernetes/ingress/tls-ingress.yaml ingress.yaml

# 2. Update domain and service
sed -i 's/<DOMAIN>/portfolio.ngtantai.pro/g' ingress.yaml
sed -i 's/<SERVICE_NAME>/portfolio-service/g' ingress.yaml

# 3. Apply ingress
kubectl apply -f ingress.yaml
```

## 📋 Template Validation

### Pre-deployment Checks

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f your-template.yaml

# Check resource quotas
kubectl describe resourcequota -n your-namespace

# Validate RBAC permissions
kubectl auth can-i create pods --as=system:serviceaccount:namespace:serviceaccount

# Check storage availability
kubectl get pv,pvc,storageclass
```

### Post-deployment Verification

```bash
# Check deployment status
kubectl get deployments -n your-namespace
kubectl rollout status deployment/your-deployment -n your-namespace

# Verify service connectivity
kubectl get services -n your-namespace
kubectl get endpoints -n your-namespace

# Test ingress routing
curl -H "Host: your-domain.com" http://your-ingress-ip

# Check logs
kubectl logs -f deployment/your-deployment -n your-namespace
```

## 🔐 Security Best Practices

### Secret Management

```bash
# Create secrets from templates
kubectl create secret generic app-secret \
  --from-literal=username=admin \
  --from-literal=password=your-password \
  --namespace=your-namespace

# Use secrets in deployments
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: password
```

### RBAC Configuration

```yaml
# Principle of least privilege
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
```

### Network Policies

```yaml
# Restrict network access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## 📈 Monitoring and Alerting

### Prometheus Configuration

```yaml
# ServiceMonitor for application metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-metrics
spec:
  selector:
    matchLabels:
      app: your-app
  endpoints:
  - port: metrics
    interval: 30s
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Application Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ]
      }
    ]
  }
}
```

## 🏆 Best Practices

### Template Organization

1. **Use descriptive names** for template files
2. **Include comments** explaining configuration options
3. **Provide examples** for common use cases
4. **Version control** your templates
5. **Document dependencies** between templates

### Configuration Management

1. **Use ConfigMaps** for non-sensitive configuration
2. **Use Secrets** for sensitive data
3. **Implement proper labeling** for resource organization
4. **Set resource limits** for all containers
5. **Use namespaces** for isolation

### Deployment Practices

1. **Test in staging** before production
2. **Use rolling updates** for zero-downtime deployments
3. **Implement health checks** for all services
4. **Monitor resource usage** and adjust limits
5. **Have rollback procedures** ready

## 🔗 Integration Points

### With Infrastructure Layer
- Network configurations match infrastructure setup
- Storage classes align with available storage
- Security certificates are properly referenced

### With Services Layer
- Database connections use service discovery
- Registry configurations match Harbor setup
- Monitoring integrates with Prometheus stack

### With Kubernetes Layer
- Resource quotas align with cluster capacity
- RBAC policies follow security guidelines
- Ingress configurations match networking setup

### With CI/CD Layer
- Pipeline templates match build requirements
- Deployment strategies align with application needs
- Secret management integrates with Jenkins

## 📞 Support and Troubleshooting

### Common Issues

1. **Template Variable Replacement**: Ensure all `<REPLACE_ME>` values are updated
2. **Resource Conflicts**: Check for duplicate resource names
3. **Permission Issues**: Verify RBAC configurations
4. **Network Connectivity**: Validate service and ingress configurations
5. **Storage Issues**: Check PVC binding and storage availability

### Validation Tools

```bash
# YAML validation
yamllint your-template.yaml

# Kubernetes validation
kubectl apply --dry-run=client -f your-template.yaml

# Security scanning
kube-score score your-template.yaml

# Resource validation
kubectl describe -f your-template.yaml
```

## 📝 Contributing

### Adding New Templates

1. Create template in appropriate directory
2. Use consistent variable naming (`<VARIABLE_NAME>`)
3. Add comprehensive comments
4. Include example usage
5. Document dependencies
6. Test with real deployments

### Template Standards

```yaml
# Template header
# Description: What this template does
# Dependencies: Required components
# Variables: List of variables to replace
# Usage: How to use this template

apiVersion: v1
kind: YourResource
metadata:
  name: <RESOURCE_NAME>
  namespace: <NAMESPACE>
  labels:
    app: <APP_NAME>
    version: <VERSION>
spec:
  # Configuration with comments
  # <VARIABLE>: Replace with actual value
```

---

**Remember**: Templates are starting points. Always customize them for your specific environment and requirements. Test thoroughly before using in production.

**Philosophy**: Template → Customize → Validate → Deploy → Monitor 