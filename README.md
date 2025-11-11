# Tài liệu Hệ thống On-Premise (Documentation Hub)

Repository này dùng để lưu trữ và tổ chức tài liệu triển khai/vận hành hệ thống on‑premise. Mục đích của repo là tập hợp các hướng dẫn, cấu hình tham chiếu và mẫu cấu hình. Repo không mô tả lộ trình học hay giáo trình theo tuần/giai đoạn.

## Phạm vi tài liệu
- Infrastructure: phần cứng, mạng, ESXi, tự động khởi động VM, WOL, v.v.
- Services: VPN, cơ sở dữ liệu (MongoDB, PostgreSQL), container registry, monitoring.
- Kubernetes: cluster setup, workloads, ingress/networking, storage, quản trị.
- CI/CD: Jenkins, pipelines, mẫu cấu hình CI/CD.
- Configuration templates: mẫu YAML/Kubernetes/Jenkins sẵn dùng.

## Cấu trúc thư mục
- `infrastructure/`: Hướng dẫn hạ tầng on‑premise (mạng, ESXi, WOL, v.v.). Xem `infrastructure/index.md`.
- `services/`: Hướng dẫn triển khai các dịch vụ cốt lõi. Xem `services/index.md`.
- `kubernetes/`: Kiến thức và thực hành về cụm Kubernetes. Xem `kubernetes/index.md`.
- `cicd/`: Thiết lập và quản trị CI/CD (Jenkins, pipelines). Xem `cicd/index.md`.
- `config-templates/`: Bộ mẫu cấu hình sẵn dùng (Kubernetes manifests, Jenkins pipeline, secrets).
- `scripts/`: Script tiện ích phục vụ triển khai/vận hành.

## Cách sử dụng
1. Chọn chủ đề và mở file `index.md` tương ứng trong thư mục đó để xem tổng quan và điều hướng.
2. Làm theo các hướng dẫn chi tiết trong từng file `.md` hoặc sử dụng mẫu tại `config-templates/`.
3. Điều chỉnh thông số theo môi trường của bạn trước khi áp dụng.

## Đóng góp
- Chấp nhận PR cải thiện nội dung, bổ sung ví dụ và mẫu cấu hình.
- Tuân thủ phong cách viết Markdown nhất quán, tập trung ngắn gọn, thực dụng.

## Ghi chú
- Tài liệu có thể được cập nhật theo thời gian để phản ánh thực tế triển khai và best practices.

