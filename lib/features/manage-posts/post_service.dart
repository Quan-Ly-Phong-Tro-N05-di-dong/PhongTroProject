import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;

import 'post_model.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  Stream<List<RentalPost>> watchPosts({
    required String role,
    required int tab,
  }) {
    Query<Map<String, dynamic>> query = _posts;
    if (role == 'landlord' && tab == 1) {
      final uid = _requireUser().uid;
      query = query.where('ownerId', isEqualTo: uid);
    } else if (role == 'admin' && tab == 1) {
      query = query.where('reviewStatus', isEqualTo: 'pending');
    } else {
      query = query
          .where('reviewStatus', isEqualTo: 'approved')
          .where('isHidden', isEqualTo: false);
    }
    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs.map(RentalPost.fromDocument).toList();
      posts.sort((a, b) {
        final comparison = (b.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
      return posts;
    });
  }

  Stream<RentalPost?> watchPost(String id) {
    return _posts.doc(id).snapshots().map((document) {
      return document.exists ? RentalPost.fromDocument(document) : null;
    });
  }

  Future<String> createPost({
    required String title,
    required String address,
    required double price,
    required double area,
    required String amenities,
    required String contact,
    required List<String> imageUrls,
  }) async {
    final draft = PostDraft(
      title: title,
      address: address,
      price: price,
      area: area,
      amenities: amenities,
      contact: contact,
      imageUrls: imageUrls,
    );
    draft.validate();
    final user = _requireUser();
    final reference = _posts.doc();

    await _db.runTransaction((transaction) async {
      await _checkRole(transaction, user.uid, 'landlord');
      transaction.set(reference, {
        ...draft.toFields(),
        'ownerId': user.uid,
        'availability': 'available',
        'isHidden': false,
        'reviewStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return reference.id;
  }

  Future<bool> updatePost({
    required RentalPost post,
    required PostDraft draft,
  }) async {
    draft.validate();
    final user = _requireUser();
    final reference = _posts.doc(post.id);

    return _db.runTransaction<bool>((transaction) async {
      await _checkRole(transaction, user.uid, 'landlord');
      final current = await transaction.get(reference);
      _checkOwnerAndVersion(current, post, user.uid);

      if (draft.sameContentAs(RentalPost.fromDocument(current))) {
        return false;
      }

      transaction.update(reference, {
        ...draft.toFields(),
        'reviewStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> setAvailability(RentalPost post, String value) async {
    if (!availabilityLabels.containsKey(value)) {
      throw const PostException('Trạng thái phòng không hợp lệ.');
    }
    await _ownerUpdate(post, {'availability': value});
  }

  Future<void> setHidden(RentalPost post, bool value) async {
    await _ownerUpdate(post, {'isHidden': value});
  }

  Future<void> _ownerUpdate(
    RentalPost post,
    Map<String, dynamic> fields,
  ) async {
    final user = _requireUser();
    final reference = _posts.doc(post.id);
    await _db.runTransaction((transaction) async {
      await _checkRole(transaction, user.uid, 'landlord');
      final current = await transaction.get(reference);
      _checkOwnerAndVersion(current, post, user.uid);
      transaction.update(reference, {
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deletePost(RentalPost post) async {
    final user = _requireUser();
    final reference = _posts.doc(post.id);
    await _db.runTransaction((transaction) async {
      await _checkRole(transaction, user.uid, 'landlord');
      final current = await transaction.get(reference);
      _checkOwnerAndVersion(current, post, user.uid);
      transaction.delete(reference);
    });
  }

  Future<void> reviewPost({
    required String postId,
    required String decision,
    required Timestamp expectedUpdatedAt,
  }) async {
    if (!['approved', 'rejected'].contains(decision)) {
      throw const PostException('Kết quả duyệt không hợp lệ.');
    }
    final user = _requireUser();
    final reference = _posts.doc(postId);
    await _db.runTransaction((transaction) async {
      await _checkRole(transaction, user.uid, 'admin');
      final current = await transaction.get(reference);
      _checkVersion(current, expectedUpdatedAt);
      if (current.data()?['reviewStatus'] != 'pending') {
        throw const PostException('Bài đăng đã được xử lý.');
      }
      transaction.update(reference, {
        'reviewStatus': decision,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PostException('Bạn cần đăng nhập.');
    }
    return user;
  }

  Future<void> _checkRole(
    Transaction transaction,
    String uid,
    String requiredRole,
  ) async {
    final snapshot = await transaction.get(_db.collection('users').doc(uid));
    final profile = snapshot.data();
    if (profile == null) {
      throw const PostException('Không tìm thấy hồ sơ tài khoản.');
    }
    if (profile['disabled'] != false) {
      throw const PostException('Tài khoản bị khóa hoặc hồ sơ chưa hợp lệ.');
    }
    if (profile['role'] != requiredRole) {
      throw const PostException('Tài khoản không có quyền thực hiện thao tác.');
    }
  }

  void _checkOwnerAndVersion(
    DocumentSnapshot<Map<String, dynamic>> current,
    RentalPost expected,
    String uid,
  ) {
    _checkVersion(current, expected.updatedAt);
    if (current.data()?['ownerId'] != uid) {
      throw const PostException('Bạn chỉ được quản lý bài đăng của mình.');
    }
  }

  void _checkVersion(
    DocumentSnapshot<Map<String, dynamic>> current,
    Timestamp? expectedUpdatedAt,
  ) {
    if (!current.exists) {
      throw const PostException('Bài đăng không còn tồn tại.');
    }
    if (expectedUpdatedAt == null ||
        current.data()?['updatedAt'] != expectedUpdatedAt) {
      throw const PostException(
        'Bài đã thay đổi. Hãy mở lại bài và kiểm tra trước khi thao tác.',
      );
    }
  }

  static String errorText(Object error) {
    if (error is PostException) return error.message;
    if (error is firebase_core.FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Không có quyền truy cập. Kiểm tra quyền tài khoản và '
              'Rules posts đã được deploy cho đúng dự án Firebase.';
        case 'unavailable':
          return 'Không kết nối được Firebase. Kiểm tra mạng của máy ảo.';
        case 'unauthenticated':
          return 'Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.';
        case 'aborted':
          return 'Dữ liệu đang thay đổi. Hãy tải lại và thử lại.';
        default:
          return '${error.code}: ${error.message ?? 'Lỗi Firebase'}';
      }
    }
    return error.toString();
  }
}
