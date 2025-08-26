
# Cập nhật hệ thống
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


# Khởi tạo Kubernetes Control Plane
sudo kubeadm init --control-plane-endpoint "172.16.21.31:6443" --upload-certs


# Cấu hình kubeconfig cho user
mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config


# Bỏ taint node control-plane để có thể chạy pod trên node này
kubectl taint nodes kubernete3 node-role.kubernetes.io/control-plane:NoSchedule-


# Cài đặt Calico CNI
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
sed -i '/CALICO_IPV4POOL_CIDR/{
N
s|# - name: CALICO_IPV4POOL_CIDR\n#   value: "192.168.0.0/16"|            - name: CALICO_IPV4POOL_CIDR\n              value: "21.19.0.0/16"|
}' calico.yaml

kubectl apply -f calico.yaml


# Cài đặt Helm
wget https://get.helm.sh/helm-v3.16.2-linux-amd64.tar.gz
tar xvf helm-v3.16.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/bin/
helm version


# Cài đặt ingress-nginx bằng Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm pull ingress-nginx/ingress-nginx
tar -xzf ingress-nginx-4.11.3.tgz
vi ingress-nginx/values.yaml
>> Sửa type: LoadBalancing => type: NodePort
>> Sửa nodePort http: "" => http: "30080"
>> Sửa nodePort https: "" => https: "30443"
kubectl create ns ingress-nginx
helm -n ingress-nginx install ingress-nginx -f ingress-nginx/values.yaml ingress-nginx