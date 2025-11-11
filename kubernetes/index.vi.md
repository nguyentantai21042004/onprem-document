# Hướng Dẫn Triển Khai Kubernetes

## 📋 Tổng Quan

Phần này cung cấp tài liệu toàn diện về cách triển khai một cụm Kubernetes sẵn sàng cho môi trường sản xuất trên hạ tầng tại chỗ của bạn. Các hướng dẫn được tổ chức theo trình tự logic từ thiết lập cơ bản đến quản lý nâng cao.

## 🏗️ Tổng Quan Kiến Trúc

```
┌──────────────────────────────────────────────────────────────┐
│                    Cụm Kubernetes                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Master 1   │  │   Master 2   │  │   Master 3   │       │
│  │192.168.1.111 │  │192.168.1.112 │  │192.168.1.113 │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Worker 1    │  │  Worker 2    │  │  Worker 3    │       │
│  │192.168.1.121 │  │192.168.1.122 │  │192.168.1.123 │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  Lớp Lưu Trữ                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │ Local SSD  │  │ NFS Storage│  │ iSCSI SAN  │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                Lớp Quản Lý                          │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │  Rancher   │  │  Ingress   │  │ Monitoring │     │   │
│  │  │   (GUI)    │  │ Controller │  │   Stack    │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## 📚 Cấu Trúc Tài Liệu

### 1. [Thiết Lập Cụm](cluster-setup.md)
**Lớp Nền Tảng - Bắt Đầu Từ Đây**
- ✅ Chuẩn bị hệ thống và yêu cầu
- ✅ Cài đặt container runtime (containerd)
- ✅ Cài đặt Kubernetes với kubeadm
- ✅ Cấu hình High Availability (3 master)
- ✅ Thiết lập mạng và cấu hình CNI
- ✅ Kiểm tra và xác thực cụm

**Yêu cầu tiên quyết**: Hoàn thành phần [01-Hạ tầng](../01-infrastructure/index.md)

### 2. [Các Khái Niệm Kubernetes](kubernetes-concepts.md)
**Lớp Kiến Thức - Hiểu Biết Cốt Lõi**
- ✅ Kiến thức cơ bản về cấu hình YAML
- ✅ Cấu trúc và quản lý tài nguyên
- ✅ Namespace và tổ chức tài nguyên
- ✅ Labels, selectors, annotations
- ✅ Quản lý cấu hình cơ bản
- ✅ Thực hành và mẫu tốt nhất

**Yêu cầu tiên quyết**: Đã thiết lập cụm cơ bản

### 3. [Quản Lý Workloads](workloads.md)
**Lớp Ứng Dụng - Mô Hình Triển Khai**
- ✅ Chiến lược triển khai và cập nhật rolling
- ✅ Các loại Service và cân bằng tải
- ✅ ConfigMap và cấu hình ứng dụng
- ✅ Quản lý Secrets và bảo mật
- ✅ Kiểm tra sức khỏe và giám sát
- ✅ Quản lý mở rộng và tài nguyên

**Yêu cầu tiên quyết**: Hiểu các khái niệm Kubernetes

### 4. [Ingress & Mạng](ingress-networking.md)
**Lớp Mạng - Truy Cập Từ Bên Ngoài**
- ✅ Cài đặt ingress controller (NGINX)
- ✅ Cấu hình DNS và domain
- ✅ Quản lý chứng chỉ SSL/TLS
- ✅ Chiến lược cân bằng tải
- ✅ Chính sách mạng và bảo mật
- ✅ Định tuyến nhiều host và theo đường dẫn

**Yêu cầu tiên quyết**: Hiểu về workloads

### 5. [Lưu Trữ & Tính Bền Vững](storage-persistence.md)
**Lớp Dữ Liệu - Lưu Trữ Bền Vững**
- ✅ Persistent Volumes và Claims
- ✅ Storage class và provisioning
- ✅ ConfigMap và dữ liệu cấu hình
- ✅ Secrets và dữ liệu nhạy cảm
- ✅ Chiến lược backup và khôi phục
- ✅ Tối ưu hiệu năng

**Yêu cầu tiên quyết**: Đã triển khai workload cơ bản

### 6. [Quản Lý Rancher](rancher-management.md)
**Lớp Quản Lý - Thao Tác Giao Diện**
- ✅ Cài đặt Rancher server
- ✅ Quản lý nhiều cụm
- ✅ Xác thực người dùng và RBAC
- ✅ Tổ chức project và namespace
- ✅ Thiết lập giám sát và cảnh báo
- ✅ Thực hành vận hành tốt

**Yêu cầu tiên quyết**: Cụm Kubernetes đã hoạt động

## 🏆 Lộ Trình Học Tập

### Lộ trình 1: Khởi Động Nhanh (Cơ Bản)
1. **Thiết lập** → [cluster-setup.md](cluster-setup.md) - Khởi động cụm
2. **Triển khai** → [workloads.md](workloads.md) - Triển khai ứng dụng đầu tiên
3. **Công khai** → [ingress-networking.md](ingress-networking.md) - Mở truy cập từ ngoài
4. **Lưu trữ** → [storage-persistence.md](storage-persistence.md) - Thêm lưu trữ bền vững

**Ước lượng thời gian**: 1-2 ngày
**Trình độ**: Mới bắt đầu đến trung cấp

### Lộ trình 2: Sản Xuất (Toàn Diện)
1. **Nền tảng** → [cluster-setup.md](cluster-setup.md) - Thiết lập HA
2. **Khái niệm** → [kubernetes-concepts.md](kubernetes-concepts.md) - Hiểu sâu
3. **Ứng dụng** → [workloads.md](workloads.md) - Triển khai nâng cao
4. **Mạng** → [ingress-networking.md](ingress-networking.md) - Định tuyến phức tạp
5. **Lưu trữ** → [storage-persistence.md](storage-persistence.md) - Lưu trữ doanh nghiệp
6. **Quản lý** → [rancher-management.md](rancher-management.md) - Thao tác giao diện

**Ước lượng thời gian**: 3-5 ngày
**Trình độ**: Trung cấp đến nâng cao

### Lộ trình 3: DevOps (Tự Động Hóa)
1. **Tự động hóa** → [cluster-setup.md](cluster-setup.md) - Thiết lập bằng script
2. **CI/CD** → [workloads.md](workloads.md) - Tự động triển khai
3. **Giám sát** → [rancher-management.md](rancher-management.md) - Quan sát hệ thống
4. **Bảo mật** → [storage-persistence.md](storage-persistence.md) - Quản lý secrets

**Ước lượng thời gian**: 2-3 ngày
**Trình độ**: Nâng cao

## 🚀 Tham Khảo Nhanh

### Lệnh Cơ Bản
```bash
# Quản lý cụm
kubectl get nodes
kubectl get pods -A
kubectl get services -A

