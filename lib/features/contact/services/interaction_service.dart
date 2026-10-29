// lib/features/contact/services/interaction_service.dart
//
// Nơi xử lý nghiệp vụ của module "Tương tác & phản hồi người dùng":
// liên hệ, đặt lịch hẹn, đánh giá, báo cáo.
//
// - Dữ liệu lưu trong bộ nhớ bằng Repository<T> (dùng chung của nhóm).
//   Sau này có backend chỉ cần thay phần lưu trữ, giao diện không đổi.
// - Người dùng hiện tại và danh sách phòng đang là DỮ LIỆU GIẢ để module chạy
//   độc lập. Khi module Đăng nhập và Quản lý bài đăng xong thì thay bằng API của họ
//   (xem registerRoom, switchUser, onHideRoom, onLockUser).
import 'package:flutter/foundation.dart';

import '../../../core/base/base_entity.dart';
import '../../../core/base/repository.dart';
import '../../home_catalog/models/room_item.dart';
import '../models/contact_models.dart';

/// 3 vai trò của hệ thống.
enum UserRole { tenant, owner, admin }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.tenant => 'Người thuê',
    UserRole.owner => 'Chủ trọ',
    UserRole.admin => 'Admin',
  };
}

extension ReportTargetLabel on ReportTarget {
  String get label => switch (this) {
    ReportTarget.room => 'Bài đăng',
    ReportTarget.user => 'Người dùng',
    ReportTarget.review => 'Đánh giá',
  };

  /// Hành động admin thực hiện khi xác nhận báo cáo vi phạm.
  String get actionLabel => switch (this) {
    ReportTarget.room => 'Ẩn bài',
    ReportTarget.user => 'Khóa tài khoản',
    ReportTarget.review => 'Xóa đánh giá',
  };
}

/// Người dùng giả (thay bằng thông tin từ module Đăng nhập & phân quyền).
class DemoUser {
  final String id;
  final String name;
  final String phone;
  final UserRole role;

  const DemoUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });
}

class DemoUsers {
  DemoUsers._();

  static const DemoUser tenant = DemoUser(
    id: 'u_tenant',
    name: 'Trần Minh Anh',
    phone: '0987 654 321',
    role: UserRole.tenant,
  );
  static const DemoUser tenant2 = DemoUser(
    id: 'u_tenant2',
    name: 'Phạm Quốc Bảo',
    phone: '0932 111 222',
    role: UserRole.tenant,
  );
  static const DemoUser ownerA = DemoUser(
    id: 'u_owner_a',
    name: 'Nguyễn Văn A',
    phone: '0901 234 567',
    role: UserRole.owner,
  );
  static const DemoUser ownerB = DemoUser(
    id: 'u_owner_b',
    name: 'Lê Thị B',
    phone: '0912 345 678',
    role: UserRole.owner,
  );
  static const DemoUser admin = DemoUser(
    id: 'u_admin',
    name: 'Quản trị viên',
    phone: '',
    role: UserRole.admin,
  );

  static const List<DemoUser> all = [tenant, tenant2, ownerA, ownerB, admin];

  static DemoUser defaultFor(UserRole role) => switch (role) {
    UserRole.tenant => tenant,
    UserRole.owner => ownerA,
    UserRole.admin => admin,
  };
}

/// Đổi lỗi (ArgumentError / StateError) thành câu tiếng Việt để hiện cho người dùng.
String friendlyError(Object error) {
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return error.toString();
}

class InteractionService extends ChangeNotifier {
  InteractionService({DateTime Function()? clock, bool seed = true})
    : _clock = clock ?? DateTime.now {
    registerRoomModels();
    registerContactModels();
    for (final user in DemoUsers.all) {
      users[user.id] = user;
    }
    _seedRooms();
    if (seed) _seedActivity();
  }

  /// Bản dùng chung cho cả ứng dụng. Chỉ gán lại trong test (để có dữ liệu sạch).
  static InteractionService instance = InteractionService();

  /// Hai lịch hẹn của cùng một phòng không được cách nhau dưới khoảng này.
  static const Duration slot = Duration(hours: 1);

  /// Giờ nhận lịch xem phòng: 07:00 - 21:00.
  static const int openHour = 7;
  static const int closeHour = 21;

