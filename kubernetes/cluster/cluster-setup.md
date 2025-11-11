# Kubernetes Cluster Setup Guide

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [System Preparation](#system-preparation)
- [Container Runtime Setup](#container-runtime-setup)
- [Kubernetes Installation](#kubernetes-installation)
- [Cluster Initialization](#cluster-initialization)
- [High Availability Setup](#high-availability-setup)
- [Network Configuration](#network-configuration)
- [Cluster Validation](#cluster-validation)
- [Troubleshooting](#troubleshooting)
- [Integration with Other Services](#integration-with-other-services)

---

## Introduction

This guide provides comprehensive instructions for setting up a production-ready Kubernetes cluster with High Availability (HA) configuration. The setup includes 3 master nodes that serve as both control plane and worker nodes, ensuring maximum availability and resource utilization.

### K8s vs K3s

| Feature | K8s (Full Kubernetes) | K3s (Lightweight K8s) |
|---------|----------------------|----------------------|
| **Target Use Case** | Production environments | Edge computing, IoT |
| **Resource Usage** | Higher (full feature set) | Lower (minimal components) |
| **Components** | All standard components | Stripped down essentials |
| **Customization** | Full flexibility | Limited customization |
| **Best For** | Enterprise deployments | Development, small deployments |

### Cluster Architecture Options

#### Basic Cluster (Not Recommended for Production)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Master Node   │    │  Worker Node 1  │    │  Worker Node 2  │
│ (Control Plane) │    │  (App Workload) │    │  (App Workload) │
│  No Workloads   │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### HA Cluster (Recommended)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Master Node 1  │    │  Master Node 2  │    │  Master Node 3  │
│ Control Plane + │    │ Control Plane + │    │ Control Plane + │
│   Workloads     │    │   Workloads     │    │   Workloads     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## Prerequisites

### Hardware Requirements

| Component | Minimum per Node | Recommended per Node |
|-----------|------------------|---------------------|
| **CPU** | 2 cores | 4 cores |
| **RAM** | 4GB | 8GB |
| **Storage** | 50GB | 100GB+ SSD |
| **Network** | 1 Gbps | 1 Gbps |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS (recommended)
- **Kernel**: Linux kernel 4.15+
- **Container Runtime**: containerd 1.6+
- **Network**: Static IP addresses for all nodes

### Network Configuration

| Node | IP Address | Role |
|------|------------|------|
| k8s-master-1 | 192.168.1.111 | Control Plane + Worker |
| k8s-master-2 | 192.168.1.112 | Control Plane + Worker |
| k8s-master-3 | 192.168.1.113 | Control Plane + Worker |

### Required Ports

| Port Range | Protocol | Purpose |
|------------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 2379-2380 | TCP | etcd server client API |
| 10250 | TCP | Kubelet API |
| 10259 | TCP | kube-scheduler |
| 10257 | TCP | kube-controller-manager |
| 30000-32767 | TCP | NodePort Services |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes HA Cluster                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Control Plane                            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   Master 1  │  │   Master 2  │  │   Master 3  │     │ │
│  │  │             │  │             │  │             │     │ │
│  │  │ kube-api    │  │ kube-api    │  │ kube-api    │     │ │
│  │  │ etcd        │  │ etcd        │  │ etcd        │     │ │
│  │  │ scheduler   │  │ scheduler   │  │ scheduler   │     │ │
│  │  │ controller  │  │ controller  │  │ controller  │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                │                            │
│                                ▼                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Worker Nodes                            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   kubelet   │  │   kubelet   │  │   kubelet   │     │ │
│  │  │ kube-proxy  │  │ kube-proxy  │  │ kube-proxy  │     │ │
│  │  │ containerd  │  │ containerd  │  │ containerd  │     │ │
│  │  │             │  │             │  │             │     │ │
│  │  │    Pods     │  │    Pods     │  │    Pods     │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                     Networking                          │ │
│  │         CNI Plugin (Calico/Flannel/Cilium)             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## System Preparation

### Step 1: Disable Swap (Critical)

**Why disable swap?**
- **kubelet requirement**: Kubernetes kubelet refuses to start with swap enabled
- **Performance**: Swap causes unpredictable container performance
- **Memory management**: K8s needs precise memory allocation control
- **OOM behavior**: K8s prefers pods to be killed rather than swapped
- **Resource limits**: Pod memory limits don't work correctly with swap
- **Scheduling issues**: K8s scheduler doesn't consider swap in capacity
- **Security**: Memory contents can leak to disk

```bash
# Check current swap status
free -h
swapon --show

# Disable swap temporarily
sudo swapoff -a

# Disable swap permanently
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

# Verify swap is disabled
free -h          # Should show 0 swap
swapon --show    # Should show nothing
```

### Step 2: Configure Kernel Modules

Create containerd configuration:

```bash
# Create module configuration
sudo tee /etc/modules-load.d/containerd.conf > /dev/null <<EOF
overlay
br_netfilter
EOF

# Load modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter

# Verify modules are loaded
lsmod | grep overlay
lsmod | grep br_netfilter
```

**Module purposes:**
- **overlay**: OverlayFS for efficient container layering
- **br_netfilter**: Bridge netfilter for iptables to process bridge traffic

### Step 3: Configure Network Settings

```bash
# Create network configuration
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply configuration
sudo sysctl --system

# Verify settings
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

**Network settings explanation:**
- **bridge-nf-call-iptables**: Enable iptables for bridge traffic (required for CNI)
- **bridge-nf-call-ip6tables**: Enable ip6tables for bridge traffic
- **ip_forward**: Enable IP forwarding for pod-to-pod communication

### Step 4: Install Required Packages

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    curl \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release

# Set timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

---

## Container Runtime Setup

### Step 1: Install containerd

```bash
# Add Docker repository (for containerd)
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
sudo apt update
sudo apt install -y containerd.io

# Verify installation
containerd --version
```

### Step 2: Configure containerd

```bash
# Create default configuration
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Configure systemd cgroup driver (important for K8s)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Enable and start containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify containerd is running
sudo systemctl status containerd
```

**Configuration notes:**
- **SystemdCgroup = true**: Use systemd as cgroup driver (K8s recommendation)
- **Default config**: Provides optimal settings for Kubernetes workloads

---

## Kubernetes Installation

### Step 1: Add Kubernetes Repository

```bash
# Add Kubernetes signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### Step 2: Install Kubernetes Components

```bash
# Update package list
sudo apt update

# Install K8s components
sudo apt install -y kubelet kubeadm kubectl

# Hold packages to prevent auto-upgrade
sudo apt-mark hold kubelet kubeadm kubectl

# Verify installation
kubelet --version
kubeadm version
kubectl version --client
```

**Component roles:**
- **kubelet**: K8s node agent, manages pods and containers
- **kubeadm**: Cluster bootstrap tool
- **kubectl**: Command-line interface for K8s API

---

## Cluster Initialization

### Step 1: Initialize First Master Node

On the first master node (192.168.1.111):

```bash
# Initialize cluster with HA endpoint
sudo kubeadm init \
    --control-plane-endpoint "192.168.1.111:6443" \
    --upload-certs \
    --pod-network-cidr=10.244.0.0/16

# Save the output - you'll need:
# - kubeadm join command for additional masters
# - kubeadm join command for workers
# - certificate key for control plane nodes
```

### Step 2: Configure kubectl for Admin User

```bash
# Create kubectl config directory
mkdir -p $HOME/.kube

# Copy admin configuration
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify cluster access
kubectl get nodes
kubectl get pods -n kube-system
```

### Step 3: Install CNI Plugin (Calico)

```bash
# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

# Verify Calico pods
kubectl get pods -n kube-system | grep calico

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
```

---

## High Availability Setup

### Step 1: Join Additional Master Nodes

On each additional master node (192.168.1.112, 192.168.1.113):

```bash
# Join cluster as control plane (use output from kubeadm init)
sudo kubeadm join 192.168.1.111:6443 \
    --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH> \
    --control-plane \
    --certificate-key <CERTIFICATE_KEY>

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 2: Enable Workload Scheduling on Masters

```bash
# Remove NoSchedule taint from all master nodes
kubectl taint nodes k8s-master-1 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes k8s-master-2 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes k8s-master-3 node-role.kubernetes.io/control-plane:NoSchedule-

# Verify taints are removed
kubectl describe nodes | grep -i taint
```

### Step 3: Configure Load Balancer (Optional)

For production environments, consider using an external load balancer:

```yaml
# Example HAProxy configuration
frontend k8s-api
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    option tcp-check
    server master1 192.168.1.111:6443 check fall 3 rise 2
    server master2 192.168.1.112:6443 check fall 3 rise 2
    server master3 192.168.1.113:6443 check fall 3 rise 2
```

---

## Network Configuration

### Step 1: Firewall Configuration

```bash
# Allow required ports
sudo ufw allow 6443/tcp        # K8s API server
sudo ufw allow 2379:2380/tcp   # etcd
sudo ufw allow 10250/tcp       # kubelet API
sudo ufw allow 10259/tcp       # kube-scheduler
sudo ufw allow 10257/tcp       # kube-controller-manager
sudo ufw allow 30000:32767/tcp # NodePort services

# Allow internal cluster communication
sudo ufw allow from 192.168.1.0/24 to any port 22
sudo ufw allow from 10.244.0.0/16   # Pod network
sudo ufw allow from 10.96.0.0/12    # Service network
```

### Step 2: DNS Configuration

```bash
# Verify CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Step 3: Network Policies (Optional)

```yaml
# Example network policy for namespace isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## Cluster Validation

### Step 1: Node Status Check

```bash
# Check all nodes are ready
kubectl get nodes -o wide

# Check node resource usage
kubectl top nodes

# Verify node labels
kubectl get nodes --show-labels
```

### Step 2: System Pod Health

```bash
# Check system pods
kubectl get pods -n kube-system

# Check pod logs if any issues
kubectl logs -n kube-system <pod-name>

# Check component status
kubectl get componentstatuses
```

### Step 3: Cluster Info

```bash
# Get cluster information
kubectl cluster-info

# Check cluster configuration
kubectl config view

# Verify API server health
curl -k https://192.168.1.111:6443/healthz
```

### Step 4: Test Workload Deployment

```bash
# Create test deployment
kubectl create deployment nginx --image=nginx

# Expose deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Test access
curl http://192.168.1.111:$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')

# Cleanup test resources
kubectl delete deployment nginx
kubectl delete service nginx
```

---

## Troubleshooting

### Common Issues

#### 1. kubelet Not Starting

```bash
# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -f

# Common fixes:
# - Ensure swap is disabled
# - Check containerd is running
# - Verify network configuration
```

#### 2. Pods Stuck in Pending

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

#### 3. CNI Issues

```bash
# Check CNI pods
kubectl get pods -n kube-system | grep calico

# Check CNI logs
kubectl logs -n kube-system <calico-pod>

# Restart CNI if needed
kubectl delete pod -n kube-system <calico-pod>
```

#### 4. Certificate Issues

```bash
# Check certificate expiration
sudo kubeadm certs check-expiration

# Renew certificates
sudo kubeadm certs renew all

# Restart kubelet after renewal
sudo systemctl restart kubelet
```

### Cluster Reset (When Needed)

```bash
# Reset cluster completely
sudo kubeadm reset -f

# Clean up additional files
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/kubernetes/manifests/*
sudo rm -rf $HOME/.kube/config

# Remove CNI configuration
sudo rm -rf /etc/cni/net.d

# Restart containerd
sudo systemctl restart containerd
```

---

## Integration with Other Services

### Step 1: Persistent Storage

```yaml
# Example local storage class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

### Step 2: Monitoring Integration

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics
kubectl top nodes
kubectl top pods
```

### Step 3: Container Registry Integration

```bash
# Create registry secret
kubectl create secret docker-registry harbor-secret \
    --docker-server=registry.ngtantai.pro \
    --docker-username=admin \
    --docker-password=Harbor12345 \
    --docker-email=admin@company.com

# Use in deployment
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "harbor-secret"}]}'
```

---

## Next Steps

After successful cluster setup:

1. **Install Management Tools**: Set up Rancher, Lens, or k9s
2. **Configure RBAC**: Implement proper access controls
3. **Set up CI/CD**: Integrate with Jenkins or GitLab CI
4. **Install Ingress Controller**: For HTTP/HTTPS routing
5. **Configure Monitoring**: Deploy Prometheus and Grafana
6. **Backup Strategy**: Implement etcd backup procedures

For more advanced topics, refer to:
- [Kubernetes Concepts](kubernetes-concepts.md)
- [Workload Management](workloads.md)
- [Management Tools](management-tools.md)
- [CI/CD Integration](cicd-integration.md)

---

## Conclusion

This Kubernetes cluster setup provides a robust, highly available foundation for container orchestration. The 3-master configuration ensures no single point of failure while maintaining the ability to run workloads on all nodes for maximum resource utilization.

Regular maintenance, monitoring, and security updates are essential for maintaining a healthy cluster. The modular setup allows for easy scaling and integration with additional services as your infrastructure grows. 