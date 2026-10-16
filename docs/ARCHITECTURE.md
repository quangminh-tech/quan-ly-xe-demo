# Kiến trúc vận tải nội bộ — phương án mở rộng

## 1. Phân vai trò (RBAC)

| Tác vụ | Admin | Kế toán | Giám đốc |
|---|---|---|---|
| Tài khoản, phân quyền, khoá tài khoản | Toàn quyền | Không | Không |
| Danh mục tài xế, xe, tuyến | CRUD | Xem thông tin công việc | Xem số liệu tổng hợp |
| Chuyến và điều phối | CRUD | Xem phục vụ đối soát | Xem tổng hợp |
| Nhập phiếu đối soát, công nợ | Giám sát/có quyền can thiệp theo chính sách | CRUD khi chưa khóa | Chỉ xem |
| Chốt kỳ (draft -> locked) | Có quyền theo chính sách | Thực hiện | Không |
| Duyệt kỳ (locked -> approved) | Không | Không | Thực hiện |
| Báo cáo tài chính | Xem | Xem/đối chiếu | Xem, duyệt |
| Nhật ký thao tác | Xem | Không | Có thể cấp quyền kiểm toán riêng |

Chỉ nên dùng 3 vai trò chính trong giao diện. Giữ dispatcher/driver ở backend để phát triển app tài xế sau. Giám đốc không được sửa trực tiếp số tiền; kế toán không được tự phê duyệt kỳ mình chốt. Admin có quyền kỹ thuật không đồng nghĩa được tự ý thay đổi dữ liệu tài chính đã duyệt. Đảm bảo kiểm tra quyền trên **server** với mọi API.

## 2. Các liên kết dữ liệu

- `users.role_code -> roles.code`, tài khoản tài xế `users.driver_id -> drivers.id`.
- `vehicles.driver_id -> drivers.id` (chỉ là lái xe hiện tại; muốn lịch sử điều chuyển thì cần thêm `vehicle_assignments` có from/to).
- `bookings.route_id -> routes.id`, `bookings.driver_id -> drivers.id`, `bookings.vehicle_id -> vehicles.id`.
- `settlements.period_id -> settlement_periods.id`, `settlements.driver_id -> drivers.id`, `settlements.vehicle_id -> vehicles.id`.
- `ledger_entries.driver_id -> drivers.id`, `ledger_entries.settlement_id -> settlements.id`.
- `import_rows.batch_id -> import_batches.id`; giữ bản gốc và checksum tránh import trùng.
- `audit_logs.actor_id -> users.id`, lưu ai đổi gì vào lúc nào (nên bổ sung trước/sau có che dữ liệu cá nhân).

Không xóa vật lý các đối tượng đã được tham chiếu; sử dụng `deleted_at` + cấm thay đổi sau khi duyệt. Hạn chế `CASCADE DELETE` cho dữ liệu kế toán. Ràng buộc liên kết phải ở PostgreSQL, không chỉ trong Vue.

## 3. Tính toán tiền — chưa chốt quy tắc phải phân tách

- `gross_revenue`: doanh số gốc của kỳ, **không đồng nhất với tiền công thực lĩnh**.
- `app_fee`, `card_fee`, `insurance_fee`, `promo`, `tips`, `wallet_return`: các cấu phần được ghi riêng, có thể có chiều tiền khác nhau tùy hợp đồng.
- `receivable` (phải thu), `payment` (đã thu), `adjustment` (điều chỉnh), `refund` (hoàn): phải quy định chiều hạch toán có dấu, tính theo **chứng từ**, không lấy số dư ví cộng vào doanh thu.
- Công thức minh họa chỉ khi được duyệt: `tạm tính = doanh thu đủ điều kiện - phí áp dụng + tip + trợ cấp - khấu trừ`; tuyệt đối không tự động cộng/trừ khuyến mãi khi chưa biết bên chịu phí.
- Tránh truy thu hai lần: mã chứng từ unique + idempotency key khi import/thanh toán. Một kỳ một tài xế có tối đa một phiếu snapshot (`UNIQUE(period_id,driver_id)`), chi tiết điều chỉnh ghi chứng từ riêng.
- Báo cáo cho giám đốc cần phân biệt **tạm tính / đã chốt / đã duyệt**, không cộng kỳ còn nháp vào kết quả được công bố.
- Tiền VND lưu `BIGINT` và kiểm tra tổng theo kỳ ở backend/DB transaction; không dùng floating point JavaScript làm chuẩn quyết toán.

## 4. Triển khai theo từng cấp

**Giai đoạn demo (hiện tại):** Vue/Vite -> Node/Express -> `server/data/local.json`. 1 tiến trình API, test chức năng, dữ liệu giả, không để public Internet. JSON không hỗ trợ FK/transaction chuẩn; cần backup và kiểm tra trùng thủ công.

