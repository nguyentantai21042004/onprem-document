# Kubernetes ConfigMap - Tổng quan và Hướng dẫn

## Tổng quan về ConfigMap

### Khái niệm cơ bản

**ConfigMap** là một Kubernetes object cho phép lưu trữ các thông tin cấu hình dưới dạng key-value pairs. Đây là công cụ quan trọng để tách biệt cấu hình khỏi container image, giúp ứng dụng trở nên linh hoạt hơn khi triển khai trên các môi trường khác nhau.

### Mục đích sử dụng

ConfigMap được thiết kế để lưu trữ:
- **Biến môi trường** (Environment Variables)
- **Tham số khởi động** (Startup Parameters)
- **File cấu hình** (Configuration Files)
- **Dữ liệu phi bảo mật** (Non-sensitive Data)

---

## Đặc điểm chính của ConfigMap

### 1. Lưu trữ dữ liệu

- **Định dạng**: Dữ liệu được lưu trữ dưới dạng **văn bản thuần túy**
- **Cấu trúc**: Key-value pairs hoặc toàn bộ file
- **Phạm vi**: Có thể được sử dụng bởi **nhiều pod** trong cùng namespace
- **Giới hạn kích thước**: Tối đa **1MB** cho mỗi ConfigMap

### 2. Cách tạo ConfigMap

Kubernetes cung cấp nhiều cách để tạo ConfigMap:

#### Từ Command Line
```bash
# Từ literal values
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2

# Từ file
kubectl create configmap my-config --from-file=path/to/file

# Từ thư mục
kubectl create configmap my-config --from-file=path/to/directory/
```

#### Từ YAML Manifest
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: default
data:
  key1: value1
  key2: value2
  config.yaml: |
    server:
      port: 8080
      host: localhost
```

### 3. Cách sử dụng ConfigMap

ConfigMap có thể được sử dụng theo 3 cách chính:

#### Volume Mounts
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: my-config
```

#### Environment Variables
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: CONFIG_KEY
      valueFrom:
        configMapKeyRef:
          name: my-config
          key: key1
```

#### Command Line Arguments
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    command: ["/bin/sh"]
    args: ["-c", "echo $(CONFIG_KEY)"]
    env:
    - name: CONFIG_KEY
      valueFrom:
        configMapKeyRef:
          name: my-config
          key: key1
```

---

## Tính năng và Ưu điểm

### 1. Tách biệt cấu hình khỏi image

**Lợi ích chính:**
- Sử dụng **cùng một image** cho development, staging và production
- Chỉ cần thay đổi ConfigMap tương ứng cho từng môi trường
- Giảm thiểu số lượng image variants cần quản lý

### 2. Deployment linh hoạt

**Ưu điểm:**
- **Không cần rebuild image** khi cập nhật cấu hình
- Quá trình deployment nhanh hơn
- Dễ dàng rollback cấu hình khi cần thiết

### 3. Cập nhật động

**Tính năng:**
- Khi ConfigMap được cập nhật, các pod sử dụng nó qua **volume mount** sẽ tự động nhận được thay đổi
- Thời gian cập nhật thường trong vòng **vài phút**
- Không cần restart pod khi sử dụng volume mount

### 4. Hỗ trợ đa dạng định dạng

**Khả năng lưu trữ:**
- Dữ liệu đơn giản (key-value)
- File phức tạp (JSON, YAML, XML)
- File cấu hình ứng dụng
- Script và template

### 5. Mounting linh hoạt

**Tùy chọn:**
- Mount toàn bộ ConfigMap
- Mount chỉ một phần cụ thể
- Mount vào nhiều đường dẫn khác nhau

---

## Hạn chế trong thực tế

### 1. Giới hạn kích thước

**Vấn đề:**
- Giới hạn tối đa **1MB** cho mỗi ConfigMap
- Có thể trở thành vấn đề với file cấu hình lớn

**Giải pháp:**
- Chia nhỏ ConfigMap thành nhiều phần
- Sử dụng volume mount từ storage bên ngoài
- Lưu trữ file lớn trong persistent volume

### 2. Bảo mật

