# Kubernetes Services - Lý thuyết và Kiến trúc

## Tổng quan về Service trong Kubernetes

### Khái niệm cơ bản

**Service** trong Kubernetes là một **abstraction layer** định nghĩa một logical set của pods và cách thức để access chúng. Đây là giải pháp cho vấn đề **service discovery** và **load balancing** trong môi trường container động.

### Vấn đề Service giải quyết

#### **Pod Ephemeral Nature:**
- Pods có thể bị **terminate** và **recreate** bất kỳ lúc nào
- Mỗi pod có **IP address riêng** và **không persistent**
- **ReplicaSet** có thể scale up/down, thay đổi pods
- **Deployment updates** tạo pods mới với IPs khác

#### **Service Discovery Challenge:**
```
Vấn đề: Frontend pod cần gọi API từ Backend pods
- Backend Pod 1: 10.244.1.5 (có thể die bất cứ lúc nào)
- Backend Pod 2: 10.244.2.3 (có thể die bất cứ lúc nào)  
- Backend Pod 3: 10.244.1.8 (có thể die bất cứ lúc nào)

Frontend làm sao biết IP nào để call?
Làm sao handle khi pod die và recreate với IP mới?
```

#### **Giải pháp của Service:**
```
Service tạo ra một stable endpoint:
- Service IP: 10.96.0.10 (stable, không đổi)
- Service DNS: backend-service.default.svc.cluster.local
- Service auto-discover và load balance tới available pods
```

---

## Kiến trúc Service

### Service Architecture Components

```
[Client] → [Service] → [Endpoints] → [Pods]
     ↓         ↓           ↓          ↓
   Request   Stable IP   Pod IPs   Containers
```

#### **1. Service Object:**
- **Stable IP address** (ClusterIP)
- **DNS name** cho service discovery
- **Port mapping** configuration
- **Selection criteria** (labels)

#### **2. Endpoints Object:**
- **Dynamic list** của pod IPs
- **Được update** khi pods change
- **Health status** của từng endpoint
- **Port information** cho mỗi pod

#### **3. kube-proxy Component:**
- **Traffic routing** từ service tới pods
- **Load balancing** algorithms
- **iptables/IPVS rules** management
- **Service networking** implementation

### Service Network Flow

```
Client Request Flow:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│   Service   │───▶│  Endpoints  │───▶│    Pods     │
│   Request   │    │ (Stable IP) │    │ (Pod IPs)   │    │(Containers) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
      ▲                    │                    │                    │
      │                    ▼                    ▼                    ▼
      │            ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
      └────────────│ kube-proxy  │───▶│  iptables   │───▶│ Pod Network │
                   │  Routing    │    │   Rules     │    │  Interface  │
                   └─────────────┘    └─────────────┘    └─────────────┘
```

---

## 4 Service Types - Phân tích lý thuyết

### 1. ClusterIP - Internal Service Pattern

#### **Architectural Purpose:**
**ClusterIP** implement **Internal Service Pattern** - một design pattern cho **intra-cluster communication**.

#### **Network Layer:**
```
OSI Layer 3 (Network): Cluster-internal IP allocation
OSI Layer 4 (Transport): TCP/UDP port mapping  
OSI Layer 7 (Application): Service discovery via DNS
```

#### **IP Allocation Mechanism:**
```yaml
Service CIDR: 10.96.0.0/12 (default)
├── Static allocation: Manually specified clusterIP
├── Dynamic allocation: Kubernetes assigns from pool
└── IP persistence: Stable until service deletion
```

#### **DNS Resolution Pattern:**
```
Service Discovery Hierarchy:
service-name.namespace.svc.cluster.local
    ↓
service-name.namespace.svc
    ↓  
service-name.namespace
    ↓
service-name (trong cùng namespace)
```

#### **Load Balancing Theory:**
- **Round-robin** (default): Distribute evenly
- **Session affinity**: Sticky sessions via clientIP
- **Weighted distribution**: Based on pod readiness

### 2. NodePort - Node-based Exposure Pattern

