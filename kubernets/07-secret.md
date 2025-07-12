# Kubernetes Secret - Tổng quan và Hướng dẫn

## Tổng quan về Secret

### Khái niệm cơ bản

**Secret** là một tài nguyên quan trọng trong Kubernetes được thiết kế đặc biệt để lưu trữ và quản lý thông tin nhạy cảm như:
- **Mật khẩu** (Passwords)
- **Token** (API tokens, OAuth tokens)
- **SSH keys** (Private keys)
- **TLS certificates** (SSL/TLS certificates)
- **Các dữ liệu bảo mật khác** (Database credentials, API keys)

### So sánh với ConfigMap

| Aspect | ConfigMap | Secret |
|--------|-----------|--------|
| **Mục đích** | Dữ liệu cấu hình thông thường | Dữ liệu nhạy cảm, bảo mật |
| **Encoding** | Plain text | Base64 encoded |
| **Storage** | etcd (plain text) | etcd (base64 encoded) |
| **Mount location** | Disk | tmpfs (memory filesystem) |
| **Use case** | Configuration files | Passwords, certificates, tokens |

---

## Đặc điểm chính của Secret

### 1. Encoding và Storage

**Base64 Encoding:**
- Dữ liệu trong Secret được **mã hóa base64** khi lưu trữ trong etcd
- ⚠️ **Lưu ý**: Đây không phải là mã hóa thực sự mà chỉ là encoding để tránh ký tự đặc biệt
- Bất kỳ ai có quyền truy cập vào etcd hoặc có thể decode base64 đều có thể đọc được nội dung

```bash
# Ví dụ encoding base64
echo "my-secret-password" | base64
# Output: bXktc2VjcmV0LXBhc3N3b3JkCg==

# Decode base64
echo "bXktc2VjcmV0LXBhc3N3b3JkCg==" | base64 -d
# Output: my-secret-password
```

### 2. Cách sử dụng Secret

Secret có thể được sử dụng theo 3 cách chính:

#### Volume Mount (Khuyến khích)
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secret
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: my-secret
```

#### Environment Variables (Cẩn thận)
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

#### Tự động mount (Service Account Token)
```yaml
# Kubernetes tự động mount service account token
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: my-service-account
  # Token được tự động mount vào /var/run/secrets/kubernetes.io/serviceaccount/
```

### 3. Bảo mật tmpfs

**Memory Filesystem:**
- Khi mount dưới dạng volume, Secret được lưu trong **tmpfs** (memory filesystem)
- Dữ liệu chỉ tồn tại trong memory và **không được ghi vào disk**
- Giảm thiểu nguy cơ bị đọc trộm từ storage

---

## Tính năng và Ưu điểm

### 1. Separation of Concerns

**Tách biệt thông tin nhạy cảm:**
- Developer không cần **hard-code** password hoặc API key trong code
- Thông tin nhạy cảm được quản lý riêng biệt khỏi mã nguồn
- Tuân thủ nguyên tắc bảo mật "separation of concerns"

### 2. RBAC Integration

**Role-Based Access Control:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames: ["db-secret"] # Chỉ cho phép truy cập secret cụ thể
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-binding
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3. Automatic Rotation Support

**Tự động xoay vòng:**
- **cert-manager** cho TLS certificates
- **External Secret Operator** cho việc đồng bộ từ external vault
- **AWS Secrets Manager**, **Azure Key Vault**, **HashiCorp Vault**

```yaml
# Ví dụ với cert-manager
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
spec:
  secretName: my-cert-secret
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
  - example.com
```

### 4. Enhanced Security

**Tăng cường bảo mật:**
- Memory-only storage khi sử dụng volume mount
- RBAC kiểm soát quyền truy cập chi tiết
- Namespace isolation
- Audit logging support

---

## Hạn chế và Thách thức Bảo mật

### 1. Base64 Encoding ≠ Encryption

**Vấn đề:**
- ⚠️ **Base64 không phải là mã hóa thực sự**
- Dễ dàng decode bởi bất kỳ ai
- Yêu cầu bảo vệ chặt chẽ quyền truy cập cluster

**Giải pháp:**
```bash
# Sử dụng external secret management
# HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
```

### 2. Giới hạn kích thước

**Hạn chế:**
- Giới hạn tối đa **1MB** cho mỗi Secret
- Có thể gây khó khăn với file certificate lớn

**Giải pháp:**
- Chia nhỏ Secret thành nhiều phần
- Sử dụng external secret management
- Lưu trữ file lớn trong persistent volume

### 3. Environment Variables Risk

**Nguy cơ:**
- Thông tin có thể bị lộ qua **process list**
- Có thể xuất hiện trong **container logs**
- Không được cập nhật động

**Best Practice:**
```yaml
# ✅ Khuyến khích: Volume mount
volumeMounts:
- name: secret-volume
  mountPath: /etc/secret
  readOnly: true