**Hạn chế:**
- ConfigMap **không phải là secret**
- Dữ liệu được lưu trữ dưới dạng **plain text**
- Có thể được đọc bởi bất kỳ ai có quyền truy cập cluster

**Lưu ý:**
- Đối với thông tin nhạy cảm (mật khẩu, API key), sử dụng **Secret** thay vì ConfigMap
- Không lưu trữ thông tin bảo mật trong ConfigMap

### 3. Cập nhật qua Environment Variables

**Vấn đề:**
- Khi sử dụng ConfigMap qua biến môi trường, các thay đổi **không được tự động cập nhật**
- Container cần được **restart** để nhận các thay đổi mới

**So sánh:**
- **Volume mount**: Cập nhật tự động
- **Environment variables**: Cần restart container

---

## Các vấn đề thường gặp

### 1. Quản lý phiên bản

**Vấn đề:**
- Không có cơ chế **version control tự động** cho ConfigMap
- Khó khăn trong việc track các thay đổi

**Giải pháp:**
- Sử dụng naming convention với version (e.g., `my-config-v1`, `my-config-v2`)
- Sử dụng Git để quản lý ConfigMap manifests
- Implement proper CI/CD pipeline

### 2. Namespace limitation

**Hạn chế:**
- ConfigMap chỉ có thể được sử dụng trong **cùng namespace**
- Khó khăn khi chia sẻ cấu hình giữa các namespace

**Giải pháp:**
- Tạo ConfigMap riêng cho từng namespace
- Sử dụng automation tools để sync ConfigMap across namespaces
- Sử dụng external configuration management tools

### 3. Dependency management

**Vấn đề:**
- Khi pod khởi động, nếu ConfigMap được tham chiếu **không tồn tại**, pod sẽ không thể start
- Có thể gây cascading failures

**Best practice:**
- Đảm bảo ConfigMap được tạo **trước khi deploy ứng dụng**
- Sử dụng init containers để verify ConfigMap existence
- Implement proper dependency ordering trong deployment pipeline

### 4. Propagation delay

**Vấn đề:**
- Thay đổi ConfigMap có thể mất **vài phút** để propagate đến pods
- Không thể đảm bảo atomic updates across multiple pods

**Giải pháp:**
- Sử dụng readiness probes để ensure pod ready after config changes
- Implement proper health checks
- Consider using immutable ConfigMaps for critical configurations

---

## Best Practices

### 1. Naming Convention

```yaml
# Good naming practice
metadata:
  name: webapp-config-v1
  labels:
    app: webapp
    version: v1
    environment: production
```

### 2. Structured Data

```yaml
# Organize configuration logically
data:
  # Simple key-value pairs
  database_host: "db.example.com"
  database_port: "5432"
  
  # Complex configuration files
  app.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      host: db.example.com
      port: 5432
  
  # Environment-specific configs
  nginx.conf: |
    server {
        listen 80;
        server_name example.com;
        location / {
            proxy_pass http://backend;
        }
    }
```

### 3. Immutable ConfigMaps

```yaml
# For critical configurations
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
immutable: true
data:
  critical_setting: "production_value"
```

### 4. Validation và Testing

```bash
# Validate ConfigMap before applying
kubectl apply --dry-run=client -f configmap.yaml

# Test configuration
kubectl get configmap my-config -o yaml
```

---

## Kết luận

ConfigMap là một công cụ mạnh mẽ cho việc quản lý cấu hình trong Kubernetes, nhưng cần được sử dụng đúng cách và kết hợp với các best practices để tránh những hạn chế và vấn đề tiềm ẩn.

### Khi nào sử dụng ConfigMap:
- ✅ Non-sensitive configuration data
- ✅ Application settings
- ✅ Configuration files
- ✅ Environment-specific parameters

### Khi nào KHÔNG sử dụng ConfigMap:
- ❌ Sensitive data (passwords, API keys)
- ❌ Large files (>1MB)
- ❌ Binary data
- ❌ Frequently changing data requiring immediate updates

**Lời khuyên:** Luôn kết hợp ConfigMap với Secret cho một chiến lược quản lý cấu hình hoàn chỉnh và bảo mật. 