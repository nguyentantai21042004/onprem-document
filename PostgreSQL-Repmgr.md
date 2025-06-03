# Hướng dẫn Setup PostgreSQL + Repmgr

## Giới thiệu

File này hướng dẫn chi tiết cách thiết lập và cấu hình PostgreSQL kết hợp với Repmgr để tạo một hệ thống cơ sở dữ liệu có tính sẵn sàng cao (High Availability). 

Repmgr là một công cụ mã nguồn mở được thiết kế để đơn giản hóa việc quản lý và giám sát các cluster PostgreSQL replication. Với hướng dẫn này, bạn sẽ học cách:

- Cài đặt và cấu hình PostgreSQL
- Thiết lập Repmgr cho high availability
- Cấu hình replication giữa các node
- Giám sát và quản lý cluster
- Xử lý failover tự động

Hướng dẫn này phù hợp cho các DevOps engineer và database administrator muốn xây dựng một hệ thống database PostgreSQL ổn định và có khả năng phục hồi cao.
