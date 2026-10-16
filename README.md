# Vận tải nội bộ — Vue 3 / Node.js

**Demo JSON**: `npm install && npm run dev`, truy cập http://127.0.0.1:5173. Tài khoản demo `admin` / `vungoimora` (CHỈ LOCAL). Không public Internet.

## 3 vai trò chính
- **Admin**: quản trị tài khoản, CRUD dữ liệu hoạt động, kiểm soát nhật ký.
- **Kế toán (`accountant`)**: tạo/cập nhật phiếu nháp, công nợ, chốt kỳ; không được tự duyệt kỳ.
- **Giám đốc (`director`)**: xem Dashboard/báo cáo, xem danh sách kỳ, **duyệt kỳ đã chốt**; không sửa tiền. Admin tạo tài khoản giám đốc trong **Tài khoản & phân quyền → Thêm mới**.

**Luồng**: Kế toán tạo kỳ → thêm phiếu → chốt kỳ (locked) → Giám đốc duyệt (approved). Phiếu kỳ đã chốt/duyệt bị chặn sửa/xóa tại backend.

**CSDL**: `database/001_initial.sql` (PostgreSQL 15+, schema mục tiêu, có FK/unique/index/audit/import batches). **Bản demo vẫn ghi vào `server/data/local.json`**. Kiến trúc, tính toán, bảo mật, migration, sizing tại `docs/ARCHITECTURE.md`. SQL chưa tự được áp dụng vào API; cần phát triển repository adapter trước production.

---
# VẬN TẢI PRO — Vue 3 + Node.js + JSON Demo

Ứng dụng demo quản trị vận tải, điều phối, tài xế, kế toán nội bộ và báo cáo lọc chi tiết. **Chỉ dùng dữ liệu giả lập, không nhập CCCD/thông tin cá nhân thật trong demo.** Chạy local không cần PostgreSQL hoặc Docker.

## Khởi chạy (Node 20+)

```bash
npm install
npm run dev
```

Mở `http://127.0.0.1:5173`. API tại `http://127.0.0.1:8788` (Vite proxy `/api`).

Tài khoản DEMO: **admin** / **vungoimora**. Mật khẩu này chỉ phục vụ thử nghiệm, KHÔNG triển khai production. Tài khoản được tạo tự động lần đầu và mật khẩu được băm bcrypt. Có thể reset dữ liệu bằng `npm run reset:demo` (dừng server trước khi reset). Không đưa `server/data/local.json` lên Git.

## Cấu trúc

```
client/src/
  App.vue                    # Shell, navigation, forms, auth, CRUD actions
  components/
    StatCard.vue             # Thẻ chỉ số
    DataTable.vue            # Bảng sort, phân trang
    FilterBar.vue            # Bộ lọc tái sử dụng
  views/
    ReportsView.vue          # Báo cáo nhiều tab, lọc, xuất CSV
  services/api.js            # HTTP client, token handling
  style.css                  # Responsive UI
server/
  server.js                  # Express REST API quản lý, RBAC, audit
  routes/reports.routes.js   # GET /api/reports
  services/report.service.js # Tổng hợp và điều kiện lọc
  data/demo.json             # Dữ liệu mẫu
  data/local.json            # Dữ liệu đã ghi (tạo lúc chạy)
```

## Chức năng