**Giai đoạn vận hành (đề xuất):**

```text
Internet / nội bộ
    |
 HTTPS / Reverse Proxy (Caddy/Nginx), WAF tùy mức độ
    |
 Vue 3 build tĩnh + Node Express REST API (2 instances khi cần)
    |
 Service / Repository / Transaction boundary
    |
 PostgreSQL 16 (managed, private network, backup + PITR)
    |
 Object Storage (hóa đơn/bằng lái) + Queue worker (import Excel/xuất báo cáo)
```

- Ban đầu một VPS đủ với reverse proxy + API + PostgreSQL, nhưng phải backup PostgreSQL ra vị trí khác. Với dữ liệu CCCD, nên chọn database managed trên private network, mã hóa và hạn chế người truy cập DB.
- Khi tăng truy cập: API stateless, dùng load balancer; Redis cho rate limit/session/revocation nếu cần; job queue cho nhập Excel và xuất PDF; cân nhắc read replica chỉ khi đo thấy truy vấn phân tích ảnh hưởng hệ thống chính.
- Không cần microservices/Kubernetes ngay. Bảo vệ DB bằng firewall, user ứng dụng quyền tối thiểu; tách tài khoản migration khỏi tài khoản truy vấn.
- Index theo cột lọc, `EXPLAIN ANALYZE`, pagination trên SQL, không lấy toàn bộ dữ liệu lên Vue. Báo cáo lớn dùng materialized views hoặc bảng tổng hợp theo ngày sau khi đã đo tải.
- RPO mục tiêu ví dụ <= 1 giờ, RTO <= 4 giờ cần kiểm nghiệm khôi phục định kỳ; backup hàng ngày và PITR tối thiểu 7-30 ngày tùy ngân sách/chính sách.

## 5. Bảo mật và tính nhất quán

1. Không đưa mật khẩu demo lên môi trường thật; tạo admin qua biến môi trường một lần rồi ép đổi mật khẩu. Argon2id hoặc bcrypt có cấu hình phù hợp.
2. Cookie HttpOnly/Secure/SameSite, HTTPS bắt buộc; session ngắn + refresh rotation hoặc phiên server-side; chống CSRF với cookie.
3. RBAC kiểm tra trên server; mọi API lấy `actor_id` từ phiên, không từ request body. Giám đốc read-only trừ endpoint duyệt.
4. Mask SĐT/CCCD/GPLX trên báo cáo giám đốc; mã hóa thuộc tính nhạy cảm, hạn chế export, ghi nhật ký truy cập dữ liệu nhạy cảm.
5. Duyệt kỳ bằng transaction: `SELECT ... FOR UPDATE`, kiểm tra trạng thái `locked`, ghi `approved_at/by`, ghi audit trong cùng transaction. Nếu cần phân tách nhiệm vụ nghiêm ngặt, không cho cùng user tạo/chốt và duyệt.
6. Khi sửa khoản đã duyệt, mở kỳ điều chỉnh/chứng từ đảo và duyệt lại, không sửa record cũ. Backup immutable/offsite, secrets manager, scan dependency và log giám sát.
7. API input validation (Zod/Joi), SQL query có parameter, giới hạn upload Excel, kiểm tra MIME/size; tránh log token và thông tin cá nhân.

## 6. Ước tính quy mô và hướng chi phí

Giả sử 100-500 tài xế, 10-30 nhân viên, 10-50 nghìn chuyến/tháng: PostgreSQL với index hợp lý đủ đáp ứng trên máy chủ tầm nhỏ, nhưng cần đo tải trước khi cam kết. Khởi đầu có thể dùng API 2 vCPU/2-4 GB RAM, DB 2 vCPU/4 GB RAM, SSD 40-100 GB, backup riêng; đó là **dự trù**, không phải benchmark hay báo giá nhà cung cấp. Nếu file chứng từ lớn, chuyển sang object storage.

## 7. Lộ trình migration từ JSON

1. Chuẩn hóa bản ghi hiện có, kiểm tra trùng số điện thoại/biển số, phát hiện foreign key thiếu và thời gian sai.
2. Tạo DB bằng `database/001_initial.sql`; thử import vào staging trước.
3. Viết adapter repository cho PostgreSQL với transaction; để frontend dùng đúng API contract cũ.
4. Đối chiếu tổng số bản ghi, tổng theo kỳ/driver và checksum nguồn với JSON, kiểm tra quyền, chạy kiểm thử.
5. Sao lưu JSON, đóng ghi, nhập chênh lệch, kiểm tra đối soát, chuyển traffic sang PostgreSQL, giữ phương án rollback.

**Lưu ý:** File SQL là schema mục tiêu, chưa được kết nối vào backend JSON demo. Chưa thể coi là migration đầy đủ cho dữ liệu hiện tại nếu chưa có script đối chiếu trường và mã hóa CCCD.