# ❌ Cẩn thận: Environment variables
env:
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: password
```

### 4. Lifecycle Management

**Thách thức:**
- Không có cơ chế tự động backup và recovery
- Secret rotation phức tạp
- Có thể gây downtime nếu không được thực hiện cẩn thận

---

## Các loại Secret Built-in

### 1. Opaque (Generic)

**Mục đích**: Dữ liệu tùy ý (default type)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: generic-secret
type: Opaque
data:
  username: YWRtaW4=        # admin
  password: MWYyZDFlMmU2N2Rm # 1f2d1e2e67df
```

```bash
# Tạo từ command line
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpassword
```

### 2. kubernetes.io/service-account-token

**Mục đích**: JWT token cho ServiceAccount

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sa-token
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token
```

**Tự động mount:**
```bash
# Tự động mount vào pod tại:
/var/run/secrets/kubernetes.io/serviceaccount/token
/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
/var/run/secrets/kubernetes.io/serviceaccount/namespace
```

### 3. kubernetes.io/dockerconfigjson

**Mục đích**: Docker registry authentication

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJyZWdpc3RyeS5leGFtcGxlLmNvbSI6IHsKICAgICAgInVzZXJuYW1lIjogInVzZXIiLAogICAgICAicGFzc3dvcmQiOiAicGFzcyIsCiAgICAgICJhdXRoIjogImRYTmxjanB3WVhOeiIKICAgIH0KICB9Cn0=
```

```bash
# Tạo từ command line
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com
```

### 4. kubernetes.io/tls

**Mục đích**: TLS certificates

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # Certificate
  tls.key: LS0tLS1CRUdJTi... # Private key
```

```bash
# Tạo từ files
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/key.key
```

### 5. kubernetes.io/basic-auth

**Mục đích**: Basic authentication

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
type: kubernetes.io/basic-auth
data:
  username: YWRtaW4=     # admin
  password: c2VjcmV0cGFzcw== # secretpass
```

### 6. kubernetes.io/ssh-auth

**Mục đích**: SSH authentication

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ssh-secret
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: LS0tLS1CRUdJTi... # SSH private key
  ssh-knownhosts: Z2l0aHViLmNvbS... # Optional known hosts
```

### 7. kubernetes.io/dockercfg (Deprecated)

**Mục đích**: Legacy Docker registry authentication

```yaml
# ❌ Deprecated - Sử dụng dockerconfigjson thay thế
apiVersion: v1
kind: Secret
metadata:
  name: legacy-docker-secret
type: kubernetes.io/dockercfg
data:
  .dockercfg: ewogICJyZWdpc3RyeS5leGFtcGxlLmNvbSI6IHsKICAgICJ1c2VybmFtZSI6ICJ1c2VyIiwKICAgICJwYXNzd29yZCI6ICJwYXNzIiwKICAgICJhdXRoIjogImRYTmxjanB3WVhOeiIKICB9Cn0=
```

### 8. bootstrap.kubernetes.io/token

**Mục đích**: Bootstrap tokens cho cluster join

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-abcdef
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  token-id: YWJjZGVm        # abcdef
  token-secret: MDEyMzQ1Njc4OWFiY2RlZg== # 0123456789abcdef
  usage-bootstrap-authentication: dHJ1ZQ==  # true
  usage-bootstrap-signing: dHJ1ZQ==          # true
```

---

## Docker Private Registry (Harbor) Integration

### Tổng quan Harbor

**Harbor** là một enterprise-grade Docker registry với các tính năng:
- **RBAC** (Role-Based Access Control)
- **Vulnerability scanning**
- **Image signing**
- **Replication** giữa registries
- **Helm chart repository**

### Step-by-step Implementation

#### Step 0: Cài đặt Harbor

```bash
# Tham khảo hướng dẫn cài đặt Harbor
# https://goharbor.io/docs/latest/install-config/
```

#### Step 1: Tạo Secret cho Harbor Authentication

```bash
# Tạo secret chứa thông tin xác thực Harbor
kubectl create secret docker-registry auth-registry \
  --docker-email=yourmail@gmail.com \
  --docker-username=username-harbor \
  --docker-password=password-harbor \
  --docker-server=domain-harbor.com \
  --namespace=ecommerce
```

**Hoặc sử dụng YAML:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-registry
  namespace: ecommerce
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ewogICJhdXRocyI6IHsKICAgICJkb21haW4taGFyYm9yLmNvbSI6IHsKICAgICAgInVzZXJuYW1lIjogInVzZXJuYW1lLWhhcmJvciIsCiAgICAgICJwYXNzd29yZCI6ICJwYXNzd29yZC1oYXJib3IiLAogICAgICAiZW1haWwiOiAieW91cm1haWxAZ21haWwuY29tIiwKICAgICAgImF1dGgiOiAiZFhObGNtNWhiV1V0YUdGeVltOXlPbkJoYzNOM2IzSmtMV2hoY21KdmNnPT0iCiAgICB9CiAgfQp9
```

#### Step 2: Sử dụng Secret trong Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-backend
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ecommerce-backend
  template:
    metadata:
      labels:
        app: ecommerce-backend
    spec:
      containers:
      - name: backend
        image: harbor-domain.com/devopseduvn/ecommerce-backend:v1
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: "postgresql-service"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      imagePullSecrets:
      - name: auth-registry  # Tham chiếu đến Secret
```

