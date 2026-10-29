// lib/features/contact/services/contact_firebase.dart
//
// Nối module "Tương tác & phản hồi" với Firebase:
//  - người dùng hiện tại lấy từ AuthService (tài khoản đăng nhập thật),
//  - lịch hẹn / tin nhắn / đánh giá / báo cáo được lưu và đồng bộ realtime trên Firestore,
//  - danh sách phòng lấy từ bài đăng thật (collection `posts`, chỉ bài đã duyệt và không ẩn).
//
// Không cần sửa firestore.rules: các collection của module (contacts, appointments, reviews,
// reports, contact_profiles) dùng luật chung "ai cũng đọc được, đăng nhập mới ghi được".
//
// Cách dùng: gọi ContactFirebase.instance.attach() một lần trong main() sau Firebase.initializeApp.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/base/base_entity.dart';
import '../../../core/base/repository.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/app_user.dart' as auth;
import '../../home_catalog/models/room_item.dart';
import '../../manage-posts/post_model.dart';
import '../models/contact_models.dart';
import 'interaction_service.dart';

class ContactFirebase {
  ContactFirebase._();

  static final ContactFirebase instance = ContactFirebase._();

  /// Người dùng tạm khi chưa đăng nhập (màn hình của module đã có chặn đăng nhập).
  static const DemoUser _guest = DemoUser(
    id: 'guest',
    name: 'Khách',
    phone: '',
    role: UserRole.tenant,
  );

  // Dữ liệu ai cũng xem được (phòng, đánh giá, tên người dùng): nghe từ lúc mở app.
  final List<StreamSubscription<dynamic>> _publicSubs = [];
  // Dữ liệu riêng của người đăng nhập (cuộc trò chuyện, lịch hẹn, báo cáo).
  final List<StreamSubscription<dynamic>> _userSubs = [];

  bool _attached = false;
  String? _userKey;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  InteractionService get _s => InteractionService.instance;

  /// Chuyển module sang dữ liệu thật. Gọi một lần lúc khởi động app.
  void attach() {
    if (_attached) return;
    _attached = true;

    final s = _s;
    s.startRemoteMode();
    s.switchUser(_guest);
    s.idGenerator = _newId;
    s.onLockUser = _lockUser;

    _bind(s.contacts, 'contacts');
    _bind(s.appointments, 'appointments');
    _bind(s.reviews, 'reviews');
    _bind(s.reports, 'reports');

    _listenPublic(s);

    final current = AuthService.instance.currentUser;
    current.addListener(() => _onUser(current.value));
    _onUser(current.value);
  }

  // ---------------------------------------------------------------------------
  // Người dùng đăng nhập / đăng xuất
  // ---------------------------------------------------------------------------

  void _onUser(auth.AppUser? user) {
    final key = user == null
        ? null
        : '${user.id}|${user.role.name}|${user.fullName}|${user.phone}';
    if (key == _userKey) return;
    _userKey = key;

    for (final sub in _userSubs) {
      sub.cancel();
    }
    _userSubs.clear();

    final s = _s;
    s.contacts.replaceAll(const []);
    s.appointments.replaceAll(const []);
    s.reports.replaceAll(const []);

    if (user == null) {
      s.switchUser(_guest);
      return;
    }

    final me = DemoUser(
      id: user.id,
      name: user.fullName,
      phone: user.phone ?? '',
      role: _mapRole(user.role),
    );
    s.switchUser(me);
    _publishProfile(me);
    _listenPrivate(s, me);
  }

  UserRole _mapRole(auth.UserRole role) => switch (role) {
    auth.UserRole.admin => UserRole.admin,
    auth.UserRole.landlord => UserRole.owner,
    auth.UserRole.tenant => UserRole.tenant,
  };

  /// Người khác không đọc được hồ sơ `users` của mình, nên mỗi người đăng "danh thiếp"
  /// (tên, vai trò) vào contact_profiles để hiện tên trong cuộc trò chuyện, đánh giá...
  /// Số điện thoại chỉ đăng với chủ trọ (người thuê cần gọi chủ trọ).
  void _publishProfile(DemoUser me) {
    _write('contact_profiles', me.id, {
      'name': me.name,
      'role': me.role.name,
      'phone': me.role == UserRole.owner ? me.phone : '',
    });
  }