#### **Architectural Concept:**
**NodePort** implement **Host Port Pattern** - expose services qua node infrastructure.

#### **Port Allocation Strategy:**
```
Port Space Management:
├── System ports: 0-1023 (reserved)
├── User ports: 1024-29999 (available for apps)
├── NodePort range: 30000-32767 (K8s services)
└── Dynamic ports: 32768-65535 (ephemeral)
```

#### **Network Topology:**
```
External Client
      ↓
Physical Network (192.168.1.0/24)
      ↓
Node IP:NodePort (192.168.1.101:30080)
      ↓
iptables NAT rules
      ↓
Service ClusterIP:Port (10.96.0.10:80)
      ↓
Pod IP:TargetPort (10.244.1.5:8080)
```

#### **kube-proxy Implementation:**
```bash
# iptables rules created by kube-proxy
-A KUBE-NODEPORTS -p tcp --dport 30080 -j KUBE-SVC-XYZ
-A KUBE-SVC-XYZ -j KUBE-SEP-ABC  # To pod 1
-A KUBE-SVC-XYZ -j KUBE-SEP-DEF  # To pod 2
```

### 3. LoadBalancer - On-Premise Load Balancing Pattern

#### **Architectural Philosophy:**
**LoadBalancer** trong **on-premise environment** cần **external load balancer implementation** như MetalLB, HAProxy, hoặc hardware load balancers.

#### **On-Premise LoadBalancer Challenge:**
```
Kubernetes Service Controller
          ↓
NO Cloud Provider Available ❌
          ↓
EXTERNAL-IP: <Pending> Status
          ↓
Manual Load Balancer Setup Required
```

#### **MetalLB Implementation (Bare Metal):**
```
MetalLB Controller
          ↓
IP Address Pool Management
          ↓
ARP/BGP Advertisement
          ↓
External IP Assignment
          ↓
Direct Traffic Routing
```

#### **On-Premise Solutions:**

**MetalLB (Layer 2 Mode):**
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
```

**HAProxy External Load Balancer:**
```bash
# /etc/haproxy/haproxy.cfg
frontend k8s-service
    bind 192.168.1.200:80
    default_backend k8s-nodes

backend k8s-nodes
    balance roundrobin
    server node1 192.168.1.101:30080 check
    server node2 192.168.1.102:30080 check
    server node3 192.168.1.103:30080 check
```

**Hardware Load Balancer Integration:**
```yaml
# F5, NetScaler, or similar
metadata:
  annotations:
    service.beta.kubernetes.io/external-traffic: "Local"
    metallb.universe.tf/address-pool: "production-pool"
```

### 4. ExternalName - DNS Delegation Pattern

#### **Theoretical Foundation:**
**ExternalName** implement **Service Facade Pattern** - provide internal interface cho external resources.

#### **DNS CNAME Mechanism:**
```
DNS Resolution Chain:
internal-service.default.svc.cluster.local
           ↓ (CNAME record)
external-api.company.com
           ↓ (A/AAAA record)  
203.0.113.10
```

#### **Service Mesh Integration:**
```yaml
# Istio VirtualService pattern
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: external-service
spec:
  hosts:
  - external-api
  http:
  - route:
    - destination:
        host: external-api.company.com
```

---

## On-Premise Service Implementation Strategies

### Physical Network Integration

#### **VLAN Segmentation:**
```
Management VLAN (192.168.1.0/24):
├── K8s Master Nodes: 192.168.1.101-103
├── ESXi Host: 192.168.1.110
└── Rancher Server: 192.168.1.104

Service VLAN (192.168.2.0/24):
├── LoadBalancer VIPs: 192.168.2.100-150
├── External Access Points
└── DMZ Services

Pod Network (10.244.0.0/16):
├── CNI Managed (Calico/Flannel)
├── Inter-pod Communication
└── Internal Service Discovery
```

#### **Router Configuration cho On-Premise:**
```bash
# Static routes for service discovery
ip route add 10.96.0.0/12 via 192.168.1.101  # Service CIDR
ip route add 10.244.0.0/16 via 192.168.1.101 # Pod CIDR

