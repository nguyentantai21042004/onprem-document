# Jenkins Setup with Kubernetes

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Jenkins Installation](#jenkins-installation)
4. [Service Account Configuration](#service-account-configuration)
5. [Jenkins Configuration](#jenkins-configuration)
6. [Plugin Installation](#plugin-installation)
7. [Credentials Management](#credentials-management)
8. [Pipeline Setup](#pipeline-setup)
9. [Webhook Configuration](#webhook-configuration)
10. [Troubleshooting](#troubleshooting)

## Overview

This guide provides step-by-step instructions for setting up Jenkins on Kubernetes with proper service account configuration, authentication, and pipeline automation. Jenkins will be configured to deploy applications to the Kubernetes cluster using service accounts and tokens.

## Prerequisites

- Functional Kubernetes cluster (from [03-Kubernetes](../03-kubernetes/index.md))
- kubectl configured to access the cluster
- Harbor registry setup (from [02-Services](../02-services/index.md))
- Administrative access to Kubernetes cluster

## Jenkins Installation

### Step 1: Create Jenkins Namespace

```bash
# Create namespace for Jenkins
kubectl create namespace jenkins

# Verify namespace creation
kubectl get namespaces | grep jenkins
```

### Step 2: Create Persistent Volume for Jenkins

```yaml
# jenkins-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/var/jenkins_home"
```

```yaml
# jenkins-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

```bash
# Apply storage configuration
kubectl apply -f jenkins-pv.yaml
kubectl apply -f jenkins-pvc.yaml
kubectl get pv,pvc -n jenkins
```

### Step 3: Deploy Jenkins

```yaml
# jenkins-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
        - containerPort: 50000
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        env:
        - name: JAVA_OPTS
          value: "-Xmx2048m -Dhudson.slaves.NodeProvisioner.MARGIN=50 -Dhudson.slaves.NodeProvisioner.MARGIN0=0.85"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-pvc
```

```yaml
# jenkins-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  selector:
    app: jenkins
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: jnlp
    port: 50000
    targetPort: 50000
  type: NodePort
```

```bash
# Deploy Jenkins
kubectl apply -f jenkins-deployment.yaml
kubectl apply -f jenkins-service.yaml

# Check deployment status
kubectl get pods -n jenkins
kubectl get services -n jenkins
```

### Step 4: Create Jenkins Service Account

```yaml
# jenkins-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
```

```bash
# Apply service account configuration
kubectl apply -f jenkins-serviceaccount.yaml

# Verify service account
kubectl get serviceaccount -n jenkins
kubectl describe serviceaccount jenkins -n jenkins
```

## Service Account Configuration

### Step 1: Create Service Account for Application Deployment

```bash
# SSH to master node
ssh root@192.168.1.111

# Create service account for Jenkins in target namespace
kubectl create serviceaccount jenkins-deployer -n personal

# Grant edit permissions to the service account
kubectl create rolebinding jenkins-deployer-binding \
  --clusterrole=edit \
  --serviceaccount=personal:jenkins-deployer \
  --namespace=personal

# Verify service account creation
kubectl get serviceaccount jenkins-deployer -n personal
kubectl describe serviceaccount jenkins-deployer -n personal
```

### Step 2: Create Long-Lived Token

```bash
# Create token with 1 year expiration
kubectl create token jenkins-deployer -n personal --duration=8760h

# Save the token output - example token:
# eyJhbGciOiJSUzI1NiIsImtpZCI6IlhYcy1xWW9nNEN3SFJMTUxMcWN0eEw4NnFxdk93MGE4V2hsc3lKT3h2Tm8ifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzgzOTI1Mjg4LCJpYXQiOjE3NTIzODkyODgsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiYzc0NGMxMzEtNzljNi00YzVkLWE5ZDQtNWIwODkxMWNhNGM2Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJwZXJzb25hbCIsInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJqZW5raW5zLWRlcGxveWVyIiwidWlkIjoiZThhYmI1NTAtMWQ5Zi00OGJkLTgyZGQtODNjYzQzYjk1NjcxIn19LCJuYmYiOjE3NTIzODkyODgsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpwZXJzb25hbDpqZW5raW5zLWRlcGxveWVyIn0.ey777n2iE-m-gSBJJkFU18M-mUElhgX1RBCNweDUkMaGxhN88mb6hjD6Hjw7FkNqplILJPkl9YixDJ2qIOYGGG6iQlohsiwGThcINHLqfrQocKGXg7-E7V-8YzFJ4VAV59FhVflZwA4ErjK_gpQY9P70FkOHyAx5mLHHHWcMYz8c8WawXgnIXxpR7IU2trPXaG0OxELAv_GBYXiWsqAqkix7codMjXJMG7ueLiii27gfF_Jo0CmgI97gqO-M0DbYH-EEV5FhKMsqYzzQ3QsVFKbLqBGw_pm67AqfqvCTTjx7LgyFvcWaiwrFRh3eo0X0NKYbiDeYbTq1jbjS66QKfw
```

### Step 3: Alternative - Create Secret-Based Token

```yaml
# jenkins-token-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-token
  namespace: personal
  annotations:
    kubernetes.io/service-account.name: jenkins-deployer
type: kubernetes.io/service-account-token
```

```bash
# Apply secret
kubectl apply -f jenkins-token-secret.yaml

# Get token from secret
kubectl get secret jenkins-token -n personal -o jsonpath='{.data.token}' | base64 -d
```

## Jenkins Configuration

### Step 1: Access Jenkins UI

```bash
# Get Jenkins service details
kubectl get service jenkins -n jenkins

# Port forward to access Jenkins locally
kubectl port-forward service/jenkins 8080:8080 -n jenkins

# Access Jenkins at http://localhost:8080
```

### Step 2: Initial Setup

```bash
# Get initial admin password
kubectl exec -n jenkins deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword

# Follow the setup wizard:
# 1. Enter the initial admin password
# 2. Install suggested plugins
# 3. Create admin user
# 4. Configure Jenkins URL
```

### Step 3: Configure API Server Access

```bash
# Update API server configuration
kubectl patch -n kube-system configmap/kubeadm-config -p '{"data":{"ClusterConfiguration":"apiServer:\n  advertiseAddress: 192.168.1.111\n  bindPort: 6443\n  certSANs:\n  - \"192.168.1.111\"\n  - \"192.168.1.112\"\n  - \"192.168.1.113\"\n  - \"localhost\"\n  - \"127.0.0.1\"\n  extraArgs:\n    api-audiences: \"https://kubernetes.default.svc.cluster.local\"\n    service-account-issuer: \"https://kubernetes.default.svc.cluster.local\""}}'

# Restart API server
sudo systemctl restart kubelet
```

### Step 4: Test API Access

```bash
# Test API access with token
KUBE_TOKEN="your-token-here"
API_SERVER="https://192.168.1.111:6443"

curl -k -H "Authorization: Bearer $KUBE_TOKEN" $API_SERVER/api/v1/namespaces/personal/pods

# Expected response: JSON with pod information
```

## Plugin Installation

### Step 1: Install Required Plugins

Go to Jenkins Dashboard → Manage Jenkins → Manage Plugins → Available

Install these plugins:
- **Kubernetes Plugin** - For Kubernetes integration
- **Docker Plugin** - For Docker operations
- **Git Plugin** - For Git operations
- **Pipeline Plugin** - For pipeline as code
- **Credentials Plugin** - For credential management
- **Blue Ocean** - For modern UI
- **Slack Notification** - For notifications

### Step 2: Configure Kubernetes Plugin

1. Go to Manage Jenkins → Configure System
2. Add Kubernetes Cloud:
   - Name: kubernetes
   - Kubernetes URL: https://kubernetes.default.svc.cluster.local
   - Kubernetes server certificate key: (leave empty for default)
   - Credentials: Select the service account token
   - Kubernetes Namespace: jenkins

## Credentials Management

### Step 1: Add Kubernetes Token

1. Go to Jenkins Dashboard → Manage Jenkins → Manage Credentials
2. Click on "Jenkins" → "Global credentials" → "Add Credentials"
3. Configure:
   - Kind: Secret text
   - Scope: Global
   - ID: k8s-token
   - Secret: Paste the token from service account creation
   - Description: Kubernetes Token for Jenkins

### Step 2: Add Harbor Registry Credentials

1. Add new credentials:
   - Kind: Username with password
   - Scope: Global
   - ID: harbor-registry
   - Username: admin
   - Password: Harbor12345
   - Description: Harbor Registry Credentials

### Step 3: Add Git Credentials

1. Add new credentials:
   - Kind: Username with password (or SSH Username with private key)
   - Scope: Global
   - ID: git-credentials
   - Username: your-git-username
   - Password: your-git-token
   - Description: Git Repository Credentials

## Pipeline Setup

### Step 1: Create Pipeline Job

1. Go to Jenkins Dashboard → New Item
2. Enter name: portfolio-pipeline
3. Select "Pipeline" and click OK
4. Configure pipeline:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: https://github.com/yourusername/portfolio-app
   - Credentials: Select git-credentials
   - Branch: */main
   - Script Path: Jenkinsfile

### Step 2: Create Jenkinsfile

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "harbor.ngtantai.pro/personal/portfolio"
        KUBECONFIG_CREDENTIAL_ID = "k8s-token"
        HARBOR_CREDENTIAL_ID = "harbor-registry"
        KUBE_API_SERVER = "https://192.168.1.111:6443"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    def buildTime = new Date().format('ddMMyy-HHmmss')
                    env.BUILD_TAG = buildTime
                    
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${BUILD_TAG} .
                        docker build -t ${DOCKER_IMAGE}:latest .
                    """
                }
            }
        }
        
        stage('Test') {
            steps {
                sh """
                    docker run --rm ${DOCKER_IMAGE}:${BUILD_TAG} npm test || true
                """
            }
        }
        
        stage('Push to Harbor') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${HARBOR_CREDENTIAL_ID}",
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh """
                        docker login harbor.ngtantai.pro -u ${HARBOR_USER} -p ${HARBOR_PASS}
                        docker push ${DOCKER_IMAGE}:${BUILD_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([string(
                    credentialsId: "${KUBECONFIG_CREDENTIAL_ID}",
                    variable: 'K8S_TOKEN'
                )]) {
                    sh """
                        # Configure kubectl
                        kubectl config set-cluster kubernetes --server=${KUBE_API_SERVER} --insecure-skip-tls-verify=true
                        kubectl config set-credentials jenkins-deployer --token=${K8S_TOKEN}
                        kubectl config set-context jenkins-context --cluster=kubernetes --user=jenkins-deployer
                        kubectl config use-context jenkins-context
                        
                        # Update deployment
                        kubectl set image deployment/portfolio-deployment portfolio=${DOCKER_IMAGE}:${BUILD_TAG} -n personal
                        
                        # Wait for rollout
                        kubectl rollout status deployment/portfolio-deployment -n personal --timeout=300s
                        
                        # Verify deployment
                        kubectl get pods -n personal -l app=portfolio
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Clean up workspace
            cleanWs()
            
            // Remove local Docker images
            sh """
                docker rmi ${DOCKER_IMAGE}:${BUILD_TAG} || true
                docker rmi ${DOCKER_IMAGE}:latest || true
            """
        }
        success {
            echo 'Pipeline succeeded!'
            // Add notification here
        }
        failure {
            echo 'Pipeline failed!'
            // Add notification here
        }
    }
}
```

## Webhook Configuration

### Step 1: Configure GitHub Webhook

1. Go to GitHub repository → Settings → Webhooks
2. Add webhook:
   - Payload URL: http://your-jenkins-server:8080/github-webhook/
   - Content type: application/json
   - Secret: (optional)
   - Events: Just the push event

### Step 2: Configure Jenkins Job

1. Go to Jenkins job → Configure
2. Under "Build Triggers":
   - Check "GitHub hook trigger for GITScm polling"
   - Check "Poll SCM" (leave schedule empty)

### Step 3: Test Webhook

```bash
# Test webhook manually
curl -X POST \
  http://your-jenkins-server:8080/github-webhook/ \
  -H 'Content-Type: application/json' \
  -d '{"ref":"refs/heads/main"}'
```

## Troubleshooting

### Common Issues

#### 1. Jenkins Pod Not Starting

```bash
# Check pod status
kubectl describe pod jenkins-xxx -n jenkins

# Check logs
kubectl logs jenkins-xxx -n jenkins

# Common fixes:
# - Increase memory limits
# - Check PVC binding
# - Verify service account permissions
```

#### 2. Kubernetes API Connection Issues

```bash
# Test API connectivity from Jenkins pod
kubectl exec -n jenkins deployment/jenkins -- curl -k https://kubernetes.default.svc.cluster.local/api/v1/namespaces

# Check service account token
kubectl get secret jenkins-token -n personal -o yaml
```

#### 3. Docker Build Failures

```bash
# Check Docker daemon
systemctl status docker

# Check Docker permissions
sudo usermod -aG docker jenkins

# Restart Jenkins
kubectl rollout restart deployment/jenkins -n jenkins
```

#### 4. Pipeline Deployment Failures

```bash
# Check deployment status
kubectl get deployments -n personal
kubectl describe deployment portfolio-deployment -n personal

# Check pod logs
kubectl logs -f deployment/portfolio-deployment -n personal

# Check service account permissions
kubectl auth can-i update deployments --as=system:serviceaccount:personal:jenkins-deployer -n personal
```

### Health Check Script

```bash
#!/bin/bash
# jenkins-health-check.sh

echo "Jenkins Health Check"
echo "===================="

# Check Jenkins pod
echo "1. Checking Jenkins pod..."
kubectl get pods -n jenkins

# Check Jenkins service
echo "2. Checking Jenkins service..."
kubectl get service jenkins -n jenkins

# Check service account
echo "3. Checking service account..."
kubectl get serviceaccount jenkins-deployer -n personal

# Check API connectivity
echo "4. Testing API connectivity..."
TOKEN=$(kubectl get secret jenkins-token -n personal -o jsonpath='{.data.token}' | base64 -d)
curl -k -H "Authorization: Bearer $TOKEN" https://192.168.1.111:6443/api/v1/namespaces/personal/pods > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ API connectivity successful"
else
    echo "✗ API connectivity failed"
fi

# Check Harbor connectivity
echo "5. Testing Harbor connectivity..."
curl -k https://harbor.ngtantai.pro/api/v2.0/health > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ Harbor connectivity successful"
else
    echo "✗ Harbor connectivity failed"
fi

echo "Health check complete!"
```

### Monitoring and Alerting

```yaml
# jenkins-monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: jenkins-monitor
  namespace: jenkins
spec:
  selector:
    matchLabels:
      app: jenkins
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
```

This comprehensive guide provides everything needed to set up Jenkins with Kubernetes integration for CI/CD pipelines. The setup includes proper authentication, service accounts, and automated deployment workflows. 