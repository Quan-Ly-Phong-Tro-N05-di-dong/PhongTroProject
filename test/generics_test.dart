// test/generics_test.dart
// Chạy: flutter test test/generics_test.dart
import 'package:flutter_application_test/core/base/base_entity.dart';
import 'package:flutter_application_test/core/base/entity_registry.dart';
import 'package:flutter_application_test/core/base/repository.dart';
import 'package:flutter_application_test/features/contact/models/contact_models.dart';
import 'package:flutter_application_test/features/home_catalog/models/room_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Model giả, cố tình KHÔNG đăng ký để kiểm tra EntityRegistry báo lỗi.
class _Unregistered extends BaseEntity<String> {
  const _Unregistered() : super(id: 'x');

  @override
  Map<String, dynamic> toJson() => baseJson();
}

Appointment _completedAppointment() {
  final appt = Appointment.book(
    id: 'a1',
    roomId: 'r1',
    tenantId: 'u2',
    ownerId: 'u5',
    time: DateTime.now().add(const Duration(days: 1)),
  );
  appt.confirm();
  appt.complete();
  return appt;
}

void main() {
  setUpAll(() {
    registerRoomModels();
    registerContactModels();
  });

  group('BaseEntity<ID> + Object', () {
    test('RoomItem, Contact... đều là BaseEntity<String>', () {
      const room = RoomItem(
        id: '1',
        title: 't',
        address: 'a',
        price: 1,
        area: 10,
        imageUrl: 'u',
      );
      expect(room, isA<BaseEntity<String>>());
      expect(room.entityType, RoomItem);
    });

    test('== và hashCode dựa trên kiểu + id', () {
      final a = Contact(id: '1', roomId: 'r1', tenantId: 'u2', ownerId: 'u5');
      final b = Contact(id: '1', roomId: 'r9', tenantId: 'u3', ownerId: 'u5');
      final other = Appointment(
        id: '1',
        roomId: 'r1',
        tenantId: 'u2',
        ownerId: 'u5',
        appointmentTime: DateTime.now(),
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == other, isFalse); // cùng id nhưng khác kiểu
      expect(<BaseEntity<String>>{a, b}.length, 1);
    });

    test('toString có tên lớp', () {
      final c = Contact(id: '1', roomId: 'r1', tenantId: 'u2', ownerId: 'u5');
      expect(c.toString(), startsWith('Contact('));
    });
  });

  group('EntityRegistry (Type)', () {
    test('toJson -> fromJson<T> cho cả 5 model', () {
      const room = RoomItem(
        id: '1',
        title: 'Phòng A',
        address: 'Hà Đông',
        price: 2.5,
        area: 20,
        imageUrl: 'u',
      );
      final contact = Contact(
        id: '1',
        roomId: '1',
        tenantId: 'u2',
        ownerId: 'u5',
      );
      contact.send(messageId: 'm1', senderId: 'u2', text: 'hi');
      final appt = _completedAppointment();
      final review = Review.forAppointment(
        appt,
        id: 'v1',
        rating: 4,
        comment: 'ok',
      );
      final report = Report(
        id: 'p1',
        reporterId: 'u2',
        targetType: ReportTarget.room,
        targetId: '1',
        reason: 'Sai thông tin',
      );

      expect(EntityRegistry.fromJson<RoomItem>(room.toJson()), room);
      expect(EntityRegistry.fromJson<Contact>(contact.toJson()), contact);
      expect(
        EntityRegistry.fromJson<Contact>(contact.toJson()).messages.single.text,
        'hi',
      );
      expect(
        EntityRegistry.fromJson<Appointment>(appt.toJson()).status,
        AppointmentStatus.completed,
      );
      expect(EntityRegistry.fromJson<Review>(review.toJson()).rating, 4);
      expect(
        EntityRegistry.fromJson<Report>(report.toJson()).targetType,
        ReportTarget.room,
      );
    });

    test('đăng ký đúng tên bảng và báo lỗi khi chưa đăng ký', () {
      expect(EntityRegistry.nameOf<Review>(), 'reviews');
      expect(EntityRegistry.nameOfType(Contact), 'contacts');
      expect(EntityRegistry.isRegistered<Report>(), isTrue);
      expect(EntityRegistry.isRegistered<_Unregistered>(), isFalse);
      expect(
        () => EntityRegistry.fromJson<_Unregistered>({'id': 'x'}),
        throwsStateError,
      );
    });
  });

  group('Repository<T>', () {
    test('thêm, tìm, sửa, xóa, xuất/nạp JSON', () {
      final repo = Repository<Contact>();
      final c = repo.add(
        Contact(id: repo.nextId(), roomId: 'r1', tenantId: 'u2', ownerId: 'u5'),
      );
      c.send(messageId: 'm1', senderId: 'u2', text: 'hi');
      expect(repo.count, 1);
      expect(repo.findById(c.id), c);
      expect(() => repo.add(c), throwsArgumentError);

      c.send(
        messageId: 'm2',
        senderId: 'u5',
        text: 'chào bạn',
      ); // chủ trọ trả lời
      repo.update(c);
      expect(
        repo.findAll(where: (x) => x.status == ContactStatus.replied).length,
        1,
      );

      final copy = Repository<Contact>()..importJson(repo.exportJson());
      expect(copy.findById(c.id)?.lastMessage?.text, 'chào bạn');
      expect(copy.findById(c.id)?.messages.length, 2);

      expect(repo.remove(c.id), isTrue);
      expect(repo.count, 0);
    });
  });

  group('Quy tắc nghiệp vụ module Contact', () {
    test('không tự liên hệ phòng của mình', () {
      expect(
        () => Contact(id: '1', roomId: 'r1', tenantId: 'u5', ownerId: 'u5'),
        throwsArgumentError,
      );
    });

    test('chỉ người thuê / chủ trọ của cuộc trò chuyện mới nhắn được, tin không được trống', () {
      final c = Contact(id: '1', roomId: 'r1', tenantId: 'u2', ownerId: 'u5');
      expect(
        () => c.send(messageId: 'm1', senderId: 'u9', text: 'xen vào'),
        throwsArgumentError,
      );
      expect(
        () => c.send(messageId: 'm1', senderId: 'u2', text: '   '),
        throwsArgumentError,
      );
      expect(c.messages, isEmpty);
    });

    test('lịch hẹn: không đặt quá khứ, chuyển trạng thái đúng luồng', () {
      expect(
        () => Appointment.book(
          id: '1',
          roomId: 'r1',
          tenantId: 'u2',
          ownerId: 'u5',
          time: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        throwsArgumentError,
      );
      final appt = Appointment.book(
        id: '1',
        roomId: 'r1',
        tenantId: 'u2',
        ownerId: 'u5',
        time: DateTime.now().add(const Duration(days: 1)),
      );
      expect(appt.complete, throwsStateError); // chưa confirm
      appt.confirm();
      expect(appt.confirm, throwsStateError); // đã confirm rồi
      appt.complete();
      expect(appt.cancel, throwsStateError); // đã hoàn thành
    });

    test('chỉ đánh giá khi lịch hẹn đã hoàn thành, sao từ 1-5', () {
      final pending = Appointment.book(
        id: '2',
        roomId: 'r1',
        tenantId: 'u2',
        ownerId: 'u5',
        time: DateTime.now().add(const Duration(days: 1)),
      );
      expect(
        () => Review.forAppointment(pending, id: 'v1', rating: 5),
        throwsStateError,
      );
      final done = _completedAppointment();
      expect(
        () => Review.forAppointment(done, id: 'v1', rating: 6),
        throwsArgumentError,
      );
    });

    test('RatingSummary tính trung bình đúng', () {
      final done = _completedAppointment();
      final r1 = Review.forAppointment(done, id: 'v1', rating: 5);
      final r2 = Review.forAppointment(done, id: 'v2', rating: 3);
      final summary = Review.summarize([r1, r2]);
      expect(summary.count, 2);
      expect(summary.average, 4.0);
      expect(Review.summarize(const []).count, 0);
    });

    test('báo cáo chỉ xử lý được một lần', () {
      final report = Report(
        id: 'p1',
        reporterId: 'u2',
        targetType: ReportTarget.user,
        targetId: 'u9',
        reason: 'Lừa đảo',
      );
      report.resolve(adminId: 'admin1');
      expect(report.status, ReportStatus.resolved);
      expect(() => report.dismiss(adminId: 'admin1'), throwsStateError);
    });
  });
}