# DHCP reservations cho load balancer pool
# 192.168.1.200-250 reserved for MetalLB
```

### Hardware Load Balancer Integration

#### **F5 BIG-IP Configuration:**
```bash
# Create pool members
tmsh create ltm pool k8s-webapp-pool members add { 
    192.168.1.101:30080 
    192.168.1.102:30080 
    192.168.1.103:30080 
}

# Create virtual server
tmsh create ltm virtual k8s-webapp-vs {
    destination 192.168.1.200:80
    pool k8s-webapp-pool
    profiles add { http tcp }
}
```

#### **HAProxy Configuration Pattern:**
```bash
# /etc/haproxy/haproxy.cfg
global
    log stdout daemon
    chroot /var/lib/haproxy

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

# Kubernetes service backends
frontend k8s-services
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/
    
    # Route based on Host header
    use_backend webapp-backend if { hdr(host) -i webapp.local }
    use_backend api-backend if { hdr(host) -i api.local }
    
backend webapp-backend
    balance roundrobin
    option httpchk GET /health
    server node1 192.168.1.101:30080 check
    server node2 192.168.1.102:30080 check
    server node3 192.168.1.103:30080 check

backend api-backend
    balance roundrobin
    option httpchk GET /api/health
    server node1 192.168.1.101:30081 check
    server node2 192.168.1.102:30081 check
    server node3 192.168.1.103:30081 check
```

### On-Premise DNS Integration

#### **Corporate DNS Integration:**
```bash
# Bind9 Configuration
zone "lab.local" {
    type master;
    file "/etc/bind/zones/lab.local";
};

