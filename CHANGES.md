# Phiên bản giao diện tinh gọn

- Loại bỏ nhãn công nghệ (JSON Local Mode, framework) khỏi giao diện. Dữ liệu vẫn ở `server/data/local.json`.
- Danh mục: chỉ tìm kiếm, thêm mới, danh sách và thao tác phù hợp; bộ lọc chỉ hiện ở màn hình có ý nghĩa.
- Thêm API PUT và xóa mềm cho tuyến, chỉnh sửa/xóa mềm chuyến đang chờ; PUT kỳ kế toán đang mở.
- Kế toán và admin mới xem báo cáo tài chính; dispatcher không có quyền báo cáo tài chính.
- Giữ giao diện CRUD cho tài xế/xe; các chứng từ đã chốt chỉ xử lý theo quy trình chốt/hoàn (không xóa tùy tiện).
- Tài khoản vẫn có role admin, accountant, dispatcher, driver. Backend kiểm tra quyền, không chỉ ẩn menu.
- Đây là bản local demo, chưa kiểm thử đầy đủ browser build và không phù hợp phơi public khi dùng mật khẩu demo.
