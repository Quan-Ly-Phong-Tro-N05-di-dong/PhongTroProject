// lib/core/base/base_entity.dart

/// CÂU 1 – Đối tượng Generics dùng chung cho mọi thực thể trong dự án.
///
/// [ID] là kiểu của khóa chính (String, int, ...). Mọi model của nhóm
/// (RoomItem, Contact, Appointment, Review, Report, ...) đều
/// `extends BaseEntity<ID>` nên có chung: id, ngày tạo, toJson, ==, hashCode, toString.
///
/// Lớp này tận dụng `Object` của dart:core:
///  - ghi đè `==` và `hashCode`  -> 2 đối tượng cùng kiểu + cùng id là "bằng nhau"
///  - ghi đè `toString`          -> in ra gọn: Tên lớp({json})
///  - dùng `runtimeType` (kiểu `Type`) để biết lớp thật của đối tượng lúc chạy
abstract class BaseEntity<ID extends Object> {
  final ID id;
  final DateTime? createdAt;

  /// Constructor `const` để các lớp con (vd RoomItem) vẫn khai báo được dữ liệu `const`.
  const BaseEntity({required this.id, this.createdAt});

  /// Mỗi lớp con tự mô tả cách chuyển sang Map (dùng cho lưu trữ / gọi API).
  Map<String, dynamic> toJson();

  /// Các trường chung, lớp con gộp vào toJson(): `{...baseJson(), 'title': title}`.
  Map<String, dynamic> baseJson() => {
    'id': id,
    'createdAt': createdAt?.toIso8601String(),
  };

  /// Đọc ngày giờ từ JSON (null nếu không có).
  static DateTime? parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Kiểu thật của đối tượng, ví dụ `Contact`, `RoomItem`.
  Type get entityType => runtimeType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BaseEntity &&
          other.runtimeType == runtimeType &&
          other.id == id);

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => '$runtimeType(${toJson()})';
}
