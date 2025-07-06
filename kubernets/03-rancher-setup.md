# Rancher Setup Guide

## Phương pháp triển khai Kubernetes

### Tư duy triển khai dự án trên K8s chuẩn format nhanh chóng

**Quy trình:**
1. **Nhu cầu** → 
2. **Sử dụng công cụ giao diện** → 
3. **Trích xuất file YAML** → 
4. **Nghiên cứu cú pháp, format, giá trị, template, các tùy chọn khác** → 
5. **Triển khai tương tự chuẩn format**

## Các công cụ quản lý K8s

1. **Command Line:** k9s
2. **Desktop:** Lens K8s
3. **Web Interface:** Rancher

## 1. Rancher Overview

Rancher là một công cụ giúp triển khai, quản lý và giám sát nhiều cụm Kubernetes trên các môi trường khác nhau, bao gồm cả on-premise và trên các nhà cung cấp dịch vụ đám mây như AWS, Azure, Google Cloud,...

### Rancher làm được gì?

- **Quản lý nhiều cụm Kubernetes**
- **Phân quyền mạnh mẽ** (based RBAC Kubernetes)
- **Hỗ trợ giám sát cụm Kubernetes**
- **Bảo mật tốt**

## 2. Cách cài đặt Rancher

### Lưu ý quan trọng
Trong thực tế, ổ nhớ của Rancher sẽ tách biệt ổ nhớ OS và ổ nhớ chứa các config của Rancher.

### Bước 1: Chuẩn bị ổ đĩa

Kiểm tra các ổ đĩa hiện có:
```bash
lsblk
```

Ví dụ output:
```
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0 63.9M  1 loop /snap/core20/2318
loop1                       7:1    0   87M  1 loop /snap/lxd/29351
loop2                       7:2    0 38.8M  1 loop /snap/snapd/21759
sda                         8:0    0   50G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0   48G  0 part
  └─ubuntu--vg-ubuntu--lv 253:0    0   24G  0 lvm  /
sdb                         8:16   0   50G  0 disk
sr0                        11:0    1 1024M  0 rom
```

### Bước 2: Format ổ đĩa cho Rancher

```bash
sudo mkfs.ext4 -m 0 /dev/sdb
```

### Bước 3: Mount ổ đĩa

Thêm vào `/etc/fstab`:
```bash
sudo echo "/dev/sdb /data ext4 defaults 0 0" | sudo tee -a /etc/fstab
```

Kiểm tra file fstab:
```bash
cat /etc/fstab
```

Mount ổ đĩa:
```bash
mount -a
```

Kiểm tra mount point:
```bash
df -h
```

### Bước 4: Cài đặt Docker và Docker Compose

Cài đặt Docker và Docker Compose cho VM.

### Bước 5: Triển khai Rancher với Docker Compose

Tạo thư mục cho Rancher:
```bash
mkdir -p /data/rancher
cd /data/rancher
```

Tạo file `docker-compose.yml`:
```yaml
version: '3'
services:
  rancher-server:
    image: rancher/rancher:v2.9.2
    container_name: rancher-server
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /data/rancher/data:/var/lib/rancher
    privileged: true
```

### Bước 6: Khởi động Rancher

```bash
docker-compose up -d
```

## 3. Kiểm tra tương thích version

### Lưu ý về version compatibility

Đặc biệt phải lưu ý tới version của Rancher và Kubernetes cluster:

Kiểm tra version của Kubernetes cluster:
```bash
kubectl get nodes
```

Output ví dụ:
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   19h   v1.30.14
k8s-master-2   Ready    control-plane   19h   v1.30.14
k8s-master-3   Ready    control-plane   19h   v1.30.14
```

**Quan trọng:** Vào Rancher matrix để check sự tương đồng về version giữa Rancher và Kubernetes cluster.

## 4. Truy cập Rancher

Sau khi cài đặt thành công, truy cập Rancher qua:
- **HTTP:** http://your-server-ip
- **HTTPS:** https://your-server-ip

## 5. Cấu trúc thư mục

```
/data/rancher/
├── docker-compose.yml
└── data/          # Persistent data của Rancher
```

## Lưu ý bảo mật

- Đảm bảo firewall được cấu hình đúng
- Sử dụng HTTPS trong production
- Backup dữ liệu Rancher thường xuyên
- Cập nhật Rancher theo lịch trình định kỳ 