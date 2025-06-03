# Hướng dẫn cài đặt MongoDB Replica Set

## Giới thiệu

File này cung cấp hướng dẫn chi tiết từng bước để cài đặt và cấu hình MongoDB Replica Set. Bạn sẽ học cách thiết lập một cụm MongoDB với khả năng sao chép dữ liệu, đảm bảo tính sẵn sàng cao (High Availability) và khả năng chịu lỗi (Fault Tolerance) cho hệ thống database của mình.

## 1. MongoDB Replica Set là gì?

MongoDB Replica Set là một nhóm các MongoDB instance (mongod processes) duy trì cùng một tập dữ liệu. Replica Set cung cấp tính dự phòng và khả năng sẵn sàng cao, là nền tảng cho tất cả các triển khai production của MongoDB.

### Thành phần chính:

- **Primary Node**: Node chính nhận tất cả các thao tác ghi (write operations)
- **Secondary Nodes**: Các node phụ sao chép dữ liệu từ Primary node
- **Arbiter** (tùy chọn): Node không chứa dữ liệu, chỉ tham gia bình chọn trong quá trình election

### Lợi ích của Replica Set:

1. **High Availability (Tính sẵn sàng cao)**
   - Tự động failover khi Primary node gặp sự cố
   - Ứng dụng có thể tiếp tục hoạt động mà không bị gián đoạn

2. **Data Redundancy (Dự phòng dữ liệu)**
   - Dữ liệu được sao chép trên nhiều server
   - Bảo vệ khỏi mất mất dữ liệu do hardware failure

3. **Read Scalability (Khả năng mở rộng đọc)**
   - Có thể đọc dữ liệu từ Secondary nodes
   - Phân tán load đọc trên nhiều node

4. **Disaster Recovery (Khôi phục thảm họa)**
   - Backup tự động thông qua replication
   - Có thể restore từ bất kỳ Secondary node nào

### Cách hoạt động:

- **Oplog (Operations Log)**: Primary ghi tất cả các thay đổi vào oplog
- **Replication**: Secondary nodes đọc và áp dúng các operations từ oplog
- **Election**: Khi Primary down, các Secondary sẽ bầu chọn Primary mới
- **Heartbeat**: Các node liên tục gửi heartbeat để kiểm tra tình trạng