#### Step 3: Verify và Troubleshoot

```bash
# Kiểm tra Secret
kubectl get secret auth-registry -n ecommerce -o yaml

# Decode và kiểm tra nội dung
kubectl get secret auth-registry -n ecommerce -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Kiểm tra Pod events
kubectl describe pod <pod-name> -n ecommerce

# Kiểm tra image pull
kubectl get events -n ecommerce --field-selector reason=Failed
```

### Advanced Harbor Configuration

#### Multi-environment Setup

```yaml
# Production Harbor Secret
apiVersion: v1
kind: Secret
metadata:
  name: harbor-prod
  namespace: production
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-config>
---
# Staging Harbor Secret
apiVersion: v1
kind: Secret
metadata:
  name: harbor-staging
  namespace: staging
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-config>
```

#### Using with Helm

```yaml
# values.yaml
image:
  repository: harbor-domain.com/devopseduvn/app
  tag: v1.0.0
  pullPolicy: Always

imagePullSecrets:
  - name: auth-registry

serviceAccount:
  create: true
  name: app-service-account
```

---

## Best Practices

### 1. Security Best Practices

#### Principle of Least Privilege
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["specific-secret-name"]  # Chỉ cho phép secret cụ thể
```

#### Separate Secrets by Environment
```bash
# Development
kubectl create secret generic db-secret \
  --from-literal=username=dev-user \
  --from-literal=password=dev-pass \
  --namespace=development

# Production  
kubectl create secret generic db-secret \
  --from-literal=username=prod-user \
  --from-literal=password=prod-pass \
  --namespace=production
```

### 2. Operational Best Practices

#### Naming Convention
```yaml
metadata:
  name: app-database-secret-v1
  labels:
    app: myapp
    component: database
    version: v1
    environment: production
```

#### Immutable Secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
immutable: true  # Không thể thay đổi sau khi tạo
type: Opaque
data:
  api-key: <base64-encoded-value>
```

### 3. External Secret Management

#### External Secrets Operator
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.company.com"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: secret/app
      property: password
```

### 4. Monitoring và Auditing

#### Audit Logging
```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

#### Monitoring Secret Access
```bash
# Sử dụng Falco hoặc tương tự
- rule: Secret Access
  desc: Detect secret access
  condition: ka.verb in (get, list) and ka.resource.name="secrets"
  output: Secret accessed (user=%ka.user.name verb=%ka.verb resource=%ka.resource.name)
  priority: INFO
```

---

## Troubleshooting

### Common Issues

#### 1. ImagePullBackOff với Private Registry
```bash
# Kiểm tra Secret
kubectl get secret auth-registry -o yaml

# Verify Secret format
kubectl get secret auth-registry -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# Kiểm tra Pod events
kubectl describe pod <pod-name>
```

#### 2. Base64 Encoding Issues
```bash
# Encoding không có newline
echo -n "password" | base64

# Decoding
echo "cGFzc3dvcmQ=" | base64 -d
```

#### 3. RBAC Permission Denied
```bash
# Kiểm tra quyền
kubectl auth can-i get secrets --as=system:serviceaccount:namespace:serviceaccount-name

# Debug RBAC
kubectl describe rolebinding -n namespace
```

### Performance Considerations

#### 1. Secret Size Optimization
```yaml
# Tốt: Tách Secret theo function
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
data:
  username: <base64>
  password: <base64>
---
apiVersion: v1
kind: Secret
metadata:
  name: api-secret
data:
  api-key: <base64>
```

#### 2. Mount Optimization
```yaml
# Mount chỉ những key cần thiết
volumeMounts:
- name: secret-volume
  mountPath: /etc/secret
  readOnly: true
volumes:
- name: secret-volume
  secret:
    secretName: my-secret
    items:
    - key: password
      path: db-password
    - key: api-key
      path: api-key
```

---

## Kết luận

### Khi nào sử dụng Secret:
- ✅ **Mật khẩu** và credentials
- ✅ **API keys** và tokens
- ✅ **TLS certificates** và private keys
- ✅ **SSH keys** và authentication data
- ✅ **Docker registry** credentials

### Khi nào KHÔNG sử dụng Secret:
- ❌ **Public configuration** data
- ❌ **Large files** (>1MB)
- ❌ **Frequently changing** data
- ❌ **Binary data** (sử dụng volume thay thế)

### Key Takeaways:
1. **Secret ≠ Secure**: Base64 encoding không phải encryption
2. **Volume mount** tốt hơn environment variables
3. **RBAC** là critical cho secret security
4. **External secret management** cho production environment
5. **Monitoring và auditing** là cần thiết

**Lời khuyên**: Sử dụng Secret kết hợp với external secret management tools như HashiCorp Vault, AWS Secrets Manager, hoặc Azure Key Vault cho production environment để đảm bảo bảo mật tối ưu. 