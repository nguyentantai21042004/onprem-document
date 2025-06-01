# Server Build Documentation

## 📋 Tổng quan

Repository này chứa tài liệu hướng dẫn chi tiết về việc xây dựng và quản lý home server, tập trung vào **DevOps learning** và **hands-on experience**. Từ những bước cơ bản như Wake On LAN đến advanced như VPN server và container orchestration.

## 🎯 Mục tiêu

- **Hands-on DevOps Learning**: Practical experience với real-world scenarios
- **Automation Focus**: Từ manual process đến complete automation 
- **Production-Ready**: Best practices và security-first approach
- **Progressive Learning**: Từ foundation đến advanced concepts
- **Vietnamese Context**: Tối ưu cho environment và ISP Việt Nam

---

## 📚 Guides Available

### 1. [Wake On LAN](Wake-On-LAN.md) 
**Level**: Foundation | **Time**: 30 mins | **Tags**: #Hardware #Automation #Remote

Wake On LAN setup với client-side automation scripts. Foundation cho remote server management và DevOps automation workflow.

**Learning Outcomes**: Remote control, network protocols, automation scripts, infrastructure as code basics.

---

### 2. [ESXi VM Autostart & Service Automation](ESXi-VM-Autostart.md)
**Level**: Intermediate | **Time**: 45 mins | **Tags**: #ESXi #Automation #SystemD

Complete automation từ hardware boot đến application services. ESXi VM autostart configuration và service automation trong Linux VMs.

**Learning Outcomes**: Service orchestration, systemd, dependency management, reliability engineering.

---

### 3. [Port Forwarding & Network Services](Port-Forwarding.md) 
**Level**: Intermediate | **Time**: 1 hour | **Tags**: #Networking #Security #Production

Router configuration, service exposure, và production deployment với reverse proxy. Hands-on với Vietnamese ISP routers.

**Learning Outcomes**: Network security, reverse proxy, SSL/TLS, monitoring, production deployment.

---

### 4. [OpenVPN Server với OVPM](VPN-Server-OpenVPN.md)
**Level**: Advanced | **Time**: 1.5 hours | **Tags**: #VPN #Security #PKI #Enterprise

Enterprise-grade VPN server với web-based management. PKI certificates, user management, và security best practices.

**Learning Outcomes**: Enterprise security, PKI infrastructure, user management, audit trails, zero trust architecture.

---

### 5. Container Orchestration (Planning)
**Level**: Advanced | **Time**: 2+ hours | **Tags**: #Docker #Kubernetes #CI/CD

Modern deployment patterns với Kubernetes hoặc Docker Swarm. GitOps workflows và cloud-native practices.

---

## 🚀 Quick Start

### Beginners (New to DevOps):
1. **[Wake On LAN](Wake-On-LAN.md)** - Hardware automation foundation
2. **[ESXi VM Autostart](ESXi-VM-Autostart.md)** - Application automation
3. **[Port Forwarding](Port-Forwarding.md)** - Service exposure basics  
4. **[OpenVPN Server](VPN-Server-OpenVPN.md)** - Security & remote access
5. **Container Basics** - Modern deployment intro

### Experienced (Have some DevOps background):
1. **[Port Forwarding](Port-Forwarding.md)** - Network service exposure
2. **[OpenVPN Server](VPN-Server-OpenVPN.md)** - Enterprise security
3. **Infrastructure as Code** - Terraform/Ansible
4. **CI/CD Pipelines** - GitLab/Jenkins integration
5. **Advanced Monitoring** - Prometheus/Grafana stack

---

## 🛠️ Technical Stack

### Infrastructure:
- **Hypervisor**: VMware ESXi
- **OS**: Ubuntu 22.04 LTS
- **Networking**: ISP routers (VNPT, Viettel, FPT)
- **Storage**: Local ESXi datastores

### Tools & Technologies:
- **Automation**: Bash scripts, systemd services
- **Networking**: OpenVPN, Nginx reverse proxy
- **Containerization**: Docker, Docker Compose
- **Monitoring**: Built-in logging, health checks
- **Security**: PKI certificates, fail2ban, firewalls

