# Hướng Dẫn Thiết Lập Cụm Kubernetes

## Mục Lục

- [Giới thiệu](#introduction)
- [Yêu cầu tiên quyết](#prerequisites)
- [Tổng quan kiến trúc](#architecture-overview)
- [Chuẩn bị hệ thống](#system-preparation)
- [Cài đặt container runtime](#container-runtime-setup)
- [Cài đặt Kubernetes](#kubernetes-installation)
- [Khởi tạo cụm](#cluster-initialization)
- [Thiết lập High Availability](#high-availability-setup)
- [Cấu hình mạng](#network-configuration)
- [Xác thực cụm](#cluster-validation)
- [Khắc phục sự cố](#troubleshooting)
- [Tích hợp với dịch vụ khác](#integration-with-other-services)

---

## Giới thiệu

Hướng dẫn này cung cấp chỉ dẫn chi tiết để thiết lập một cụm Kubernetes sẵn sàng cho môi trường sản xuất với cấu hình High Availability (HA). Thiết lập bao gồm 3 node master vừa làm control plane vừa làm worker, đảm bảo tính sẵn sàng tối đa và tận dụng tài nguyên.

### So sánh K8s và K3s

| Tính năng | K8s (Kubernetes đầy đủ) | K3s (Kubernetes nhẹ) |
|----------|-------------------------|---------------------|
| **Mục đích** | Môi trường sản xuất | Edge, IoT |
| **Tài nguyên** | Cao (đầy đủ tính năng) | Thấp (tối giản) |
| **Thành phần** | Đầy đủ | Tối giản |
| **Tùy biến** | Linh hoạt | Hạn chế |
| **Phù hợp** | Doanh nghiệp | Phát triển, nhỏ |

### Các mô hình kiến trúc cụm

#### Cụm cơ bản (Không khuyến nghị cho sản xuất)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Master Node   │    │  Worker Node 1  │    │  Worker Node 2  │
│ (Control Plane) │    │ (App Workload)  │    │ (App Workload)  │
│  No Workloads   │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Cụm HA (Khuyến nghị)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Master Node 1   │    │ Master Node 2   │    │ Master Node 3   │
│ Control Plane + │    │ Control Plane + │    │ Control Plane + │
│   Workloads     │    │   Workloads     │    │   Workloads     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## Yêu cầu tiên quyết

### Yêu cầu phần cứng

| Thành phần | Tối thiểu/node | Khuyến nghị/node |
|------------|----------------|------------------|
| **CPU**    | 2 nhân         | 4 nhân           |
| **RAM**    | 4GB            | 8GB              |
| **Lưu trữ**| 50GB           | 100GB+ SSD       |
| **Mạng**   | 1 Gbps         | 1 Gbps           |

### Yêu cầu phần mềm

- **OS**: Ubuntu 22.04 LTS (khuyến nghị)
- **Kernel**: Linux kernel 4.15+
- **Container Runtime**: containerd 1.6+
- **Mạng**: IP tĩnh cho tất cả node

### Cấu hình mạng

| Node         | Địa chỉ IP     | Vai trò                  |
|--------------|---------------|--------------------------|
| k8s-master-1 | 192.168.1.111 | Control Plane + Worker   |
| k8s-master-2 | 192.168.1.112 | Control Plane + Worker   |
| k8s-master-3 | 192.168.1.113 | Control Plane + Worker   |

### Các cổng cần thiết

| Khoảng cổng   | Giao thức | Mục đích                  |
|--------------|-----------|---------------------------|
| 6443         | TCP       | Kubernetes API server     |
| 2379-2380    | TCP       | etcd server client API    |
| 10250        | TCP       | Kubelet API               |
| 10259        | TCP       | kube-scheduler            |
| 10257        | TCP       | kube-controller-manager   |
| 30000-32767  | TCP       | NodePort Services         |

---

## Tổng quan kiến trúc

```
┌──────────────────────────────────────────────────────────────┐
│                Cụm Kubernetes HA                            │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                Control Plane                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │   Master 1   │  │   Master 2   │  │   Master 3   │  │  │
│  │  │ kube-api     │  │ kube-api     │  │ kube-api     │  │  │
│  │  │ etcd         │  │ etcd         │  │ etcd         │  │  │
│  │  │ scheduler    │  │ scheduler    │  │ scheduler    │  │  │
│  │  │ controller   │  │ controller   │  │ controller   │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                │                            │
│                                ▼                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                 Worker Nodes                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │   kubelet    │  │   kubelet    │  │   kubelet    │  │  │
│  │  │ kube-proxy   │  │ kube-proxy   │  │ kube-proxy   │  │  │
│  │  │ containerd   │  │ containerd   │  │ containerd   │  │  │
│  │  │    Pods      │  │    Pods      │  │    Pods      │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                     Mạng                              │  │
│  │         CNI Plugin (Calico/Flannel/Cilium)            │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## Chuẩn bị hệ thống

### Bước 1: Tắt swap (bắt buộc)

**Tại sao phải tắt swap?**
- **Yêu cầu của kubelet**: kubelet không chạy nếu swap bật
- **Hiệu năng**: Swap gây hiệu năng không ổn định
- **Quản lý bộ nhớ**: K8s cần kiểm soát bộ nhớ chính xác
- **Hành vi OOM**: K8s thích kill pod hơn là swap
- **Giới hạn tài nguyên**: Giới hạn bộ nhớ pod không đúng nếu có swap
- **Lên lịch**: Scheduler không tính swap
- **Bảo mật**: Dữ liệu bộ nhớ có thể ghi ra đĩa

```bash
# Kiểm tra trạng thái swap
free -h
swapon --show

# Tắt swap tạm thời
sudo swapoff -a

# Tắt swap vĩnh viễn
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

# Kiểm tra lại
free -h          # Phải là 0 swap
swapon --show    # Không có gì
```

### Bước 2: Cấu hình kernel modules

Tạo cấu hình cho containerd:

```bash
# Tạo file cấu hình module
sudo tee /etc/modules-load.d/containerd.conf > /dev/null <<EOF
overlay
br_netfilter
EOF

# Nạp module ngay
sudo modprobe overlay
sudo modprobe br_netfilter

# Kiểm tra
lsmod | grep overlay
lsmod | grep br_netfilter
```

**Ý nghĩa:**
- **overlay**: OverlayFS cho container
- **br_netfilter**: Cho phép iptables xử lý traffic bridge

### Bước 3: Cấu hình mạng

```bash
# Tạo cấu hình mạng
sudo tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Áp dụng cấu hình
sudo sysctl --system

# Kiểm tra
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

**Giải thích:**
- **bridge-nf-call-iptables**: Bắt buộc cho CNI
- **ip_forward**: Cho phép pod giao tiếp

### Bước 4: Cài đặt gói cần thiết

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói cơ bản
sudo apt install -y \
    curl \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release

# Đặt múi giờ
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

---

## Cài đặt container runtime

### Bước 1: Cài containerd

```bash
# Thêm repo Docker (cho containerd)
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Cài containerd
sudo apt update
sudo apt install -y containerd.io

# Kiểm tra
containerd --version
```

### Bước 2: Cấu hình containerd

```bash
# Tạo cấu hình mặc định
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Sử dụng systemd cgroup driver (bắt buộc cho K8s)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Khởi động lại containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Kiểm tra
sudo systemctl status containerd
```

**Lưu ý:**
- **SystemdCgroup = true**: Bắt buộc cho K8s
- **Cấu hình mặc định**: Tối ưu cho workload Kubernetes

---

## Cài đặt Kubernetes

### Bước 1: Thêm repo Kubernetes

```bash
# Thêm key ký
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Thêm repo
... 