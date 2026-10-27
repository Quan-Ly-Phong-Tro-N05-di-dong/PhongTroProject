// lib/core/base/entity_registry.dart
import 'base_entity.dart';

/// Hàm dựng đối tượng kiểu [T] từ JSON.
typedef FromJson<T> = T Function(Map<String, dynamic> json);

/// CÂU 2 – Tổng quát hóa bằng kiểu `Type` (Class của Dart).
///
/// Mỗi model đăng ký 1 lần: "kiểu T -> cách dựng từ JSON + tên bảng".
/// Sau đó code chung chỉ cần viết `EntityRegistry.fromJson<T>(json)`
/// mà không phải `if (T == Contact) ... else if (T == Review) ...`.
class EntityRegistry {
  EntityRegistry._();

  static final Map<Type, FromJson<BaseEntity>> _builders = {};
  static final Map<Type, String> _names = {};

  /// Đăng ký model [T]. Gọi lại nhiều lần vẫn an toàn (ghi đè).
  static void register<T extends BaseEntity>(
    FromJson<T> fromJson, {
    required String name,
  }) {
    _builders[T] = fromJson;
    _names[T] = name;
  }

  static bool isRegistered<T extends BaseEntity>() => _builders.containsKey(T);

  /// Dựng đối tượng kiểu [T] từ JSON.
  static T fromJson<T extends BaseEntity>(Map<String, dynamic> json) {
    final builder = _builders[T];
    if (builder == null) {
      throw StateError('$T chưa được đăng ký trong EntityRegistry');
    }
    return builder(json) as T;
  }

  /// Dựng theo `Type` lấy lúc chạy (vd từ `entity.runtimeType`).
  static BaseEntity fromJsonOfType(Type type, Map<String, dynamic> json) {
    final builder = _builders[type];
    if (builder == null) {
      throw StateError('$type chưa được đăng ký trong EntityRegistry');
    }
    return builder(json);
  }

  /// Tên bảng/collection của model [T].
  static String nameOf<T extends BaseEntity>() => nameOfType(T);

  static String nameOfType(Type type) => _names[type] ?? type.toString();

  /// Danh sách các kiểu đã đăng ký.
  static List<Type> get registeredTypes => List.unmodifiable(_builders.keys);
}
