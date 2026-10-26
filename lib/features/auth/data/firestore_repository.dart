// lib/features/auth/data/firestore_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRepository<T> {
  final CollectionReference<Map<String, dynamic>> _collection;
  final T Function(String id, Map<String, dynamic> data) fromMap;
  final Map<String, dynamic> Function(T item) toMap;

  FirestoreRepository({
    required String collectionPath,
    required this.fromMap,
    required this.toMap,
  }) : _collection = FirebaseFirestore.instance.collection(collectionPath);

  // Chuyển một document thành T, null nếu document không tồn tại
  T? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : fromMap(doc.id, data);
  }

  // Đọc 1 đối tượng theo id
  Future<T?> get(String id) async {
    return _fromDoc(await _collection.doc(id).get());
  }

  // Theo dõi 1 đối tượng theo thời gian thực
  Stream<T?> watch(String id) {
    return _collection.doc(id).snapshots().map(_fromDoc);
  }

  // Theo dõi toàn bộ collection, có thể sắp xếp theo một trường
  Stream<List<T>> watchAll({String? orderBy, bool descending = false}) {
    Query<Map<String, dynamic>> query = _collection;
    if (orderBy != null) query = query.orderBy(orderBy, descending: descending);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => fromMap(doc.id, doc.data())).toList(),
        );
  }

  // Tạo mới hoặc ghi đè 1 đối tượng.
  // extraFields dùng cho các trường không nằm trong T, ví dụ createdAt = FieldValue.serverTimestamp()
  Future<void> set(String id, T item, {Map<String, dynamic> extraFields = const {}}) {
    return _collection.doc(id).set({...toMap(item), ...extraFields});
  }

  // Chỉ sửa một vài trường, không ghi đè cả document
  Future<void> update(String id, Map<String, dynamic> fields) {
    return _collection.doc(id).update(fields);
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
