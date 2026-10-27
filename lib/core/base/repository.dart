// lib/core/base/repository.dart
import 'base_entity.dart';
import 'entity_registry.dart';

/// Kho dữ liệu tổng quát (CRUD) cho MỌI đối tượng `extends BaseEntity<String>`.
/// Viết 1 lần, dùng cho Room, Contact, Appointment, Review, Report...
/// Hiện lưu trong bộ nhớ; sau này đổi sang API/SQLite chỉ cần sửa lớp này.
class Repository<T extends BaseEntity<String>> {
  final Map<String, T> _items = {};
  int _seq = 0;

  /// Tên bảng của [T] (lấy từ EntityRegistry).
  String get name => EntityRegistry.nameOf<T>();

  int get count => _items.length;

  /// Sinh id kế tiếp chưa bị dùng: '1', '2', ...
  String nextId() {
    do {
      _seq++;
    } while (_items.containsKey('$_seq'));
    return '$_seq';
  }

  T add(T entity) {
    if (_items.containsKey(entity.id)) {
      throw ArgumentError('$name đã có id "${entity.id}"');
    }
    _items[entity.id] = entity;
    return entity;
  }

  T? findById(String id) => _items[id];

  List<T> findAll({bool Function(T item)? where}) {
    final all = _items.values;
    return (where == null ? all : all.where(where)).toList();
  }

  T update(T entity) {
    if (!_items.containsKey(entity.id)) {
      throw StateError('$name không có id "${entity.id}" để cập nhật');
    }
    _items[entity.id] = entity;
    return entity;
  }

  bool remove(String id) => _items.remove(id) != null;

  List<Map<String, dynamic>> exportJson() =>
      _items.values.map((e) => e.toJson()).toList();

  /// Nạp dữ liệu từ JSON, dùng EntityRegistry để dựng đúng kiểu [T].
  void importJson(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      add(EntityRegistry.fromJson<T>(row));
    }
  }
}
