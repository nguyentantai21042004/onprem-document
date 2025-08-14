sudo apt update -y && sudo apt upgrade -y

# Tắt swap
sudo swapoff -a
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

# Cấu hình module kernel cho containerd
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/containerd.conf

# Tải module kernel
sudo modprobe overlay
sudo modprobe br_netfilter

# Cấu hình hệ thống mạng cho Kubernetes
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee /etc/sysctl.d/kubernetes.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf

# Áp dụng cấu hình sysctl
sudo sysctl --system

# Cài đặt các gói cần thiết và thêm kho Docker
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo mkdir -p /etc/apt/trusted.gpg.d
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Cài đặt containerd
sudo apt update -y
sudo apt install -y containerd.io

# Cấu hình containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Khởi động containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Thêm kho lưu trữ Kubernetes
sudo mkdir -p /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Cài đặt các gói Kubernetes
sudo apt update -y
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo kubeadm init --control-plane-endpoint "172.16.21.31:6443" --upload-certs

mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
sed -i '/CALICO_IPV4POOL_CIDR/{
N
s|# - name: CALICO_IPV4POOL_CIDR\n#   value: "192.168.0.0/16"|            - name: CALICO_IPV4POOL_CIDR\n              value: "21.19.0.0/16"|
}' calico.yaml

kubectl apply -f calico.yaml