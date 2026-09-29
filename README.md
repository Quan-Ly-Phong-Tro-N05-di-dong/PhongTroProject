# Ứng Dụng Quản Lý & Tìm Kiếm Phòng Trọ

Hệ thống hỗ trợ tìm kiếm, quản lý bài đăng và kết nối thuê phòng trọ, được phát triển trên nền tảng Flutter theo kiến trúc Feature-First.

---

## Phân Chia Module & Trách Nhiệm

Dự án áp dụng mô hình Feature-First. Mỗi thành viên chịu trách nhiệm độc lập trên một module tương ứng trong thư mục `lib/features/`:

| Module | Đường dẫn thư mục | Chức năng chính | Người phụ trách |
| :--- | :--- | :--- | :--- |
| **Auth** | `lib/features/auth/` | Xác thực người dùng, phân quyền (Chủ trọ / Khách thuê) | Tên Thành Viên 1 |
| **Home Catalog** | `lib/features/home_catalog/` | Khám phá, tìm kiếm, bộ lọc & gợi ý phòng trọ | Tên Thành Viên 2 |
| **Manage Posts** | `lib/features/manage_posts/` | Tạo, chỉnh sửa, xóa và quản lý trạng thái tin đăng | Tên Thành Viên 3 |
| **Contact** | `lib/features/contact/` | Liên hệ trực tiếp, nhắn tin & đặt lịch hẹn xem phòng | Tên Thành Viên 4 |

---

## Cấu Trúc Thư Mục Chuẩn

```text
lib/
├── core/                  # Cấu hình dùng chung (Network, Theme, Constants, Widgets dùng chung)
│   ├── routes/            # Cấu hình App Route chung
│   └── main_screen.dart   # Shell điều hướng chính (BottomNavigationBar)
├── features/              # Chia theo module tính năng độc lập
│   ├── auth/
│   ├── contact/
│   ├── home_catalog/
│   └── manage_posts/
├── main.dart              # Entry point của ứng dụng
└── routers.dart
```

[!IMPORTANT]
### Lưu Ý Quan Trọng
1. Tuyệt đối không tự ý chỉnh sửa `lib/main.dart` và `lib/core/routes/`. Mọi thay đổi cấu hình toàn cục phải thảo luận trước với cả nhóm.
2. Test code chạy được trước khi push
3. Nên kiểm tra và pull code mới nhất (nếu có) trước khi bắt đầu code :D