- **Dashboard:** số lượng tài xế/xe/chuyến, doanh thu đối soát, trạng thái và chuyến theo tháng.
- **Xe:** loại xe, biển số, hãng, giấy tờ, bảo hiểm, tài xế liên kết, thêm/sửa/xóa mềm.
- **Tài xế:** quản lý hồ sơ, giấy phép, liên kết tài khoản.
- **Tuyến và chuyến:** tạo tuyến/chuyến, giao xe tài xế, tài xế nhận/từ chối, điều phối hoàn tất.
- **Đối soát:** tạo kỳ, lập/sửa phiếu trong kỳ nháp, khóa kỳ (không sửa khi đã khóa).
- **Công nợ:** tạo truy thu/thanh toán/điều chỉnh/hoàn tiền, hoàn chứng từ có dấu vết.
- **Báo cáo:** lọc từ-đến ngày, kỳ, tài xế, loại xe, trạng thái đối soát, trạng thái chuyến. 5 tab: phiếu đối soát, chi tiết chuyến, tổng hợp tài xế, tổng hợp kỳ, công nợ. Tổng tiền: doanh thu, phí app, khuyến mãi, bảo hiểm, tip, hoàn ví, truy thu, đã thanh toán. Xuất CSV UTF-8 có BOM dùng Excel. **Lưu ý các khoản chỉ là các trường số liệu gốc, không tự động suy diễn thành lương thực lĩnh.**
- **Bảng dữ liệu:** tìm kiếm trong danh sách, lọc ngày/trạng thái, sắp xếp từng cột, phân trang 12 dòng, xuất CSV.
- **RBAC:** admin toàn quyền; accountant quản lý kỳ/phiếu/chứng từ; dispatcher quản lý tài xế/xe/tuyến/chuyến; driver chỉ xem chuyến, đối soát, chứng từ của mình qua API.
- **Audit:** ghi nhận các thao tác thay đổi.

## API chính

| Method | Endpoint | Ý nghĩa |
|---|---|---|
| POST | `/api/login` | Đăng nhập, nhận JWT |
| GET | `/api/me` | Người dùng hiện tại |
| GET | `/api/dashboard` | Tổng quan |
| GET | `/api/reports` | Báo cáo lọc nhiều chiều |
| GET, POST, PUT, DELETE | `/api/vehicles` | Xe (PUT/DELETE sử dụng `/:id`) |
| GET, POST, PUT, DELETE | `/api/drivers` | Tài xế |
| GET, POST | `/api/routes` | Tuyến |
| GET, POST | `/api/bookings` | Chuyến |
| PATCH | `/api/bookings/:id/status` | Đổi trạng thái |
| GET, POST | `/api/periods` | Kỳ kế toán |
| PATCH | `/api/periods/:id/lock` | Khóa kỳ |
| GET, POST, DELETE | `/api/settlements` | Đối soát |
| GET, POST | `/api/ledger` | Chứng từ |
| POST | `/api/ledger/:id/reverse` | Hoàn chứng từ |
| GET, POST | `/api/users` | Tài khoản (admin) |
| PATCH | `/api/users/:id/active` | Khóa/mở tài khoản |
| GET | `/api/audit` | Audit (admin) |

Ví dụ:

```
GET /api/reports?from=2026-09-01&to=2026-10-31&vehicle_type=car&driver_id=<id>
```

## Triển khai thật: PostgreSQL

JSON là **single-process demo storage**, không phải giải pháp nhiều người truy cập đồng thời, sao lưu, phục hồi hay đảm bảo tính toàn vẹn tài chính. Khi triển khai thật nên dùng PostgreSQL (phù hợp hơn MySQL cho nhiều ràng buộc, báo cáo, transaction; SQLite có thể dùng cho prototype đơn máy).

Các bảng mục tiêu: `users`, `drivers`, `vehicles`, `routes`, `bookings`, `settlement_periods`, `settlements`, `ledger_entries`, `audit_logs`. Chuyển sang repository dùng PostgreSQL, khóa ngoại, UNIQUE, CHECK, transaction khi chốt kỳ và định khoản; dùng các cột tiền BIGINT (VND) để tránh lỗi float. Nên bổ sung: TLS + HTTPS, JWT trong HttpOnly/SameSite cookie kèm CSRF protection, secret lưu trong env/secret manager, đổi mật khẩu mặc định và chính sách mật khẩu mạnh, rate-limit phân tán, kiểm thử RBAC, khóa đăng nhập, audit bất biến, backup tự động, xác thực nghiệp vụ tài chính và test end-to-end.

## Phạm vi kiểm thử

Các file Node `server.js`, router và service báo cáo đã được kiểm tra cú pháp. Trong môi trường phát triển hiện tại npm install đã bị timeout, vì vậy chưa xác nhận build Vue và kiểm thử đầu-cuối trên Mac. Nếu gặp lỗi hãy gửi log `npm install`/`npm run dev` để khoanh đúng file.
