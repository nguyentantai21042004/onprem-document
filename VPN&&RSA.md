# VPN (Virtual Private Network) và Hệ thống PKI

## 1. Tổng quan về VPN

VPN (Virtual Private Network) là công nghệ tạo kết nối mạng riêng ảo, cho phép:
- Kết nối an toàn qua Internet công cộng
- Mã hóa dữ liệu truyền nhận
- Ẩn danh IP thật của người dùng
- Truy cập tài nguyên nội bộ từ xa

VPN sử dụng hạ tầng PKI (Public Key Infrastructure) để đảm bảo tính bảo mật và xác thực.

## 2. Cơ chế hoạt động của VPN

### a) Các thành phần chính
- VPN Client: Phần mềm VPN trên thiết bị người dùng
- VPN Server: Máy chủ VPN tiếp nhận kết nối
- Chứng chỉ số: Dùng để xác thực client và server
- Kênh truyền mã hóa: Đường hầm VPN được mã hóa

### b) Quy trình kết nối
1. Client khởi tạo kết nối tới VPN Server
2. Hai bên trao đổi chứng chỉ để xác thực lẫn nhau
3. Thiết lập đường hầm mã hóa
4. Truyền nhận dữ liệu qua đường hầm an toàn

## 3. Hệ thống PKI trong VPN

PKI cung cấp nền tảng bảo mật cho VPN thông qua:

### a) Các thành phần PKI chính
- CA (Certificate Authority): Cấp và quản lý chứng chỉ
- Chứng chỉ số: Xác thực danh tính server/client
- Cặp khóa công khai/riêng tư: Dùng để mã hóa

### b) Vai trò của PKI
- Xác thực hai chiều giữa client và server
- Mã hóa dữ liệu truyền nhận
- Đảm bảo tính toàn vẹn thông tin
- Quản lý quyền truy cập VPN

## 4. Triển khai OpenVPN với Easy-RSA

### Bước 1: Cài đặt phần mềm
