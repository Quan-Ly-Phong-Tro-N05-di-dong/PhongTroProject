// lib/core/base/repository.dart
import 'base_entity.dart';
import 'entity_registry.dart';

/// Kho dữ liệu tổng quát (CRUD) cho MỌI đối tượng `extends BaseEntity<String>`.
/// Viết 1 lần, dùng cho Room, Contact, Appointment, Review, Report...
/// Mặc định lưu trong bộ nhớ. Khi chạy với Firestore thì gán [onSaved] / [onRemoved]
/// để mỗi thay đổi được ghi lên server, và [idGenerator] để id không bị trùng giữa các máy.
class Repository<T extends BaseEntity<String>> {
  final Map<String, T> _items = {};
  int _seq = 0;

  /// Nếu gán, [nextId] dùng hàm này (vd: id do Firestore sinh) thay vì đếm '1', '2', ...
  String Function()? idGenerator;

  /// Được gọi sau mỗi lần [add] / [update] (dùng để ghi lên Firestore).
  void Function(T entity)? onSaved;

  /// Được gọi sau khi [remove] xóa được một phần tử (dùng để xóa trên Firestore).
  void Function(String id)? onRemoved;

  /// Tên bảng của [T] (lấy từ EntityRegistry).
  String get name => EntityRegistry.nameOf<T>();

  int get count => _items.length;

  /// Sinh id kế tiếp chưa bị dùng: '1', '2', ... (hoặc từ [idGenerator] nếu có).
  String nextId() {
    final generate = idGenerator;
    if (generate != null) return generate();
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
    onSaved?.call(entity);
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
    onSaved?.call(entity);
    return entity;
  }

  bool remove(String id) {
    final removed = _items.remove(id) != null;
    if (removed) onRemoved?.call(id);
    return removed;
  }

  /// Thay toàn bộ dữ liệu bằng [items] (dữ liệu vừa tải từ server).
  /// Không gọi [onSaved] / [onRemoved] để khỏi ghi ngược lại lên server.
  void replaceAll(Iterable<T> items) {
    _items
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
  }

  List<Map<String, dynamic>> exportJson() =>
      _items.values.map((e) => e.toJson()).toList();

  /// Nạp dữ liệu từ JSON, dùng EntityRegistry để dựng đúng kiểu [T].
  void importJson(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      add(EntityRegistry.fromJson<T>(row));
    }
  }
}
