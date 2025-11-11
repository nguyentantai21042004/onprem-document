# Kubernetes Ingress and Networking

## Table of Contents
1. [Ingress Overview](#ingress-overview)
2. [Ingress Controller Setup](#ingress-controller-setup)
3. [Ingress Configuration](#ingress-configuration)
4. [TLS/SSL Configuration](#tlsssl-configuration)
5. [Advanced Networking](#advanced-networking)
6. [Network Policies](#network-policies)
7. [Load Balancing](#load-balancing)
8. [Troubleshooting](#troubleshooting)

## Ingress Overview

### What is Ingress?
Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

### Key Components
- **Ingress Controller**: Processes Ingress rules and configures load balancer
- **Ingress Resource**: Defines routing rules
- **Backend Services**: Target services for traffic routing

## Ingress Controller Setup

### NGINX Ingress Controller Installation

```bash
# Add NGINX Ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.metrics.enabled=true \
  --set controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set controller.podAnnotations."prometheus\.io/port"="10254"

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx
```

### Configure External Access

```bash
# For on-premise deployment, configure NodePort
kubectl patch service ingress-nginx-controller \
  -n ingress-nginx \
  -p '{"spec":{"ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":"http","nodePort":30080}]}}'

kubectl patch service ingress-nginx-controller \
  -n ingress-nginx \
  -p '{"spec":{"ports":[{"name":"https","port":443,"protocol":"TCP","targetPort":"https","nodePort":30443}]}}'
```

## Ingress Configuration

### Basic Ingress Resource

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

### Multi-Host Ingress

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

### Path-Based Routing

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

## TLS/SSL Configuration

### Certificate Management with cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
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

### TLS-enabled Ingress

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

## Advanced Networking

### Common Annotations

```yaml
annotations:
  # Basic configurations
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  
  # SSL configurations
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  
  # Rate limiting
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/rate-limit-rps: "10"
  
  # Authentication
  nginx.ingress.kubernetes.io/auth-type: basic
  nginx.ingress.kubernetes.io/auth-secret: basic-auth
  
  # CORS
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
```

### Custom Backend Configuration

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

## Network Policies

### Basic Network Policy

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

### Allow Specific Traffic

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

## Load Balancing

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

## Troubleshooting

### Common Issues

#### 1. Ingress Not Accessible
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress resource
kubectl describe ingress your-ingress-name
kubectl get ingress -A
```

#### 2. Backend Service Issues
```bash
# Check service endpoints
kubectl get endpoints your-service-name
kubectl describe service your-service-name

# Test service connectivity
kubectl run test-pod --image=nginx --rm -it -- /bin/bash
curl http://your-service-name.namespace.svc.cluster.local
```

#### 3. DNS Resolution Issues
```bash
# Check DNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it -- nslookup kubernetes.default
```

### Debugging Commands

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check ingress configuration
kubectl get ingress -o yaml

# Test connectivity
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### Performance Optimization

#### 1. Enable Compression
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

## Best Practices

1. **Use meaningful names** for ingress resources
2. **Implement proper TLS** for all external services
3. **Configure rate limiting** to prevent abuse
4. **Use network policies** for security
5. **Monitor ingress metrics** for performance
6. **Test configurations** in staging first
7. **Document routing rules** clearly
8. **Use proper annotations** for specific requirements

## Security Considerations

1. **Enable SSL/TLS** for all ingress resources
2. **Use proper authentication** mechanisms
3. **Configure rate limiting** and DDoS protection
4. **Implement network policies** for traffic control
5. **Regular security updates** for ingress controller
6. **Monitor access logs** for suspicious activity

## Integration with Harbor Registry

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

This comprehensive guide covers all aspects of Kubernetes ingress and networking configuration for your on-premise server setup. 