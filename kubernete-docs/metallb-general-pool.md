# MetalLB General Pool Configuration

## Giới thiệu
File này chứa cấu hình MetalLB để cung cấp Load Balancer cho Kubernetes cluster trong môi trường bare-metal hoặc on-premise.

## Cấu hình YAML

```yaml
# metallb-general-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: general-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.16.21.200-172.16.21.230
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: general-advertise
  namespace: metallb-system
spec:
  ipAddressPools:
  - general-pool
```

## Giải thích cấu hình

### 1. IPAddressPool
- **apiVersion**: `metallb.io/v1beta1` - Phiên bản API của MetalLB
- **kind**: `IPAddressPool` - Định nghĩa một pool IP addresses
- **metadata**:
  - **name**: `general-pool` - Tên của IP pool
  - **namespace**: `metallb-system` - Namespace chứa MetalLB
- **spec**:
  - **addresses**: `172.16.21.200-172.16.21.230` - Dải IP từ 172.16.21.200 đến 172.16.21.230 (31 IP addresses)
  - **autoAssign**: `true` - Tự động gán IP từ pool này cho các LoadBalancer services

### 2. L2Advertisement
- **apiVersion**: `metallb.io/v1beta1` - Phiên bản API của MetalLB
- **kind**: `L2Advertisement` - Cấu hình quảng bá Layer 2
- **metadata**:
  - **name**: `general-advertise` - Tên của advertisement
  - **namespace**: `metallb-system` - Namespace chứa MetalLB
- **spec**:
  - **ipAddressPools**: `general-pool` - Liên kết với IP pool đã định nghĩa ở trên

## Cách hoạt động

1. **IP Pool**: MetalLB sẽ quản lý dải IP từ 172.16.21.200 đến 172.16.21.230
2. **Auto Assignment**: Khi có LoadBalancer service được tạo, MetalLB tự động gán một IP từ pool này
3. **L2 Advertisement**: MetalLB sử dụng giao thức ARP (Layer 2) để quảng bá các IP này trong mạng local

## Triển khai

Để áp dụng cấu hình này:

```bash
kubectl apply -f metallb-general-pool.yaml
```

## Kiểm tra trạng thái

```bash
# Kiểm tra IP pools
kubectl get ipaddresspool -n metallb-system

# Kiểm tra L2 advertisements
kubectl get l2advertisement -n metallb-system

# Kiểm tra các LoadBalancer services
kubectl get svc --all-namespaces -o wide | grep LoadBalancer
```

## Lưu ý
- Đảm bảo dải IP 172.16.21.200-172.16.21.230 không bị sử dụng bởi các thiết bị khác trong mạng
- MetalLB cần được cài đặt trước khi áp dụng cấu hình này
- Chỉ áp dụng cho môi trường bare-metal hoặc on-premise, không dùng cho cloud providers