  final DateTime Function() _clock;

  final Repository<Contact> contacts = Repository<Contact>();
  final Repository<Appointment> appointments = Repository<Appointment>();
  final Repository<Review> reviews = Repository<Review>();
  final Repository<Report> reports = Repository<Report>();

  /// Phòng giả (sau này lấy từ module Quản lý bài đăng).
  final Map<String, RoomItem> rooms = {};

  /// roomId -> id chủ trọ (sau này lấy từ ownerId của bài đăng).
  final Map<String, String> roomOwner = {};

  /// Người dùng giả (sau này lấy từ module Đăng nhập).
  final Map<String, DemoUser> users = {};

  /// Module Bài đăng gắn hàm ẩn bài vào đây; được gọi khi admin xử lý báo cáo bài đăng.
  void Function(String roomId)? onHideRoom;

  /// Module Phân quyền gắn hàm khóa tài khoản vào đây; được gọi khi admin xử lý báo cáo người dùng.
  void Function(String userId)? onLockUser;

  /// Bài đăng / tài khoản đã bị admin xử lý (lưu tạm trong module này để demo;
  /// khi có hook ở trên thì module kia mới là nơi giữ trạng thái thật).
  final Set<String> hiddenRoomIds = {};
  final Set<String> lockedUserIds = {};

  int _messageSeq = 0;

  /// true = dữ liệu giả để demo (có thanh chọn vai trò).
  /// false = đang dùng tài khoản và dữ liệu thật trên Firestore.
  bool isDemo = true;

  /// Nếu gán, id tin nhắn lấy từ hàm này (Firestore) thay vì đếm m1, m2, ...
  String Function()? idGenerator;

  DemoUser _current = DemoUsers.tenant;

  DemoUser get currentUser => _current;
  UserRole get role => _current.role;
  DateTime now() => _clock();

  /// Báo giao diện vẽ lại (lớp bên ngoài không gọi trực tiếp notifyListeners được).
  void refresh() => notifyListeners();