  /// Admin xác nhận báo cáo người dùng -> khóa tài khoản thật (users/{id}.disabled = true).
  void _lockUser(String userId) {
    unawaited(
      AuthService.instance.setDisabled(userId, true).catchError((Object e) {
        _log('Không khóa được tài khoản $userId: $e');
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Ghi lên Firestore (mọi thay đổi của Repository tự được ghi)
  // ---------------------------------------------------------------------------

  void _bind<T extends BaseEntity<String>>(
    Repository<T> repo,
    String collection,
  ) {
    repo.idGenerator = _newId;
    repo.onSaved = (entity) => _write(collection, entity.id, entity.toJson());
    repo.onRemoved = (id) => _delete(collection, id);
  }

  /// Id ngẫu nhiên do Firestore sinh, không trùng giữa các máy.
  String _newId() => _db.collection('ids').doc().id;

  void _write(String collection, String id, Map<String, dynamic> data) {
    unawaited(
      _db.collection(collection).doc(id).set(data).catchError((Object e) {
        _log('Không lưu được $collection/$id: $e');
      }),
    );
  }

  void _delete(String collection, String id) {
    unawaited(
      _db.collection(collection).doc(id).delete().catchError((Object e) {
        _log('Không xóa được $collection/$id: $e');
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Nghe dữ liệu công khai
  // ---------------------------------------------------------------------------

  void _listenPublic(InteractionService s) {
    // Phòng = bài đăng đã duyệt và không ẩn (cùng truy vấn với module Quản lý bài đăng).
    _publicSubs.add(
      _db
          .collection('posts')
          .where('reviewStatus', isEqualTo: 'approved')
          .where('isHidden', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            final ids = <String>{};
            for (final doc in snapshot.docs) {
              try {
                final post = RentalPost.fromDocument(doc);
                ids.add(post.id);
                s.rooms[post.id] = _toRoom(post);
                s.roomOwner[post.id] = post.ownerId;
              } catch (e) {
                _log('Bỏ qua bài đăng ${doc.id}: $e');
              }
            }
            s.rooms.removeWhere((id, _) => !ids.contains(id));
            s.refresh();
          }, onError: (Object e) => _log('Không đọc được posts: $e')),
    );

    // Đánh giá: ai cũng xem được (hiện điểm trung bình của phòng).
    _publicSubs.add(
      _watch<Review>(
        label: 'reviews',
        query: _db.collection('reviews'),
        parse: Review.fromJson,
        apply: (items) => s.reviews.replaceAll(items),
      ),
    );

    // Bài đăng bị admin xác nhận vi phạm -> ẩn khỏi danh sách phòng của module.
    _publicSubs.add(
      _db
          .collection('reports')
          .where('status', isEqualTo: 'resolved')
          .snapshots()
          .listen((snapshot) {
            final hidden = <String>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final target = data['targetId'];
              if (data['targetType'] == ReportTarget.room.name &&
                  target is String) {
                hidden.add(target);
              }
            }
            s.hiddenRoomIds
              ..clear()
              ..addAll(hidden);
            s.refresh();
          }, onError: (Object e) => _log('Không đọc được reports: $e')),
    );

    // Tên người dùng để hiển thị.
    _publicSubs.add(
      _db.collection('contact_profiles').snapshots().listen((snapshot) {
        for (final doc in snapshot.docs) {
          if (doc.id == s.currentUser.id) continue;
          final data = doc.data();
          s.users[doc.id] = DemoUser(
            id: doc.id,
            name: (data['name'] as String?) ?? 'Người dùng',
            phone: (data['phone'] as String?) ?? '',
            role: _roleByName(data['role'] as String?),
          );
        }
        s.refresh();
      }, onError: (Object e) => _log('Không đọc được contact_profiles: $e')),
    );
  }

  RoomItem _toRoom(RentalPost post) => RoomItem(
    id: post.id,
    title: post.title,
    address: post.address,
    price: post.price / 1000000, // bài đăng lưu VNĐ, RoomItem tính theo triệu
    area: post.area,
    imageUrl: post.imageUrls.isEmpty ? '' : post.imageUrls.first,
    createdAt: post.createdAt?.toDate(),
  );

  UserRole _roleByName(String? name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.tenant,
  );

  // ---------------------------------------------------------------------------
  // Nghe dữ liệu riêng của người đăng nhập
  // ---------------------------------------------------------------------------

  void _listenPrivate(InteractionService s, DemoUser me) {
    final uid = me.id;
    final isAdmin = me.role == UserRole.admin;
    // Chỉ lấy cuộc trò chuyện / lịch hẹn mà mình là người thuê hoặc chủ trọ.
    final mine = Filter.or(
      Filter('tenantId', isEqualTo: uid),
      Filter('ownerId', isEqualTo: uid),
    );

    if (!isAdmin) {
      _userSubs.add(
        _watch<Contact>(
          label: 'contacts',
          query: _db.collection('contacts').where(mine),
          parse: Contact.fromJson,
          apply: (items) {
            s.contacts.replaceAll(items);
            for (final c in items) {
              s.roomOwner.putIfAbsent(c.roomId, () => c.ownerId);
            }
          },
        ),
      );
    }

    _userSubs.add(
      _watch<Appointment>(
        label: 'appointments',
        query: isAdmin
            ? _db.collection('appointments')
            : _db.collection('appointments').where(mine),
        parse: Appointment.fromJson,
        apply: (items) {
          s.appointments.replaceAll(items);
          for (final a in items) {
            s.roomOwner.putIfAbsent(a.roomId, () => a.ownerId);
          }
        },
      ),
    );

    // Admin thấy mọi báo cáo; người khác chỉ thấy báo cáo mình đã gửi.
    _userSubs.add(
      _watch<Report>(
        label: 'reports',
        query: isAdmin
            ? _db.collection('reports')
            : _db.collection('reports').where('reporterId', isEqualTo: uid),
        parse: Report.fromJson,
        apply: (items) => s.reports.replaceAll(items),
      ),
    );
  }

  /// Nghe một truy vấn, đổi từng document thành đối tượng [T] rồi nạp vào Repository.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _watch<T extends BaseEntity<String>>({
    required String label,
    required Query<Map<String, dynamic>> query,
    required T Function(Map<String, dynamic> json) parse,
    required void Function(List<T> items) apply,
  }) {
    return query.snapshots().listen(
      (snapshot) {
        final items = <T>[];
        for (final doc in snapshot.docs) {
          try {
            items.add(parse({...doc.data(), 'id': doc.id}));
          } catch (e) {
            _log('Bỏ qua $label/${doc.id}: $e');
          }
        }
        apply(items);
        _s.refresh();
      },
      onError: (Object e) => _log('Không đọc được $label: $e'),
    );
  }

  void _log(String message) => debugPrint('[ContactFirebase] $message');
}