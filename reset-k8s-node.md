# Reset kubeadm với force
sudo kubeadm reset -f

# Backup nếu cần thiết, sau đó xóa
sudo rm -rf /etc/cni/net.d

# Sử dụng kube-proxy container để cleanup
docker run --privileged --rm registry.k8s.io/kube-proxy:v1.33.0 sh -c "kube-proxy --cleanup && echo DONE"

# Hoặc manual cleanup iptables
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Kiểm tra nội dung trước khi xóa
ls -la $HOME/.kube/

# Backup nếu cần, sau đó xóa
rm -rf $HOME/.kube

# Xóa kubelet data
sudo rm -rf /var/lib/kubelet

# Xóa container runtime data
sudo docker system prune -af
sudo docker volume prune -f

# Hoặc nếu dùng containerd
sudo ctr -n k8s.io c rm $(sudo ctr -n k8s.io c ls -q) 2>/dev/null || true
sudo ctr -n k8s.io i rm $(sudo ctr -n k8s.io i ls -q) 2>/dev/null || true

# Restart services
sudo systemctl restart containerd  # hoặc docker
sudo systemctl restart kubelet

# Chỉ áp dụng cho control-plane nodes
yq eval -i '.spec.containers[0].command = []' /etc/kubernetes/manifests/kube-apiserver.yaml
timeout 60 sh -c 'while pgrep kube-apiserver >/dev/null; do sleep 1; done' || true