  /// Chuyển sang dữ liệu thật: xóa sạch dữ liệu giả, dữ liệu mới sẽ đến từ Firestore.
  void startRemoteMode() {
    isDemo = false;
    contacts.replaceAll(const []);
    appointments.replaceAll(const []);
    reviews.replaceAll(const []);
    reports.replaceAll(const []);
    rooms.clear();
    roomOwner.clear();
    users.clear();
    hiddenRoomIds.clear();
    lockedUserIds.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Người dùng và phòng (dữ liệu giả, chờ các module khác)
  // ---------------------------------------------------------------------------

  /// Chuyển nhanh sang một người dùng mẫu của vai trò [newRole] (dùng để demo).
  void switchRole(UserRole newRole) =>
      switchUser(DemoUsers.defaultFor(newRole));

  void switchUser(DemoUser user) {
    users[user.id] = user;
    _current = user;
    notifyListeners();
  }

  DemoUser? userById(String? id) => id == null ? null : users[id];

  /// Module Bài đăng gọi hàm này để đăng ký phòng thật.
  void registerRoom(RoomItem room, {required String ownerId}) {
    rooms[room.id] = room;
    roomOwner[room.id] = ownerId;
    notifyListeners();
  }

  String? ownerOf(String roomId) => roomOwner[roomId];

  bool isRoomHidden(String roomId) => hiddenRoomIds.contains(roomId);
  bool isUserLocked(String userId) => lockedUserIds.contains(userId);

  /// Phòng đang hiển thị (chưa bị admin ẩn).
  List<RoomItem> get visibleRooms =>
      rooms.values.where((r) => !hiddenRoomIds.contains(r.id)).toList();

  // ---------------------------------------------------------------------------
  // Liên hệ (cuộc trò chuyện người thuê - chủ trọ về một phòng)
  // ---------------------------------------------------------------------------

  /// Cuộc trò chuyện của [tenantId] về phòng [roomId] (null nếu chưa nhắn lần nào).
  Contact? findContact({required String roomId, required String tenantId}) {
    for (final c in contacts.findAll()) {
      if (c.roomId == roomId && c.tenantId == tenantId) return c;
    }
    return null;
  }

  /// Người thuê nhắn cho chủ trọ của phòng. Chưa có cuộc trò chuyện thì tạo mới.
  Contact sendToOwner({required String roomId, required String text}) {
    _requireRole(UserRole.tenant, 'nhắn tin cho chủ trọ');
    _requireNotLocked();
    final ownerId = _ownerOrThrow(roomId);
    final existing = findContact(roomId: roomId, tenantId: _current.id);
    final contact =
        existing ??
        Contact(
          id: contacts.nextId(),
          roomId: roomId,
          tenantId: _current.id,
          ownerId: ownerId,
          createdAt: _clock(),
        );
    contact.send(
      messageId: _nextMessageId(),
      senderId: _current.id,
      text: text.trim(),
      sentAt: _clock(),
    );
    if (existing == null) {
      contacts.add(contact);
    } else {
      contacts.update(contact);
    }
    notifyListeners();
    return contact;
  }

  /// Gửi thêm một tin trong cuộc trò chuyện có sẵn (người thuê hoặc chủ trọ của cuộc đó).
  ContactMessage sendMessage(String contactId, String text) {
    _requireNotLocked();
    final contact = contacts.findById(contactId);
    if (contact == null) throw StateError('Không tìm thấy cuộc trò chuyện');
    if (_current.id != contact.tenantId && _current.id != contact.ownerId) {
      throw StateError('Bạn không thuộc cuộc trò chuyện này');
    }
    final message = contact.send(
      messageId: _nextMessageId(),
      senderId: _current.id,
      text: text.trim(),
      sentAt: _clock(),
    );
    contacts.update(contact);
    notifyListeners();
    return message;
  }

  /// Chủ trọ mở cuộc trò chuyện -> tin mới chuyển sang "đã đọc".
  void markContactRead(String contactId) {
    final contact = contacts.findById(contactId);
    if (contact == null || contact.ownerId != _current.id) return;
    if (!contact.isUnreadForOwner) return;
    contact.markReadByOwner();
    contacts.update(contact);
    notifyListeners();
  }

  /// Cuộc trò chuyện của người dùng hiện tại (người thuê: đã nhắn; chủ trọ: nhận được),
  /// có hoạt động gần nhất lên đầu.
  List<Contact> contactsForCurrentUser() {
    final list = switch (_current.role) {
      UserRole.tenant => contacts.findAll(
        where: (c) => c.tenantId == _current.id,
      ),
      UserRole.owner => contacts.findAll(
        where: (c) => c.ownerId == _current.id,
      ),
      UserRole.admin => <Contact>[],
    };
    list.sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));
    return list;
  }

  /// Số cuộc trò chuyện chủ trọ chưa xem.
  int unreadContactCount() {
    if (_current.role != UserRole.owner) return 0;
    return contactsForCurrentUser().where((c) => c.isUnreadForOwner).length;
  }

  /// Thời điểm có tin gần nhất của cuộc trò chuyện.
  DateTime lastActivity(Contact c) =>
      c.lastMessage?.createdAt ?? c.createdAt ?? DateTime(2000);

  // ---------------------------------------------------------------------------
  // Lịch hẹn
  // ---------------------------------------------------------------------------

  Appointment book({
    required String roomId,
    required DateTime time,
    required String phone,
    String note = '',
  }) {
    _requireRole(UserRole.tenant, 'đặt lịch xem phòng');
    _requireNotLocked();
    final ownerId = _ownerOrThrow(roomId);
    if (phone.trim().isEmpty) {
      throw ArgumentError('Vui lòng nhập số điện thoại để chủ trọ liên lạc');
    }
    final minutes = time.hour * 60 + time.minute;
    if (minutes < openHour * 60 || minutes > closeHour * 60) {
      throw ArgumentError('Chỉ nhận lịch xem phòng từ 07:00 đến 21:00');
    }

    final clash = appointments.findAll(
      where: (a) =>
          a.roomId == roomId &&
          a.status == AppointmentStatus.confirmed &&
          a.appointmentTime.difference(time).abs() < slot,
    );
    if (clash.isNotEmpty) {
      throw StateError('Khung giờ này đã có người đặt, vui lòng chọn giờ khác');
    }
    final mine = appointments.findAll(
      where: (a) =>
          a.roomId == roomId &&
          a.tenantId == _current.id &&
          isUpcoming(a) &&
          a.appointmentTime.difference(time).abs() < slot,
    );
    if (mine.isNotEmpty) {
      throw StateError('Bạn đã có lịch xem phòng này vào khoảng giờ đó');
    }

    final appointment = appointments.add(
      Appointment.book(
        id: appointments.nextId(),
        roomId: roomId,
        tenantId: _current.id,
        ownerId: ownerId,
        time: time,
        note: note.trim(),
        phone: phone.trim(),
        now: _clock(),
      ),
    );
    notifyListeners();
    return appointment;
  }

  void confirmAppointment(String id) {
    final a = _ownedAppointment(id, 'xác nhận lịch hẹn');
    final clash = appointments.findAll(
      where: (o) =>
          o.id != a.id &&
          o.roomId == a.roomId &&
          o.status == AppointmentStatus.confirmed &&
          o.appointmentTime.difference(a.appointmentTime).abs() < slot,
    );
    if (clash.isNotEmpty) {
      throw StateError('Đã có lịch được xác nhận trong khung giờ này');
    }
    a.confirm();
    appointments.update(a);
    notifyListeners();
  }

  void rejectAppointment(String id, String reason) {
    final a = _ownedAppointment(id, 'từ chối lịch hẹn');
    a.reject(reason);
    appointments.update(a);
    notifyListeners();
  }

  void completeAppointment(String id) {
    final a = _ownedAppointment(id, 'đánh dấu hoàn thành lịch hẹn');
    a.complete();
    appointments.update(a);
    notifyListeners();
  }

  /// Người thuê hoặc chủ trọ của lịch đó đều hủy được (khi chưa hoàn thành).
  void cancelAppointment(String id) {
    final a = _appointmentOrThrow(id);
    if (a.tenantId != _current.id && a.ownerId != _current.id) {
      throw StateError('Bạn không có quyền hủy lịch này');
    }
    a.cancel();
    appointments.update(a);
    notifyListeners();
  }

  /// Lịch hẹn của người dùng hiện tại, sớm -> muộn.
  List<Appointment> appointmentsForCurrentUser() {
    final list = switch (_current.role) {
      UserRole.tenant => appointments.findAll(
        where: (a) => a.tenantId == _current.id,
      ),
      UserRole.owner => appointments.findAll(
        where: (a) => a.ownerId == _current.id,
      ),
      UserRole.admin => appointments.findAll(),
    };
    list.sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    return list;
  }

  /// "Sắp tới" = đang chờ hoặc đã xác nhận (chưa hoàn thành, chưa hủy/từ chối).
  static bool isUpcoming(Appointment a) =>
      a.status == AppointmentStatus.pending ||
      a.status == AppointmentStatus.confirmed;

  // ---------------------------------------------------------------------------
  // Đánh giá
  // ---------------------------------------------------------------------------

  Review addReview({
    required String appointmentId,
    required int rating,
    String comment = '',
  }) {
    _requireRole(UserRole.tenant, 'đánh giá phòng');
    _requireNotLocked();
    final appointment = _appointmentOrThrow(appointmentId);
    if (appointment.tenantId != _current.id) {
      throw StateError('Đây không phải lịch hẹn của bạn');
    }
    if (reviewForAppointment(appointmentId) != null) {
      throw StateError('Bạn đã đánh giá lịch hẹn này rồi');
    }
    final review = reviews.add(
      Review.forAppointment(
        appointment,
        id: reviews.nextId(),
        rating: rating,
        comment: comment.trim(),
      ),
    );
    notifyListeners();
    return review;
  }

  Review editReview(String id, {int? rating, String? comment}) {
    final review = _reviewOrThrow(id);
    if (review.userId != _current.id) {
      throw StateError('Bạn chỉ sửa được đánh giá của chính mình');
    }
    review.edit(rating: rating, comment: comment?.trim());
    reviews.update(review);
    notifyListeners();
    return review;
  }

  /// Tác giả hoặc admin xóa được đánh giá.
  void deleteReview(String id) {
    final review = _reviewOrThrow(id);
    final allowed =
        review.userId == _current.id || _current.role == UserRole.admin;
    if (!allowed) throw StateError('Bạn không có quyền xóa đánh giá này');
    reviews.remove(id);
    notifyListeners();
  }

  void replyReview(String id, String text) {
    _requireRole(UserRole.owner, 'phản hồi đánh giá');
    final review = _reviewOrThrow(id);
    if (roomOwner[review.roomId] != _current.id) {
      throw StateError('Đây không phải phòng của bạn');
    }
    review.replyAsOwner(text);
    reviews.update(review);
    notifyListeners();
  }

  Review? reviewForAppointment(String appointmentId) {
    final found = reviews.findAll(
      where: (r) => r.appointmentId == appointmentId,
    );
    return found.isEmpty ? null : found.first;
  }

  /// Đánh giá của một phòng, mới -> cũ.
  List<Review> reviewsOfRoom(String roomId) {
    final list = reviews.findAll(where: (r) => r.roomId == roomId);
    list.sort((a, b) => _byCreated(b, a));
    return list;
  }

  /// Điểm trung bình + số lượt đánh giá (trang chủ, tìm kiếm, gợi ý dùng).
  RatingSummary ratingSummary(String roomId) =>
      Review.summarize(reviewsOfRoom(roomId));

  /// Đánh giá hiển thị cho người dùng hiện tại
  /// (người thuê: của mình; chủ trọ: về phòng của mình; admin: tất cả).
  List<Review> reviewsForCurrentUser() {
    final list = switch (_current.role) {
      UserRole.tenant => reviews.findAll(where: (r) => r.userId == _current.id),
      UserRole.owner => reviews.findAll(
        where: (r) => roomOwner[r.roomId] == _current.id,
      ),
      UserRole.admin => reviews.findAll(),
    };
    list.sort((a, b) => _byCreated(b, a));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Báo cáo
  // ---------------------------------------------------------------------------

  Report submitReport({
    required ReportTarget type,
    required String targetId,
    required String reason,
    String description = '',
  }) {
    if (_current.role == UserRole.admin) {
      throw StateError('Admin xử lý báo cáo, không gửi báo cáo');
    }
    _requireNotLocked();
    final duplicated = reports.findAll(
      where: (r) =>
          r.reporterId == _current.id &&
          r.targetType == type &&
          r.targetId == targetId &&
          r.status == ReportStatus.pending,
    );
    if (duplicated.isNotEmpty) {
      throw StateError('Bạn đã báo cáo mục này, vui lòng chờ admin xử lý');
    }
    final report = reports.add(
      Report(
        id: reports.nextId(),
        reporterId: _current.id,
        targetType: type,
        targetId: targetId,
        reason: reason,
        description: description.trim(),
        createdAt: _clock(),
      ),
    );
    notifyListeners();
    return report;
  }

  /// Danh sách báo cáo (admin), mới -> cũ. [pending] true = chờ xử lý, false = đã xử lý.
  List<Report> reportsByPending(bool pending) {
    final list = reports.findAll(
      where: (r) => (r.status == ReportStatus.pending) == pending,
    );
    list.sort((a, b) => _byCreated(b, a));
    return list;
  }

  /// Admin xác nhận vi phạm: ẩn bài / khóa tài khoản / xóa đánh giá tùy loại.
  void resolveReport(String id, {String note = ''}) {
    _requireRole(UserRole.admin, 'xử lý báo cáo');
    final report = _reportOrThrow(id);
    if (report.status != ReportStatus.pending) {
      throw StateError('Báo cáo này đã được xử lý');
    }
    switch (report.targetType) {
      case ReportTarget.room:
        hiddenRoomIds.add(report.targetId);
        onHideRoom?.call(report.targetId);
      case ReportTarget.user:
        lockedUserIds.add(report.targetId);
        onLockUser?.call(report.targetId);
      case ReportTarget.review:
        reviews.remove(report.targetId);
    }
    final action = report.targetType.actionLabel;
    final extra = note.trim();
    report.resolve(
      adminId: _current.id,
      note: extra.isEmpty ? action : '$action — $extra',
    );
    reports.update(report);
    notifyListeners();
  }

  /// Admin bỏ qua báo cáo (không vi phạm).
  void dismissReport(String id, {String note = ''}) {
    _requireRole(UserRole.admin, 'xử lý báo cáo');
    final report = _reportOrThrow(id);
    report.dismiss(adminId: _current.id, note: note.trim());
    reports.update(report);
    notifyListeners();
  }

  /// Mô tả ngắn đối tượng bị báo cáo để admin biết.
  String describeTarget(Report report) {
    switch (report.targetType) {
      case ReportTarget.room:
        return rooms[report.targetId]?.title ?? 'Bài đăng #${report.targetId}';
      case ReportTarget.user:
        return users[report.targetId]?.name ?? 'Người dùng #${report.targetId}';
      case ReportTarget.review:
        final review = reviews.findById(report.targetId);
        if (review == null) return 'Đánh giá đã bị xóa';
        final text = review.comment.isEmpty
            ? '${review.rating} sao'
            : review.comment;
        return '“$text”';
    }
  }

  // ---------------------------------------------------------------------------
  // Hàm nội bộ
  // ---------------------------------------------------------------------------

  String _nextMessageId() => idGenerator?.call() ?? 'm${++_messageSeq}';

  void _requireNotLocked() {
    if (lockedUserIds.contains(_current.id)) {
      throw StateError('Tài khoản của bạn đã bị khóa');
    }
  }

  void _requireRole(UserRole required, String action) {
    if (_current.role != required) {
      throw StateError('Chỉ ${required.label.toLowerCase()} mới được $action');
    }
  }

  String _ownerOrThrow(String roomId) {
    final ownerId = roomOwner[roomId];
    if (ownerId == null) throw StateError('Không tìm thấy phòng này');
    return ownerId;
  }

  Appointment _appointmentOrThrow(String id) {
    final a = appointments.findById(id);
    if (a == null) throw StateError('Không tìm thấy lịch hẹn');
    return a;
  }

  Appointment _ownedAppointment(String id, String action) {
    _requireRole(UserRole.owner, action);
    final a = _appointmentOrThrow(id);
    if (a.ownerId != _current.id) {
      throw StateError('Đây không phải lịch hẹn của phòng bạn');
    }
    return a;
  }

  Review _reviewOrThrow(String id) {
    final r = reviews.findById(id);
    if (r == null) throw StateError('Không tìm thấy đánh giá');
    return r;
  }

  Report _reportOrThrow(String id) {
    final r = reports.findById(id);
    if (r == null) throw StateError('Không tìm thấy báo cáo');
    return r;
  }

  static int _byCreated(BaseEntity<String> a, BaseEntity<String> b) =>
      (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000));

  // ---------------------------------------------------------------------------
  // Dữ liệu mẫu
  // ---------------------------------------------------------------------------

  /// [dayOffset] ngày so với hôm nay, lúc [hour]:[minute].
  DateTime _at(int dayOffset, int hour, [int minute = 0]) {
    final n = _clock();
    return DateTime(n.year, n.month, n.day + dayOffset, hour, minute);
  }

  void _seedRooms() {
    registerRoom(
      const RoomItem(
        id: '1',
        title: 'Phòng trọ khép kín full đồ gần ĐH Phenikaa',
        address: 'Yên Nghĩa, Hà Đông, Hà Nội',
        price: 2.8,
        area: 25,
        imageUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
      ),
      ownerId: DemoUsers.ownerA.id,
    );
    registerRoom(
      const RoomItem(
        id: '2',
        title: 'Chung cư mini có thang máy, ban công thoáng',
        address: 'Đồng Mai, Hà Đông, Hà Nội',
        price: 3.5,
        area: 32,
        imageUrl: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
      ),
      ownerId: DemoUsers.ownerA.id,
    );
    registerRoom(
      const RoomItem(
        id: '3',
        title: 'Phòng đơn giá rẻ cho sinh viên năm nhất',
        address: 'Dương Nội, Hà Đông, Hà Nội',
        price: 1.6,
        area: 18,
        imageUrl:
            'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600',
      ),
      ownerId: DemoUsers.ownerB.id,
    );
  }

  void _seedActivity() {
    final t = DemoUsers.tenant.id;
    final t2 = DemoUsers.tenant2.id;
    final ownerA = DemoUsers.ownerA.id;

    Appointment appt(
      String roomId,
      String tenantId,
      DateTime time,
      AppointmentStatus status, {
      String note = '',
      String? rejectReason,
    }) {
      return appointments.add(
        Appointment(
          id: appointments.nextId(),
          roomId: roomId,
          tenantId: tenantId,
          ownerId: roomOwner[roomId]!,
          appointmentTime: time,
          note: note,
          phone: users[tenantId]?.phone ?? '',
          status: status,
          rejectReason: rejectReason,
          createdAt: time.subtract(const Duration(days: 1)),
        ),
      );
    }

    // Lịch hẹn của người thuê mẫu (Trần Minh Anh)
    appt(
      '1',
      t,
      _at(2, 9, 30),
      AppointmentStatus.pending,
      note: 'Em muốn xem phòng sau giờ học',
    );
    appt('2', t, _at(3, 14), AppointmentStatus.confirmed);
    appt('1', t, _at(-14, 10), AppointmentStatus.completed); // chưa đánh giá
    appt(
      '3',
      t,
      _at(-3, 10),
      AppointmentStatus.rejected,
      rejectReason: 'Phòng đã có người đặt cọc',
    );

    // Lịch hẹn của người thuê khác
    final done1 = appt('1', t2, _at(-10, 15), AppointmentStatus.completed);
    final done2 = appt('2', t2, _at(-6, 11), AppointmentStatus.completed);
    appt(
      '1',
      t2,
      _at(4, 16),
      AppointmentStatus.pending,
      note: 'Cho em xem phòng buổi chiều nhé',
    );

    // Đánh giá
    final review1 = reviews.add(
      Review(
        id: reviews.nextId(),
        roomId: '1',
        userId: t2,
        appointmentId: done1.id,
        rating: 5,
        comment: 'Phòng sạch sẽ, thoáng mát, chủ trọ nhiệt tình. Đi bộ tới trường được.',
        createdAt: _at(-9, 20),
      ),
    );
    reviews.add(
      Review(
        id: reviews.nextId(),
        roomId: '2',
        userId: t2,
        appointmentId: done2.id,
        rating: 4,
        comment: 'Chung cư mini có thang máy, hơi ồn vào buổi sáng.',
        ownerReply: 'Cảm ơn bạn đã góp ý, mình sẽ nhắc các phòng bên cạnh giữ yên tĩnh hơn.',
        createdAt: _at(-5, 9),
      ),
    );

    // Liên hệ (cuộc trò chuyện)
    Contact chat(
      String roomId,
      String tenantId,
      List<(String, String, DateTime)> lines,
      ContactStatus status,
    ) {
      final contactId = contacts.nextId();
      final messages = <ContactMessage>[
        for (final line in lines)
          ContactMessage(
            id: _nextMessageId(),
            contactId: contactId,
            senderId: line.$1,
            text: line.$2,
            createdAt: line.$3,
          ),
      ];
      return contacts.add(
        Contact(
          id: contactId,
          roomId: roomId,
          tenantId: tenantId,
          ownerId: roomOwner[roomId]!,
          messages: messages,
          status: status,
          createdAt: lines.first.$3,
        ),
      );
    }

    chat('1', t, [
      (
        t,
        'Chào anh, phòng này còn trống không ạ? Em muốn xem phòng vào cuối tuần.',
        _at(-1, 9, 32),
      ),
      (
        ownerA,
        'Phòng vẫn còn nhé em. Thứ Bảy anh sắp xếp lúc 9:30 sáng được không?',
        _at(-1, 9, 34),
      ),
    ], ContactStatus.replied);
    chat('1', t2, [
      (t2, 'Phòng có cho nuôi mèo không ạ?', _at(0, 8, 15)),
    ], ContactStatus.newMessage);
    chat('2', t, [
      (t, 'Giá phòng đã bao gồm điện nước chưa anh?', _at(0, 9, 5)),
    ], ContactStatus.newMessage);

    // Báo cáo
    reports.add(
      Report(
        id: reports.nextId(),
        reporterId: t2,
        targetType: ReportTarget.room,
        targetId: '3',
        reason: 'Thông tin không chính xác',
        description: 'Diện tích thực tế nhỏ hơn nhiều so với tin đăng.',
        createdAt: _at(-1, 21),
      ),
    );
    reports.add(
      Report(
        id: reports.nextId(),
        reporterId: t,
        targetType: ReportTarget.review,
        targetId: review1.id,
        reason: 'Spam / quảng cáo',
        createdAt: _at(0, 7),
      ),
    );
  }
}