# Triển khai ứng dụng
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl describe deployment app-name

# Mạng
kubectl get ingress
kubectl get services
kubectl port-forward service/app-service 8080:80

# Lưu trữ
kubectl get pv,pvc
kubectl describe pvc claim-name
kubectl get storageclass

# Khắc phục sự cố
kubectl describe pod pod-name
kubectl logs pod-name
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Ví Dụ Cấu Hình
```yaml
# Triển khai cơ bản
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - host: nginx.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

## 🔧 Mẫu Cấu Hình

### Mẫu Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    tier: application
```

### Mẫu Resource Quota
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    persistentvolumeclaims: "10"
```

### Mẫu Network Policy
```yaml
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

## 🏅 Danh Sách Kiểm Tra

### Sức Khỏe Cụm
- [ ] Tất cả node ở trạng thái Ready
- [ ] Tất cả pod hệ thống đang Running
- [ ] Mạng cụm hoạt động bình thường
- [ ] DNS hoạt động
- [ ] Storage class sẵn sàng

### Triển Khai Ứng Dụng
- [ ] Deployment khỏe mạnh
- [ ] Service truy cập được
- [ ] Ingress định tuyến đúng
- [ ] Chứng chỉ SSL hợp lệ
- [ ] Lưu trữ bền vững được mount

