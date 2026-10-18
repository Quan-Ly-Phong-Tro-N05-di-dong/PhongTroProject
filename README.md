# Ứng Dụng Quản Lý & Tìm Kiếm Phòng Trọ

Hệ thống hỗ trợ tìm kiếm, quản lý bài đăng và kết nối thuê phòng trọ, được phát triển trên nền tảng Flutter theo kiến trúc Feature-First.

---

## Phân Chia Module & Trách Nhiệm

Dự án áp dụng mô hình Feature-First. Mỗi thành viên chịu trách nhiệm độc lập trên một module tương ứng trong thư mục `lib/features/`:

| Module           | Đường dẫn thư mục            | Chức năng chính                                        | Người phụ trách  |
| :--------------- | :--------------------------- | :----------------------------------------------------- | :--------------- |
| **Auth**         | `lib/features/auth/`         | Xác thực người dùng, phân quyền (Chủ trọ / Khách thuê) | Tên Thành Viên 1 |
| **Home Catalog** | `lib/features/home_catalog/` | Khám phá, tìm kiếm, bộ lọc & gợi ý phòng trọ           | Tên Thành Viên 2 |
| **Manage Posts** | `lib/features/manage_posts/` | Tạo, chỉnh sửa, xóa và quản lý trạng thái tin đăng     | Tên Thành Viên 3 |
| **Contact**      | `lib/features/contact/`      | Liên hệ trực tiếp, nhắn tin & đặt lịch hẹn xem phòng   | Tên Thành Viên 4 |

---

## Cấu Trúc Thư Mục Chuẩn

```text
lib/
├── core/                  # Cấu hình dùng chung (Network, Theme, Constants, Widgets dùng chung)
│   ├── base/              # BaseEntity<ID>, EntityRegistry, Repository<T> (Generics dùng chung)
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

---

## Đối Tượng Generics Dùng Chung (Generics & Kế Thừa)

### Câu 1 – `BaseEntity<ID>` (`lib/core/base/`)

Mọi đối tượng dữ liệu của dự án (phòng, liên hệ, lịch hẹn, đánh giá, báo cáo, ...) đều có chung id, ngày tạo, cách chuyển sang JSON và cách so sánh. Thay vì mỗi module tự viết lại, nhóm dùng một lớp generic duy nhất:

```dart
abstract class BaseEntity<ID extends Object> {
  final ID id;                  // kiểu khóa chính do lớp con quyết định (String, int, ...)
  final DateTime? createdAt;
  const BaseEntity({required this.id, this.createdAt});
  Map<String, dynamic> toJson();   // lớp con tự cài đặt
}
```

| File                   | Vai trò                                                                                         |
| :--------------------- | :---------------------------------------------------------------------------------------------- |
| `base_entity.dart`     | `BaseEntity<ID>`: id, createdAt, `toJson()`, ghi đè `==`, `hashCode`, `toString`                |
| `entity_registry.dart` | `EntityRegistry`: đăng ký "kiểu `T` → cách dựng từ JSON + tên bảng", dùng `Type`                |
| `repository.dart`      | `Repository<T extends BaseEntity<String>>`: CRUD tổng quát (thêm, tìm, sửa, xóa, xuất/nạp JSON) |

### Câu 2 – Kế thừa và tổng quát hóa

| Đối tượng     | Kế thừa              | Vị trí                                        | Ghi chú                                                     |
| :------------ | :------------------- | :-------------------------------------------- | :---------------------------------------------------------- |
| `RoomItem`    | `BaseEntity<String>` | `features/home_catalog/models/room_item.dart` | Đối tượng có sẵn, trước đây nằm trong `counter_screen.dart` |
| `Contact`     | `BaseEntity<String>` | `features/contact/models/contact.dart`        | Tin nhắn liên hệ chủ trọ                                    |
| `Appointment` | `BaseEntity<String>` | `features/contact/models/appointment.dart`    | Lịch hẹn, có luồng trạng thái                               |
| `Review`      | `BaseEntity<String>` | `features/contact/models/review.dart`         | Đánh giá 1-5 sao, `RatingSummary`                           |
| `Report`      | `BaseEntity<String>` | `features/contact/models/report.dart`         | Báo cáo vi phạm cho admin xử lý                             |

**Dùng `Object` class (dart:core)** – `BaseEntity` ghi đè các thành viên của `Object`:

- `==` và `hashCode`: hai đối tượng **cùng kiểu và cùng id** là bằng nhau (không so sánh từng trường).
- `toString()`: in `TênLớp({json})` để debug.
- `runtimeType`: cho biết lớp thật của đối tượng lúc chạy (vd `Contact`, `Review`).

**Dùng "Class class"** – trong Dart, đối tượng mô tả một lớp lúc chạy là `Type` (lấy bằng `runtimeType` hoặc viết `T` trong hàm generic). `EntityRegistry` dùng `Type` làm khóa nên code chung viết được như sau, không cần chuỗi `if (T == Contact) ... else if (T == Review) ...`:

```dart
T clone<T extends BaseEntity>(T e) => EntityRegistry.fromJson<T>(e.toJson());
```

> Lưu ý: `Class` trong thư viện `vm_service` (link trong đề bài) là API mô tả lớp thông qua VM Service, dùng cho công cụ debug và cần kết nối tới Dart VM đang chạy. Nó không dùng được trong app Flutter thông thường, nên nhóm dùng `Type`/`runtimeType` làm phần tương ứng.

### Quy ước cho cả nhóm

1. Model mới viết là `class Xxx extends BaseEntity<String>`, cài đặt `toJson()` (gộp `...baseJson()`) và `factory Xxx.fromJson(...)`.
2. Viết hàm `registerXxxModels()` gọi `EntityRegistry.register<Xxx>(Xxx.fromJson, name: '...')`. Hiện có `registerRoomModels()` và `registerContactModels()`. Cần thêm lời gọi vào `main()` khi chạy app (theo quy tắc phía dưới thì phải thống nhất với nhóm trước khi sửa `main.dart`).
3. Lưu và truy vấn dữ liệu qua `Repository<T>`, không tự viết lại danh sách + hàm CRUD trong từng module.
4. Id của các đối tượng là `String` (giống `RoomItem.id`); các trường tham chiếu như `roomId`, `ownerId` cũng là `String`.

### Chạy thử

```bash
flutter pub get
flutter test test/generics_test.dart      # kiểm tra tự động
dart run tool/demo_generics.dart          # in kết quả demo ra màn hình
```

### Ảnh chụp màn hình kết quả

![Kết quả flutter test](assets/generics_test.png)

![Kết quả chạy demo](assets/generics_demo.png)

[!IMPORTANT]

### Lưu Ý Quan Trọng

1. Tuyệt đối không tự ý chỉnh sửa `lib/main.dart` và `lib/core/routes/`. Mọi thay đổi cấu hình toàn cục phải thảo luận trước với cả nhóm.
2. Test code chạy được trước khi push
3. Nên kiểm tra và pull code mới nhất (nếu có) trước khi bắt đầu code :D

## Giao diện demo ứng dụng

![Giao diện trang chủ và tìm kiếm](assets/home.png)
