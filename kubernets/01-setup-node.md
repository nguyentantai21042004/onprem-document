# Hướng dẫn cài đặt Kubernetes Cluster HA (3 Master Nodes)

## Tổng quan

### K3s vs K8s
- **K3s**: Phiên bản nhỏ gọn của K8s, phù hợp cho edge computing và IoT
- **K8s**: Phiên bản đầy đủ cho production environment

### Kiến trúc Cluster
**Cụm K8s cơ bản:** 1 master (control plane - không triển khai dự án) + 2 worker nodes

**Cụm HA (High Availability):** 3 master nodes vừa làm control plane vừa làm worker nodes

---

## Bước 1: Tắt Swap

### Tại sao phải tắt swap?
- **kubelet yêu cầu:** K8s kubelet từ chối start nếu có swap enabled
- **Performance:** Swap làm chậm container, không predictable
- **Memory management:** K8s cần control chính xác memory allocation
- **OOM behavior:** K8s muốn pod bị kill khi hết RAM thay vì swap
- **Resource limits:** Pod memory limits không hoạt động đúng với swap
- **Scheduling issues:** K8s scheduler không tính swap vào capacity
- **Security:** Memory có thể bị leak ra disk

### Các lệnh thực hiện:

```bash
# Kiểm tra trạng thái swap
free -h
swapon --show

# Tắt swap tạm thời
sudo swapoff -a

# Tắt swap vĩnh viễn (comment dòng swap trong fstab)
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

# Kiểm tra lại
free -h  # Should show 0 swap
swapon --show  # Should show nothing
```

---

## Bước 2: Cấu hình Kernel Modules

### Tạo file config cho containerd:

```bash
sudo vi /etc/modules-load.d/containerd.conf
```

**Nội dung file:**
```
overlay
br_netfilter
```

### Load modules:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

### Ý nghĩa:
- **overlay:** OverlayFS để container layers hoạt động
- **br_netfilter:** Bridge netfilter để iptables có thể xử lý traffic qua Linux bridge

---

## Bước 3: Cấu hình Network

### Tạo file cấu hình network:

```bash
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

### Áp dụng cấu hình:

```bash
sudo sysctl --system
```

### Kiểm tra kết quả:
```
* Applying /etc/sysctl.d/kubernetes.conf ...
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

### Ý nghĩa:
- **bridge-nf-call-iptables:** Cho phép iptables xử lý traffic qua bridge (cần cho CNI)
- **ip_forward:** Enable IP forwarding để pods có thể communicate giữa các nodes

---

## Bước 4: Cài đặt Containerd

### Cài đặt các gói cần thiết:

```bash
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
```

### Thêm Docker repository:

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
```

### Cài đặt containerd:

```bash
sudo apt update -y
sudo apt install -y containerd.io
```

### Ý nghĩa:
containerd là container runtime mặc định của K8s (thay thế Docker). Chịu trách nhiệm pull images, chạy containers.

---

## Bước 5: Cấu hình Containerd

### Tạo config mặc định:

```bash
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
```

### Cấu hình systemd cgroup:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
```

### Khởi động containerd:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Ý nghĩa:
- Tạo config mặc định cho containerd
- **SystemdCgroup = true:** Sử dụng systemd làm cgroup driver (khuyến nghị cho K8s)

---

## Bước 6: Cài đặt Kubernetes

### Thêm Kubernetes repository:

```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

### Cài đặt các components K8s:

```bash
sudo apt update -y
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Ý nghĩa:
- **kubelet:** K8s agent chạy trên mỗi node, quản lý pods
- **kubeadm:** Tool để bootstrap K8s cluster
- **kubectl:** CLI để interact với K8s cluster
- **apt-mark hold:** Ngăn auto-update để tránh version conflicts

---

## Bước 7: Khởi tạo Cluster HA (3 Master Nodes)

### Trên node đầu tiên (k8s-master-1):

```bash
# Khởi tạo cluster với control-plane endpoint
sudo kubeadm init --control-plane-endpoint "192.168.1.111:6443" --upload-certs

# Cấu hình kubectl cho user
mkdir -p $HOME/.kube 
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Cài đặt Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
```

### Trên các node còn lại (k8s-master-2, k8s-master-3):

```bash
# Join cluster với quyền control-plane
sudo kubeadm join 192.168.1.111:6443 \
  --token your_token \
  --discovery-token-ca-cert-hash your_sha \
  --control-plane \
  --certificate-key your_cert

# Cấu hình kubectl cho user
mkdir -p $HOME/.kube 
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Cho phép schedule pods trên master nodes:

```bash
# Remove taint để có thể schedule workload lên master nodes
kubectl taint nodes k8s-master-1 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes k8s-master-2 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes k8s-master-3 node-role.kubernetes.io/control-plane:NoSchedule-
```

---

## Bước 8: Reset Cluster (khi cần)

### Lệnh reset hoàn toàn cluster:

```bash
sudo kubeadm reset -f
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/kubernetes/manifests/*
```

### Ý nghĩa:
Clean up hoàn toàn cluster khi muốn setup lại từ đầu.

---

## Tổng quan quy trình

### Mục tiêu:
Chuẩn bị môi trường để K8s cluster hoạt động ổn định với High Availability

### Luồng hoạt động:
1. **System prep:** Tắt swap, cấu hình kernel
2. **Network prep:** Enable IP forwarding, bridge filtering  
3. **Container runtime:** Cài containerd với systemd cgroup
4. **K8s components:** Cài kubelet, kubeadm, kubectl
5. **Cluster initialization:** Khởi tạo cluster HA với 3 master nodes
6. **Network plugin:** Cài đặt Calico CNI
7. **Workload scheduling:** Remove taint để schedule pods trên master nodes

### Kết quả:
Cluster K8s HA với 3 nodes vừa là master vừa là worker, có thể chạy workload và đảm bảo high availability.