### Bảo Mật
- [ ] Đã cấu hình RBAC
- [ ] Đã áp dụng network policy
- [ ] Secrets được mã hóa
- [ ] Chính sách bảo mật pod được áp dụng
- [ ] Đã bật audit logging

### Giám Sát
- [ ] Đã thu thập metrics
- [ ] Đã tập trung log
- [ ] Đã cấu hình cảnh báo
- [ ] Dashboard truy cập được
- [ ] Health check hoạt động

## 🔗 Tích Hợp

### Với Lớp Hạ Tầng
- Cấu hình mạng từ [01-Hạ tầng](../01-infrastructure/index.md)
- Thiết lập lưu trữ từ hướng dẫn hạ tầng
- Chứng chỉ và khóa bảo mật

### Với Lớp Dịch Vụ
- Tích hợp Harbor registry cho image
- MongoDB, PostgreSQL cho dữ liệu ứng dụng
- Prometheus, Grafana cho giám sát

### Với Lớp CI/CD
- Tích hợp Jenkins cho tự động triển khai
- GitOps cho quản lý cấu hình
- Pipeline tích hợp Harbor registry

## 📈 Tối Ưu Hiệu Năng

### Quản Lý Tài Nguyên
- Đặt requests và limits hợp lý
- Sử dụng autoscaling cho pod
- Cấu hình autoscaling cho cụm
- Giám sát sử dụng tài nguyên

### Tối Ưu Lưu Trữ
- Chọn storage class phù hợp
- Thực hiện backup đúng cách
- Giám sát hiệu năng lưu trữ
- Lên kế hoạch mở rộng lưu trữ

### Tối Ưu Mạng
- Cấu hình ingress tối ưu định tuyến
- Sử dụng connection pooling
- Cân bằng tải hợp lý
- Giám sát hiệu năng mạng

## 🔒 Thực Hành Bảo Mật

### Kiểm Soát Truy Cập
- Áp dụng RBAC
- Sử dụng service account hợp lý
- Cấu hình pod security policy
- Kiểm tra bảo mật định kỳ

### Bảo Vệ Dữ Liệu
- Dùng secrets cho dữ liệu nhạy cảm
- Mã hóa dữ liệu khi lưu trữ
- Bảo mật giao tiếp giữa các dịch vụ
- Thường xuyên kiểm tra backup/khôi phục

### Bảo Mật Mạng
- Áp dụng network policy
- Dùng ingress với TLS
- Cấu hình firewall hợp lý
- Giám sát lưu lượng mạng

## ☎️ Hỗ Trợ & Khắc Phục Sự Cố

### Vấn Đề Thường Gặp
- Lỗi lên lịch pod
- Lỗi phát hiện dịch vụ
- Lỗi mount lưu trữ
- Lỗi kết nối mạng
- Hết hạn chứng chỉ

### Công Cụ Gỡ Rối
- `kubectl describe` để xem chi tiết tài nguyên
- `kubectl logs` để xem log ứng dụng
- `kubectl events` để xem sự kiện cụm
- Rancher UI để debug trực quan
- Prometheus để giám sát

## 🎯 Bước Tiếp Theo

Sau khi hoàn thành phần Kubernetes, hãy tiếp tục:
1. **[04-CI/CD](../04-cicd/index.md)** - Thiết lập pipeline tự động triển khai
2. **[05-Monitoring](../05-monitoring/index.md)** - Giám sát và cảnh báo nâng cao
3. **[06-Security](../06-security/index.md)** - Tăng cường bảo mật và tuân thủ

---

**Lưu ý**: Kubernetes là một hệ thống phức tạp. Hãy bắt đầu từ cơ bản, hiểu rõ các khái niệm, sau đó dần dần tiếp cận các tính năng nâng cao. Sử dụng các công cụ giao diện như Rancher để hiểu cấu hình, sau đó trích xuất và chuẩn hóa các mẫu YAML cho môi trường sản xuất.

**Triết lý**: Giao diện → Hiểu → YAML → Tự động hóa → Sản xuất 