# Ingress và Mạng trong Kubernetes

## Mục Lục
1. [Tổng quan Ingress](#ingress-overview)
2. [Cài đặt Ingress Controller](#ingress-controller-setup)
3. [Cấu hình Ingress](#ingress-configuration)
4. [Cấu hình TLS/SSL](#tlsssl-configuration)
5. [Mạng nâng cao](#advanced-networking)
6. [Chính sách mạng](#network-policies)
7. [Cân bằng tải](#load-balancing)
8. [Khắc phục sự cố](#troubleshooting)

## Tổng quan Ingress

### Ingress là gì?
Ingress cho phép truy cập HTTP/HTTPS từ bên ngoài vào các dịch vụ trong cụm. Việc định tuyến được kiểm soát bởi các rule trong tài nguyên Ingress.

### Thành phần chính
- **Ingress Controller**: Xử lý rule Ingress và cấu hình load balancer
- **Ingress Resource**: Định nghĩa rule định tuyến
- **Backend Services**: Dịch vụ đích nhận lưu lượng

## Cài đặt Ingress Controller

### Cài đặt NGINX Ingress Controller

```bash
# Thêm repo Helm NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Cài đặt NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.metrics.enabled=true \
  --set controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set controller.podAnnotations."prometheus\.io/port"="10254"

# Kiểm tra
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx
```

### Cấu hình truy cập ngoài

```bash
# Đối với môi trường on-premise, cấu hình NodePort
kubectl patch service ingress-nginx-controller \
  -n ingress-nginx \
  -p '{"spec":{"ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":"http","nodePort":30080}]}}'

kubectl patch service ingress-nginx-controller \
  -n ingress-nginx \
  -p '{"spec":{"ports":[{"name":"https","port":443,"protocol":"TCP","targetPort":"https","nodePort":30443}]}}'
```

## Cấu hình Ingress

### Ingress cơ bản

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

### Ingress nhiều host

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
  namespace: personal
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
  rules:
    - host: portfolio.ngtantai.pro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portfolio-service
                port:
                  number: 80
    - host: curriculum-vitae.ngtantai.pro
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: curriculum-vitae-service
                port:
                  number: 80
```

### Định tuyến theo đường dẫn

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /api/v1(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: api-v1-service
                port:
                  number: 8080
          - path: /api/v2(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: api-v2-service
                port:
                  number: 8080
```

## Cấu hình TLS/SSL

### Quản lý chứng chỉ với cert-manager

```bash
# Cài cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Tạo ClusterIssuer cho Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Ingress có TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - secure.example.com
      secretName: example-tls
  rules:
    - host: secure.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: secure-service
                port:
                  number: 80
```

## Mạng nâng cao

### Annotation phổ biến

```yaml
annotations:
  # Cấu hình cơ bản
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  # SSL
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  # Giới hạn tốc độ
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/rate-limit-rps: "10"
  # Xác thực
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  # CORS
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
```

### Backend tùy chỉnh

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-backend-ingress
  annotations:
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/affinity-mode: "persistent"
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 8080
```

## Chính sách mạng

### Network Policy cơ bản

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

### Cho phép traffic cụ thể

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Cân bằng tải

### Session Affinity

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sticky-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 8080
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

### Weighted Load Balancing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: weighted-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "30"
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-v2-service
                port:
                  number: 80
```

## Khắc phục sự cố

### Vấn đề thường gặp

#### 1. Ingress không truy cập được
```bash
# Kiểm tra trạng thái ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
# Kiểm tra ingress resource
kubectl describe ingress your-ingress-name
kubectl get ingress -A
```

#### 2. Lỗi backend service
```bash
# Kiểm tra endpoint service
kubectl get endpoints your-service-name
kubectl describe service your-service-name
# Test kết nối
kubectl run test-pod --image=nginx --rm -it -- /bin/bash
curl http://your-service-name.namespace.svc.cluster.local
```

#### 3. Lỗi DNS
```bash
# Kiểm tra cấu hình DNS
kubectl get configmap coredns -n kube-system -o yaml
# Test DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
```

### Lệnh debug

```bash
# Xem log ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
# Xem event
kubectl get events --sort-by='.lastTimestamp'
# Xem cấu hình ingress
kubectl get ingress -o yaml
# Test kết nối
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### Tối ưu hiệu năng

#### 1. Bật nén
```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-compression: "true"
  nginx.ingress.kubernetes.io/compression-types: "text/plain,text/css,application/json,application/javascript,text/xml,application/xml"
```

#### 2. Connection Pooling
```yaml
annotations:
  nginx.ingress.kubernetes.io/upstream-keepalive-connections: "64"
  nginx.ingress.kubernetes.io/upstream-keepalive-requests: "100"
  nginx.ingress.kubernetes.io/upstream-keepalive-timeout: "60"
```

#### 3. Caching
```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-buffering: "on"
  nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
  nginx.ingress.kubernetes.io/proxy-buffers-number: "8"
```

## Thực hành tốt

1. **Đặt tên ý nghĩa** cho ingress
2. **Bật TLS** cho dịch vụ ngoài
3. **Giới hạn tốc độ** để chống abuse
4. **Áp dụng network policy** để bảo mật
5. **Giám sát metric ingress**
6. **Test cấu hình ở môi trường staging trước**
7. **Ghi chú rõ rule định tuyến**
8. **Dùng annotation phù hợp cho từng yêu cầu**

## Bảo mật

1. **Bật SSL/TLS** cho mọi ingress
2. **Dùng xác thực phù hợp**
3. **Giới hạn tốc độ, chống DDoS**
4. **Áp dụng network policy**
5. **Cập nhật ingress controller thường xuyên**
6. **Theo dõi log truy cập**

## Tích hợp Harbor Registry

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-deployment
  namespace: personal
spec:
  template:
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: portfolio
        image: harbor.ngtantai.pro/personal/portfolio:latest
        ports:
        - containerPort: 80
```

Hướng dẫn này bao quát toàn bộ cấu hình ingress và mạng cho hệ thống Kubernetes on-premise. 