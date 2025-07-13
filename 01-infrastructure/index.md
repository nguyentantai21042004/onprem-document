# Infrastructure Documentation

## 📋 Tổng quan

Folder này chứa tất cả tài liệu về **infrastructure foundation** - nền tảng hạ tầng cho toàn bộ hệ thống server on-premise. Đây là Phase 1 trong roadmap xây dựng server, bao gồm các components cơ bản nhất để có thể remote management và network connectivity.

### 🎯 Mục tiêu Phase 1

- **Remote Power Management**: Có thể bật/tắt server từ xa
- **Virtual Machine Management**: Tự động khởi động VMs và services
- **Network Foundation**: Hiểu và cấu hình networking trong ESXi
- **External Access**: Expose services ra internet một cách an toàn

---

## 📚 Nội dung

### 1. 🔌 [Wake-on-LAN](wake-on-lan.md)
**Level**: Foundation | **Time**: 30 phút | **Tags**: #Hardware #Remote #Automation

Wake-on-LAN setup với client-side automation scripts. Foundation cho remote server management và DevOps automation workflow.

#### Nội dung chính:
- ESXi server configuration
- macOS/Windows automation scripts
- Testing và validation
- Troubleshooting

#### Kết quả học được:
- Remote control fundamentals
- Network protocols understanding
- Automation script development
- Infrastructure as code basics

---

### 2. 🚀 [ESXi VM Autostart](esxi-vm-autostart.md)
**Level**: Intermediate | **Time**: 45 phút | **Tags**: #ESXi #Automation #SystemD

Complete automation từ hardware boot đến application services. ESXi VM autostart configuration và service automation trong Linux VMs.

#### Nội dung chính:
- ESXi autostart configuration
- Systemd service creation
- Script templates và examples
- Monitoring và logging

#### Kết quả học được:
- Service orchestration
- Systemd management
- Dependency handling
- Reliability engineering

---

### 3. 🌐 [Networking Knowledge](networking.md)
**Level**: Intermediate | **Time**: 1 giờ | **Tags**: #Networking #ESXi #Theory

Kiến thức lý thuyết và thực hành về networking trong môi trường ESXi. Virtual switches, port groups, VLAN configuration.

#### Nội dung chính:
- Physical NIC (vmnic) concepts
- Virtual Switch architecture
- Port Groups và policies
- Network troubleshooting

#### Kết quả học được:
- Virtual networking understanding
- Security policy implementation
- Performance optimization
- Network troubleshooting skills

---

### 4. 🔗 [Port Forwarding](port-forwarding.md)
**Level**: Intermediate | **Time**: 1 giờ | **Tags**: #Networking #Security #Production

Router configuration, service exposure, và production deployment với reverse proxy. Hands-on với Vietnamese ISP routers.

#### Nội dung chính:
- Router configuration
- Service setup trong VMs
- Security best practices
- Performance optimization

#### Kết quả học được:
- Network security understanding
- Reverse proxy implementation
- SSL/TLS configuration
- Production deployment skills

---

## 🔄 Learning Path

### Beginners (Mới bắt đầu DevOps):
```
1. Wake-on-LAN         → Remote management foundation
2. ESXi VM Autostart   → Service automation
3. Networking          → Network understanding
4. Port Forwarding     → External access
```

### Experienced (Có kinh nghiệm):
```
1. Networking          → Architecture understanding
2. Port Forwarding     → Production deployment
3. Wake-on-LAN         → Automation enhancement
4. ESXi VM Autostart   → Service orchestration
```

---

## 🔗 Dependencies

### Prerequisites:
- **Hardware**: ESXi server với static IP
- **Network**: Stable internet connection
- **Client**: macOS/Linux/Windows với SSH client
- **Knowledge**: Basic Linux command line

### External Dependencies:
- **ESXi Server**: VMware ESXi 6.7+
- **Router**: Vietnamese ISP router hoặc custom router
- **VMs**: Ubuntu 22.04 LTS VMs

---

## 📊 Validation Checklist

Sau khi hoàn thành Phase 1, bạn nên có thể:

- [ ] **Remote Power**: Bật/tắt ESXi server từ xa
- [ ] **VM Management**: VMs tự động khởi động sau reboot
- [ ] **Service Automation**: Services tự động start trong VMs
- [ ] **Network Understanding**: Hiểu ESXi networking concepts
- [ ] **External Access**: Truy cập services từ internet
- [ ] **Security**: Implement basic security measures

---

## 🚀 Next Phase

Sau khi hoàn thành Infrastructure Phase, tiến tới:

### Phase 2: [Core Services](../02-services/)
- **VPN Server**: Secure remote access
- **Databases**: MongoDB & PostgreSQL HA
- **Harbor Registry**: Container image storage
- **Monitoring**: Prometheus & Grafana stack

---

## 🔧 Tools & Technologies

### Infrastructure Tools:
- **VMware ESXi**: Virtualization platform
- **Ubuntu 22.04**: Guest OS cho VMs
- **SSH**: Remote access
- **Wake-on-LAN**: Remote power management

### Networking Tools:
- **Nginx**: Reverse proxy
- **UFW**: Firewall management
- **iptables**: Network filtering
- **OpenSSL**: SSL/TLS certificates

### Automation Tools:
- **Systemd**: Service management
- **Bash**: Shell scripting
- **Cron**: Task scheduling
- **Git**: Version control

---

## 📈 Key Metrics

### Success Metrics:
- **Uptime**: 99%+ server availability
- **Boot Time**: <5 minutes từ WOL đến services ready
- **Response Time**: <2 seconds cho web services
- **Security**: Zero unauthorized access attempts

### Monitoring Points:
- **Server Status**: Online/offline monitoring
- **Service Health**: Critical services status
- **Network Performance**: Bandwidth và latency
- **Security Events**: Failed login attempts

---

## 🔍 Troubleshooting

### Common Issues:
- **WOL not working**: Check router và ESXi settings
- **Services not starting**: Review systemd logs
- **Network connectivity**: Verify ESXi networking
- **Port forwarding**: Check router và firewall rules

### Debug Commands:
```bash
# Check server status
ping esxi-server-ip

# Check service status
systemctl status service-name

# Check network ports
netstat -tlnp | grep port-number

# Check firewall rules
ufw status verbose
```

---

## 📝 Best Practices

### Security:
1. **Change default ports** cho SSH và web services
2. **Use strong passwords** cho tất cả accounts
3. **Enable firewall** với restrictive rules
4. **Monitor access logs** for suspicious activity

### Performance:
1. **Optimize VM resources** theo actual usage
2. **Use static IPs** cho critical services
3. **Monitor resource usage** thường xuyên
4. **Plan for scaling** từ đầu

### Automation:
1. **Script everything** có thể automate
2. **Use version control** cho scripts
3. **Test automation** trong isolated environment
4. **Document dependencies** rõ ràng

---

## 🎯 Learning Outcomes

Sau khi hoàn thành Infrastructure Phase, bạn sẽ có:

### Technical Skills:
- **Remote server management**
- **Virtual networking configuration**
- **Service automation**
- **Security implementation**

### DevOps Skills:
- **Infrastructure as Code** concepts
- **Automation thinking**
- **Problem-solving approach**
- **Documentation practices**

### Practical Experience:
- **Real server management**
- **Production-like environment**
- **Network troubleshooting**
- **Security hardening**

---

## 📚 Additional Resources

### Official Documentation:
- [VMware ESXi Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Systemd Manual](https://www.freedesktop.org/software/systemd/man/)

### Community Resources:
- [r/homelab](https://reddit.com/r/homelab) - Community support
- [VMware Communities](https://communities.vmware.com/) - ESXi help
- [Ubuntu Forums](https://ubuntuforums.org/) - Ubuntu support

### Tools:
- [Putty](https://putty.org/) - SSH client cho Windows
- [iTerm2](https://iterm2.com/) - Terminal cho macOS
- [Homebrew](https://brew.sh/) - Package manager cho macOS

---

**🎉 Happy Infrastructure Building! 🚀**

> "Infrastructure is the foundation of all great systems. Build it right, and everything else becomes possible." 