# /etc/bind/zones/lab.local
$TTL    604800
@       IN      SOA     dns.lab.local. admin.lab.local. (
                        2024010101      ; Serial
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL

; K8s Services via MetalLB VIPs
webapp          IN      A       192.168.1.200
api             IN      A       192.168.1.201
dashboard       IN      A       192.168.1.202

; K8s Nodes
k8s-master-1    IN      A       192.168.1.101
k8s-master-2    IN      A       192.168.1.102
k8s-master-3    IN      A       192.168.1.103
```

#### **dnsmasq cho Local Development:**
```bash
# /etc/dnsmasq.d/k8s-services.conf
# Map service names to LoadBalancer IPs
address=/webapp.lab.local/192.168.1.200
address=/api.lab.local/192.168.1.201
address=/rancher.lab.local/192.168.1.104

# Wildcard for development
address=/.dev.lab.local/192.168.1.210
```

## Service Discovery Mechanisms

#### **CoreDNS Architecture:**
```
Pod DNS Query → CoreDNS → Kubernetes API → Service Object → Response
```

#### **DNS Record Types:**
```yaml
A Record: service-name.namespace.svc.cluster.local → ClusterIP
SRV Record: _port._protocol.service-name.namespace.svc.cluster.local
PTR Record: Reverse DNS lookup for debugging
```

### Environment Variable Discovery

#### **Legacy Pattern (deprecated):**
```bash
# Kubernetes injects service info as env vars
WEBAPP_SERVICE_HOST=10.96.0.10
WEBAPP_SERVICE_PORT=80
WEBAPP_SERVICE_PORT_80_TCP=tcp://10.96.0.10:80
```

---

## Traffic Routing Algorithms

### kube-proxy Modes

#### **1. iptables Mode (default):**
```bash
# Random selection using iptables probability
-A KUBE-SVC-XYZ -m statistic --mode random --probability 0.33 -j KUBE-SEP-1
-A KUBE-SVC-XYZ -m statistic --mode random --probability 0.50 -j KUBE-SEP-2  
-A KUBE-SVC-XYZ -j KUBE-SEP-3
```

#### **2. IPVS Mode (advanced):**
```bash
# More efficient, supports more algorithms
ipvsadm -L -n
TCP  10.96.0.10:80 rr
  -> 10.244.1.5:8080      Masq    1      0          0
  -> 10.244.2.3:8080      Masq    1      0          0
```

### Load Balancing Algorithms

#### **Round Robin (default):**
```
Request 1 → Pod A
Request 2 → Pod B  
Request 3 → Pod C
Request 4 → Pod A (cycle repeats)
```

#### **Session Affinity:**
```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800  # 3 hours
```

---

## Network Policies và Security

### Service-level Security

#### **Network Policy Integration:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-access-policy
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

#### **Service Mesh Security:**
```yaml
# Istio mTLS policy
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: strict-mtls
spec:
  mtls:
    mode: STRICT
```

---

## Service Performance Considerations

### On-Premise Performance Optimization

#### **Node Affinity cho Load Balancing:**
```yaml
# Prefer local node traffic (reduce network hops)
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  annotations:
    service.beta.kubernetes.io/external-traffic: "Local"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local  # Keep traffic on same node
  selector:
    app: webapp
```

#### **Hardware Resource Optimization:**
```yaml
# NUMA-aware pod scheduling
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    kubernetes.io/hostname: node-with-optimal-placement
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
```

#### **Network Bandwidth Management:**
```yaml
# Traffic shaping for on-premise networks
metadata:
  annotations:
    kubernetes.io/ingress.bandwidth: "100M"
    kubernetes.io/egress.bandwidth: "100M"
```

### Connection Handling

#### **Connection Draining:**
```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: app
        lifecycle:
          preStop:
            httpGet:
              path: /shutdown
              port: 8080
```

---

## On-Premise Service Deployment Patterns

### Typical On-Premise Architecture

```
Corporate Network (192.168.0.0/16)
├── Management Subnet (192.168.1.0/24)
│   ├── ESXi Hosts: .110-.120
│   ├── K8s Masters: .101-.103
│   └── Rancher: .104
├── Service Subnet (192.168.2.0/24)  
│   ├── LoadBalancer VIPs: .100-.150
│   ├── External Services: .151-.200
│   └── DMZ Services: .201-.250
└── Storage Network (192.168.10.0/24)
    ├── NFS/iSCSI: .10-.50
    └── Backup Systems: .51-.100
```

### Enterprise Integration Patterns

#### **Active Directory Integration:**
```yaml
# LDAP/AD authentication for services
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldap-config
data:
  ldap.conf: |
    server: ldap://dc.company.local:389
    base_dn: DC=company,DC=local
    bind_dn: CN=k8s-service,OU=ServiceAccounts,DC=company,DC=local
```

#### **Certificate Management:**
```yaml
# Internal CA certificates
apiVersion: v1
kind: Secret
metadata:
  name: internal-ca-cert
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # Internal CA certificate
  tls.key: LS0tLS1CRUdJTi... # Private key for services
```

### Hardware Load Balancer Patterns

#### **F5 BIG-IP Service Integration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: production-webapp
  annotations:
    # F5 specific annotations
    virtual-server.f5.com/ip: "192.168.2.100"
    virtual-server.f5.com/partition: "kubernetes"
    virtual-server.f5.com/pool-member-type: "nodeport"
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.2.100
  selector:
    app: webapp
    tier: production
```

#### **Cisco ACI Integration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: aci-integrated-service
  annotations:
    aci.cisco.com/external-ip: "192.168.2.101"
    aci.cisco.com/tenant: "kubernetes-tenant"
    aci.cisco.com/app-profile: "k8s-services"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
```

### Headless Services

#### **Use Case:** Direct pod communication
```yaml
apiVersion: v1
kind: Service
metadata:
  name: headless-service
spec:
  clusterIP: None  # Headless
  selector:
    app: database
  ports:
  - port: 5432
```

#### **DNS Behavior:**
```bash
# Normal service: Returns ClusterIP
nslookup webapp-service
# Returns: 10.96.0.10

# Headless service: Returns all pod IPs
nslookup headless-service  
# Returns: 10.244.1.5, 10.244.2.3, 10.244.1.8
```

### Multi-port Services

#### **Protocol Multiplexing:**
```yaml
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https  
    port: 443
    targetPort: 8443
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
```

### External Services với Endpoints

#### **Manual Endpoint Management:**
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  ports:
  - port: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-database
subsets:
- addresses:
  - ip: 192.168.1.200
  - ip: 192.168.1.201
  ports:
  - port: 5432
```

---

## Service Mesh Integration

### Service-to-Service Communication

#### **Traditional K8s Services:**
```
Pod A → Service → Pod B
(Layer 4 load balancing only)
```

#### **Service Mesh (Istio/Linkerd):**
```
Pod A → Sidecar Proxy → Service → Sidecar Proxy → Pod B
(Layer 7 routing, mTLS, observability)
```

### Advanced Traffic Management

#### **Canary Deployments:**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: canary-routing
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: webapp-service
        subset: v2
  - route:
    - destination:
        host: webapp-service
        subset: v1
```

---

## Theoretical Comparison

### On-Premise vs Cloud Service Comparison

| Aspect | On-Premise | Cloud |
|--------|------------|-------|
| **LoadBalancer Implementation** | MetalLB/HAProxy/Hardware | Cloud Provider Native |
| **IP Management** | Manual IP Pool | Automatic Allocation |
| **Cost Model** | Hardware CapEx | OpEx per LB instance |
| **Scalability** | Hardware Limited | Cloud Scale |
| **Control** | Full Control | Provider Dependent |
| **Latency** | Local Network | Internet + Cloud |
| **Security** | Internal Network | Cloud Security Model |
| **Maintenance** | Self-Managed | Provider Managed |

### On-Premise Specific Considerations

#### **Network Infrastructure Requirements:**
- **Sufficient IP pools** cho LoadBalancer services
- **VLAN segmentation** for traffic isolation  
- **Hardware load balancer** hoặc software alternatives
- **DNS integration** với corporate infrastructure
- **Firewall rules** cho service exposure

#### **Hardware Sizing cho Service Load:**
```
Service Type Usage (typical on-premise):
├── ClusterIP: 70% (internal microservices)
├── NodePort: 20% (development, debugging)
├── LoadBalancer: 9% (production external services)
└── ExternalName: 1% (external integrations)

Resource Planning:
├── MetalLB IP Pool: /27 subnet (30 IPs)
├── NodePort range: 30000-32767 (2768 ports)
└── ClusterIP range: /12 subnet (1M IPs)
```

### Network Layer Analysis

```
Application Layer (L7): HTTP/HTTPS routing, content-based
Presentation Layer (L6): SSL/TLS termination  
Session Layer (L5): Session management, load balancer cookies
Transport Layer (L4): TCP/UDP port mapping ← Service operates here
Network Layer (L3): IP routing, cluster networking
Data Link Layer (L2): Node-to-node communication
Physical Layer (L1): Network infrastructure
```

---

## Design Principles

### Declarative Configuration

**Services follow Kubernetes' declarative model:**
- **Desired state**: Declare what you want
- **Controller reconciliation**: System maintains state
- **Self-healing**: Automatic recovery from failures

### Loose Coupling

**Services enable microservices architecture:**
- **Service contracts**: Stable interface despite implementation changes
- **Independent deployment**: Services can update independently  
- **Fault isolation**: Service failures don't cascade

### Scalability Patterns

**Horizontal scaling support:**
- **Stateless design**: Services work with any number of pods
- **Load distribution**: Automatic traffic spreading
- **Dynamic discovery**: No hardcoded endpoints

---

## Kết luận

Kubernetes Services là **fundamental networking primitive** cung cấp:

1. **Service Discovery**: DNS-based và environment-based
2. **Load Balancing**: Multiple algorithms và session affinity
3. **Network Abstraction**: Stable endpoints cho dynamic pods
4. **Multi-environment Support**: Internal, external, và hybrid scenarios

**4 Service types** cover toàn bộ spectrum của **service networking requirements** từ internal microservices communication đến external load balancing và DNS delegation.

Understanding Services là **prerequisite** cho advanced topics như **Ingress**, **Service Mesh**, và **Network Policies**.