### Development Environment:
- **Client OS**: macOS (primary), Windows (secondary)
- **Remote Access**: SSH, VPN, web interfaces
- **Version Control**: Git-based documentation
- **Testing**: Local labs, production validation

---

## 📊 Learning Roadmap

```
📍 START HERE
    ↓
🔧 Wake On LAN (Foundation)
    ↓ Remote server management
⚙️ ESXi VM Autostart (Intermediate)  
    ↓ Application automation
🌐 Port Forwarding (Intermediate)
    ↓ Service exposure
🔒 OpenVPN Server (Advanced)
    ↓ Enterprise security
🚀 Container Orchestration (Expert)
    ↓ Modern DevOps
☁️ Cloud Integration (Expert+)
```

---

## 💡 Key Learning Outcomes

### DevOps Fundamentals:
- **Infrastructure as Code**: Scripts, configuration management
- **Automation**: Service orchestration, CI/CD concepts  
- **Monitoring**: Logging, health checks, alerting
- **Security**: Network security, authentication, encryption

### Practical Skills:
- **Network Administration**: Routing, firewall, VPN
- **System Administration**: Linux services, systemd, Docker
- **Security Engineering**: PKI, certificates, access control
- **Production Operations**: Backup, disaster recovery, maintenance

### Real-world Experience:
- **Vietnamese ISP Integration**: Router configs, limitations
- **Home Lab Management**: Resource optimization, monitoring
- **Remote Development**: Secure access, productivity tools
- **Cost Optimization**: Efficient resource usage, power management

---

## 🔧 Prerequisites

### Hardware Requirements:
- **Server**: Intel/AMD x64 với ESXi compatibility
- **RAM**: 16GB+ (recommended 32GB)
- **Storage**: 500GB+ SSD/HDD
- **Network**: Gigabit ethernet, stable internet

### Software Knowledge:
- **Basic Linux**: Command line, file editing, services
- **Basic Networking**: IP addresses, ports, DNS
- **Basic Security**: Passwords, keys, basic encryption concepts

### Optional but Helpful:
- **Docker basics**: Container concepts
- **Git basics**: Version control
- **Network troubleshooting**: ping, curl, ssh

---

## 📖 How to Use This Repository

### 1. **Choose Your Learning Path**:
   - Beginners: Start with Wake On LAN
   - Experienced: Jump to Port Forwarding or VPN

### 2. **Follow Sequential Order**:
   - Each guide builds on previous knowledge
   - Cross-references help understand dependencies

### 3. **Hands-on Practice**:
   - Set up actual hardware/VMs
   - Test all configurations
   - Adapt scripts to your environment

### 4. **Safety First**:
   - Always backup configurations
   - Test in isolated environments first
   - Understand security implications

---

## 🔗 Cross-References

**Learning Flow**:
- [Wake On LAN](Wake-On-LAN.md) → [ESXi VM Autostart](ESXi-VM-Autostart.md) → [Port Forwarding](Port-Forwarding.md)
- [Port Forwarding](Port-Forwarding.md) → [OpenVPN Server](VPN-Server-OpenVPN.md) (security evolution)

**By Topic**:
- **Automation**: [Wake On LAN](Wake-On-LAN.md), [ESXi VM Autostart](ESXi-VM-Autostart.md)
- **Networking**: [Port Forwarding](Port-Forwarding.md), [OpenVPN Server](VPN-Server-OpenVPN.md)
- **Security**: [Port Forwarding](Port-Forwarding.md) (basic), [OpenVPN Server](VPN-Server-OpenVPN.md) (enterprise)

---

## 🤝 Contributing

Contributions welcome! Tập trung vào:

- **Vietnamese context**: ISP-specific configurations
- **DevOps learning**: Educational value và hands-on experience  
- **Production readiness**: Security, monitoring, best practices
- **Clear documentation**: Step-by-step instructions với explanations

---

## 📝 License

Documentation available for educational và personal use. Thích hợp cho DevOps learning, home lab setups, và skill development.

---

**🎯 Happy Learning & Building! 🚀**

