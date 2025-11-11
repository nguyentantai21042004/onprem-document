# Rancher Management Platform

## Table of Contents
1. [Rancher Overview](#rancher-overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Initial Configuration](#initial-configuration)
5. [Cluster Management](#cluster-management)
6. [User Management](#user-management)
7. [Project and Namespace Management](#project-and-namespace-management)
8. [Monitoring and Alerting](#monitoring-and-alerting)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Rancher Overview

Rancher is a comprehensive container management platform that provides a complete software stack for teams adopting containers. It addresses the operational and security challenges of managing multiple Kubernetes clusters across any infrastructure.

### Key Features

- **Multi-Cluster Management**: Deploy and manage Kubernetes clusters across multiple environments
- **Centralized Authentication**: Integrate with Active Directory, LDAP, GitHub, and other identity providers
- **Project-based Multi-tenancy**: Organize resources into projects with role-based access control
- **Integrated Monitoring**: Built-in monitoring, logging, and alerting capabilities
- **Application Catalog**: Deploy applications from Helm charts and custom catalogs
- **DevOps Pipeline**: Integrated CI/CD pipeline with GitHub, GitLab integration

### Architecture Components

- **Rancher Server**: The main management interface and API server
- **Rancher Agent**: Runs on each managed cluster node
- **Cluster**: Kubernetes clusters managed by Rancher
- **Project**: Logical grouping of namespaces within a cluster
- **Workload**: Deployments, StatefulSets, DaemonSets, Jobs, and CronJobs

## Prerequisites

### System Requirements

#### Rancher Server
- **CPU**: 4 vCPUs minimum
- **Memory**: 8GB RAM minimum
- **Storage**: 50GB SSD minimum
- **OS**: Ubuntu 20.04 LTS or CentOS 8

#### Managed Clusters
- **CPU**: 2 vCPUs per node minimum
- **Memory**: 4GB RAM per node minimum
- **Storage**: 20GB per node minimum
- **Network**: All nodes must communicate with Rancher server

### Network Requirements

```bash
# Required ports for Rancher server
# 80/443 - HTTP/HTTPS access
# 6443 - Kubernetes API server
# 2379-2380 - etcd client and peer communication
# 10250 - Kubelet API
# 10251 - kube-scheduler
# 10252 - kube-controller-manager
```

## Installation

### Option 1: Docker Installation (Single Node)

```bash
# Create data directory
sudo mkdir -p /opt/rancher
sudo chown -R 1000:1000 /opt/rancher

# Run Rancher server
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /opt/rancher:/var/lib/rancher \
  --privileged \
  rancher/rancher:latest

# Check installation
sudo docker logs rancher
```

### Option 2: Kubernetes Installation (High Availability)

```bash
# Add Rancher Helm repository
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Create namespace
kubectl create namespace cattle-system

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Install Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=your-email@domain.com

# Check installation
kubectl -n cattle-system get pods
```

### Option 3: Manual Installation with Custom Storage

```bash
# Prepare storage disk
sudo fdisk -l
sudo mkfs.ext4 /dev/sdb
sudo mkdir /var/lib/rancher
sudo mount /dev/sdb /var/lib/rancher

# Make mount permanent
echo "/dev/sdb /var/lib/rancher ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Install Docker if not present
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable docker
sudo systemctl start docker

# Run Rancher with custom storage
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /var/lib/rancher:/var/lib/rancher \
  -v /var/log/rancher:/var/log/rancher \
  --privileged \
  rancher/rancher:latest
```

## Initial Configuration

### First Access

1. **Access Rancher UI**:
   ```
   https://your-rancher-server
   ```

2. **Set Admin Password**:
   ```bash
   # Get bootstrap password if using Helm
   kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}'
   ```

3. **Configure Server URL**:
   Set the server URL to match your domain or IP

### SSL/TLS Configuration

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout rancher.key -out rancher.crt -days 365 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=rancher.yourdomain.com"

# Create Kubernetes secret
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=rancher.crt \
  --key=rancher.key

# Update Rancher installation
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.yourdomain.com \
  --set ingress.tls.source=secret \
  --set ingress.tls.secretName=tls-rancher-ingress
```

## Cluster Management

### Import Existing Cluster

1. **From Rancher UI**:
   - Go to "Cluster Management"
   - Click "Import Existing"
   - Enter cluster name and description
   - Copy the provided command

2. **Run on Target Cluster**:
   ```bash
   # Apply the generated manifest
   kubectl apply -f https://rancher.yourdomain.com/v3/import/xxx.yaml
   ```

### Create New Cluster

#### RKE2 Cluster Creation

```bash
# Create cluster configuration
cat > cluster.yml << EOF
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: production-cluster
  namespace: fleet-default
spec:
  kubernetesVersion: v1.26.8+rke2r1
  rkeConfig:
    machineGlobalConfig:
      cni: calico
      disable-kube-proxy: false
      etcd-expose-metrics: false
    machinePools:
    - name: master-pool
      quantity: 3
      etcdRole: true
      controlPlaneRole: true
      workerRole: false
      machineConfigRef:
        kind: VmwarevsphereConfig
        name: master-config
    - name: worker-pool
      quantity: 3
      etcdRole: false
      controlPlaneRole: false
      workerRole: true
      machineConfigRef:
        kind: VmwarevsphereConfig
        name: worker-config
EOF

kubectl apply -f cluster.yml
```

### Cluster Upgrades

```bash
# List available Kubernetes versions
kubectl get kontainerdriver

# Upgrade cluster
kubectl patch cluster production-cluster -p '{"spec":{"kubernetesVersion":"v1.27.5+rke2r1"}}' --type merge

# Monitor upgrade progress
kubectl get cluster production-cluster -o yaml
```

## User Management

### Authentication Configuration

#### Active Directory Integration

```yaml
apiVersion: management.cattle.io/v3
kind: ActiveDirectoryConfig
metadata:
  name: activedirectory
spec:
  servers:
  - "ldap://your-ad-server:389"
  serviceAccountUsername: "rancher@yourdomain.com"
  serviceAccountPassword: "password"
  userSearchBase: "ou=users,dc=yourdomain,dc=com"
  groupSearchBase: "ou=groups,dc=yourdomain,dc=com"
  userObjectClass: "person"
  userLoginAttribute: "sAMAccountName"
  userNameAttribute: "name"
  userEnabledAttribute: "userAccountControl"
  groupObjectClass: "group"
  groupNameAttribute: "name"
  groupMemberUserAttribute: "distinguishedName"
  groupMemberMapAttribute: "member"
  connectionTimeout: 5000
  requestTimeout: 5000
```

#### GitHub Authentication

```yaml
apiVersion: management.cattle.io/v3
kind: GithubConfig
metadata:
  name: github
spec:
  clientId: "your-github-client-id"
  clientSecret: "your-github-client-secret"
  hostname: "github.com"
  tls: true
```

### Role-Based Access Control

#### Global Roles

```yaml
apiVersion: management.cattle.io/v3
kind: GlobalRole
metadata:
  name: custom-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

#### Cluster Roles

```yaml
apiVersion: management.cattle.io/v3
kind: RoleTemplate
metadata:
  name: cluster-viewer
context: cluster
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
```

#### Project Roles

```yaml
apiVersion: management.cattle.io/v3
kind: RoleTemplate
metadata:
  name: project-developer
context: project
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
```

## Project and Namespace Management

### Create Projects

```yaml
apiVersion: management.cattle.io/v3
kind: Project
metadata:
  name: production-project
  namespace: c-cluster-id
spec:
  clusterId: "c-cluster-id"
  displayName: "Production Project"
  description: "Production environment project"
  resourceQuota:
    limit:
      requestsCpu: "10000m"
      requestsMemory: "20Gi"
      persistentvolumeclaims: "10"
```

### Namespace Management

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production-app
  labels:
    field.cattle.io/projectId: "c-cluster-id:p-project-id"
  annotations:
    field.cattle.io/projectId: "c-cluster-id:p-project-id"
spec:
  finalizers:
  - controller.cattle.io/namespace-auth
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production-app
spec:
  hard:
    requests.cpu: "4000m"
    requests.memory: "8Gi"
    limits.cpu: "8000m"
    limits.memory: "16Gi"
    persistentvolumeclaims: "5"
    pods: "10"
    services: "5"
```

## Monitoring and Alerting

### Enable Monitoring

```bash
# Enable cluster monitoring
kubectl patch cluster production-cluster -p '{"spec":{"enableClusterMonitoring":true}}' --type merge

# Enable project monitoring
kubectl patch project production-project -p '{"spec":{"enableProjectMonitoring":true}}' --type merge
```

### Custom Alerts

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: cattle-monitoring-system
spec:
  groups:
  - name: cluster.rules
    rules:
    - alert: NodeDown
      expr: up{job="node-exporter"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Node {{ $labels.instance }} is down"
        description: "Node {{ $labels.instance }} has been down for more than 5 minutes"
```

## Best Practices

### Security Best Practices

1. **Enable RBAC**: Always use role-based access control
2. **Regular Updates**: Keep Rancher server and agents updated
3. **Network Segmentation**: Isolate cluster networks
4. **Audit Logging**: Enable and monitor audit logs
5. **Secret Management**: Use Kubernetes secrets for sensitive data

### Operational Best Practices

1. **Backup Strategy**: Regular backups of etcd and Rancher data
2. **Monitoring**: Implement comprehensive monitoring
3. **Resource Limits**: Set appropriate resource quotas
4. **Cluster Organization**: Use projects for multi-tenancy
5. **Automation**: Automate cluster provisioning and management

### Performance Optimization

```yaml
# Rancher server optimization
apiVersion: v1
kind: ConfigMap
metadata:
  name: rancher-config
  namespace: cattle-system
data:
  CATTLE_AGENT_LOGLEVEL: "info"
  CATTLE_SERVER_LOGLEVEL: "info"
  CATTLE_PROMETHEUS_METRICS: "true"
  CATTLE_FEATURES: "multi-cluster-management=true"
```

## Troubleshooting

### Common Issues

#### 1. Cluster Import Failures

```bash
# Check agent logs
kubectl logs -n cattle-system deployment/cattle-cluster-agent

# Check node agent logs
kubectl logs -n cattle-system daemonset/cattle-node-agent

# Verify connectivity
curl -k https://rancher.yourdomain.com/ping
```

#### 2. Authentication Issues

```bash
# Check authentication provider logs
kubectl logs -n cattle-system deployment/rancher

# Verify authentication configuration
kubectl get authconfig -o yaml
```

#### 3. Performance Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n cattle-system

# Monitor etcd performance
kubectl exec -n cattle-system etcd-xxx -- etcdctl endpoint status
```

### Diagnostic Commands

```bash
# Check Rancher server status
kubectl get pods -n cattle-system
kubectl describe pod -n cattle-system rancher-xxx

# Check cluster status
kubectl get clusters
kubectl describe cluster production-cluster

# Check projects and namespaces
kubectl get projects
kubectl get namespaces

# Export cluster configuration
kubectl get cluster production-cluster -o yaml > cluster-backup.yaml
```

### Recovery Procedures

#### Rancher Server Recovery

```bash
# Stop Rancher container
sudo docker stop rancher

# Backup data
sudo cp -r /var/lib/rancher /backup/rancher-$(date +%Y%m%d)

# Start Rancher with backup
sudo docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  -v /backup/rancher-20240101:/var/lib/rancher \
  --privileged \
  rancher/rancher:latest
```

#### Cluster Recovery

```bash
# Restore from backup
kubectl apply -f cluster-backup.yaml

# Reinstall agents if needed
kubectl apply -f https://rancher.yourdomain.com/v3/import/xxx.yaml
```

## Integration Examples

### CI/CD Pipeline Integration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rancher-pipeline-config
data:
  rancher-url: "https://rancher.yourdomain.com"
  cluster-id: "c-cluster-id"
  project-id: "p-project-id"
```

### Monitoring Integration

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: rancher-monitoring
spec:
  selector:
    matchLabels:
      app: rancher
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

This comprehensive guide provides everything needed to set up and manage Rancher for your Kubernetes infrastructure, following the deployment philosophy of using GUI tools first to understand the configurations, then extracting and standardizing the YAML templates for production use. 