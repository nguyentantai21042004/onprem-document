# Server Build Documentation 🏠🖥️

## Giới thiệu

Repository này chứa **documentation chi tiết** cho việc **tự build và quản lý server tại nhà**, đặc biệt hướng đến **học DevOps** và **home lab setup**. Mỗi file Markdown là một hướng dẫn từng bước cụ thể, dễ theo dõi và thực hành.

## 🎯 Mục tiêu

- **Học DevOps thực tế**: Từ cơ bản đến nâng cao
- **Home Lab Setup**: Xây dựng environment học tập tại nhà
- **Infrastructure Automation**: Tự động hóa từ hardware đến application
- **Best Practices**: Áp dụng các phương pháp hay nhất trong thực tế

## 📚 Danh sách hướng dẫn

### 🔌 Infrastructure & Automation

1. **[Wake On LAN](WakeOnLans.md)** - *Foundation Level*
   - Remote power management cho ESXi server
   - Client-side automation scripts (macOS/Windows)
   - Network protocols và troubleshooting

2. **[ESXi VM Autostart](ESXi-Autostart.md)** - *Intermediate Level*
   - Tự động khởi động VMs sau khi server boot
   - Service automation trong Linux VMs
   - Complete automation workflow

3. **[Port Forwarding & Network Services](ForwardPort.md)** - *Intermediate Level*
   - Expose internal services ra external network
   - Router configuration và security best practices
   - Production-ready service deployment

### 🚀 Sắp tới (Roadmap)

4. **Container Orchestration** - Docker & Kubernetes setup
5. **Monitoring & Logging** - Prometheus, Grafana, ELK stack
6. **CI/CD Pipeline** - GitLab/Jenkins automation
7. **Network Services** - VPN, DNS, reverse proxy
8. **Backup & Recovery** - Automated backup strategies

## 🎓 Learning Path

### Cho người mới bắt đầu:
```
Wake On LAN → ESXi Autostart → Port Forwarding → Container Basics → Monitoring
```

### Cho người có kinh nghiệm:
```
Port Forwarding → CI/CD → Infrastructure as Code → Advanced Monitoring
```

## 🛠️ Công nghệ sử dụng

**Ảo hóa**: VMware ESXi  
**Hệ điều hành**: Linux (Ubuntu/CentOS), macOS, Windows  
**Tự động hóa**: Bash scripts, PowerShell, Python  
**Mạng**: Wake On LAN, SSH, TCP/IP  
**Công cụ DevOps**: Git, Docker, systemd  

## 💡 Đặc điểm nổi bật

### ✅ **Thực tiễn & Thực hành**
- Mỗi hướng dẫn đều có ví dụ thực tế
- Có quy trình kiểm thử và xử lý sự cố
- Script sẵn sàng cho môi trường production

### ✅ **Định hướng DevOps**
- Tập trung vào tự động hóa và best practices
- Tiếp cận Infrastructure as Code
- Tương thích đa nền tảng

### ✅ **Thân thiện cho người mới**
- Giải thích từ cơ bản đến nâng cao
- Hướng dẫn từng bước
- Có phần xử lý sự cố

## 🔧 Yêu cầu

**Phần cứng**:
- Server/Workstation hỗ trợ ảo hóa
- Hạ tầng mạng (router, switch)
- Tối thiểu 16GB RAM, 100GB lưu trữ

**Phần mềm**:
- VMware ESXi (có bản miễn phí)
- Máy client chạy macOS/Windows
- Kiến thức cơ bản về dòng lệnh

## 📖 Cách sử dụng

1. **Clone repository**:
   ```bash
   git clone https://gitlab.com/tantai-server/server-build-docs.git
   cd server-build-docs
   ```

2. **Bắt đầu từ Wake On LAN**: Nền tảng cho toàn bộ quá trình tự động hóa

3. **Làm theo thứ tự**: Mỗi hướng dẫn xây dựng dựa trên kiến thức trước đó

4. **Thực hành & Thử nghiệm**: Tùy chỉnh script theo môi trường của bạn

Vui lòng tạo issue hoặc gửi merge request nếu có góp ý.

## 📞 Hỗ trợ & Cộng đồng

- **Issues**: Sử dụng GitLab Issues cho câu hỏi/lỗi
- **Thảo luận**: Chia sẻ kinh nghiệm và best practices
- **Học tập**: Phù hợp cho sinh viên DevOps và người đam mê home lab

## 🏷️ Tags

`#DevOps` `#HomeLab` `#ESXi` `#Automation` `#Infrastructure` `#WakeOnLAN` `#Vietnamese` `#SelfHosted` `#Learning`

## 📄 Giấy phép

MIT License - Miễn phí sử dụng cho mục đích giáo dục và cá nhân.

---

## 🎯 Bắt đầu nhanh

**Mới học DevOps?** Bắt đầu tại đây: [Hướng dẫn Wake On LAN](WakeOnLans.md)  
**Đã có kiến thức cơ bản?** Chuyển sang: [Hướng dẫn ESXi Autostart](ESXi-Autostart.md)  
**Muốn tự động hóa toàn diện?** Làm theo toàn bộ lộ trình học!

**Chúc bạn học tập vui vẻ! 🚀**
