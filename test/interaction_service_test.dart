// test/interaction_service_test.dart
// Kiểm tra nghiệp vụ module "Tương tác & phản hồi người dùng" (không cần giao diện).
// Chạy: flutter test test/interaction_service_test.dart
import 'package:flutter_application_test/features/contact/models/contact_models.dart';
import 'package:flutter_application_test/features/contact/services/interaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Đồng hồ cố định để dữ liệu mẫu và các phép kiểm tra không phụ thuộc ngày chạy test.
final DateTime _now = DateTime(2026, 10, 22, 8);

InteractionService _service() => InteractionService(clock: () => _now);

/// [days] ngày so với "hôm nay" của đồng hồ cố định, lúc [hour]:[minute].
DateTime _at(int days, int hour, [int minute = 0]) =>
    DateTime(_now.year, _now.month, _now.day + days, hour, minute);

const String _phone = '0987 654 321';

void main() {
  group('Dữ liệu mẫu', () {
    test('người thuê thấy 2 lịch sắp tới và 2 lịch đã qua', () {
      final s = _service();
      final mine = s.appointmentsForCurrentUser();
      expect(mine.where(InteractionService.isUpcoming).length, 2);
      expect(mine.where((a) => !InteractionService.isUpcoming(a)).length, 2);
    });

    test('chủ trọ chỉ thấy lịch hẹn của phòng mình', () {
      final s = _service()..switchRole(UserRole.owner);
      final list = s.appointmentsForCurrentUser();
      expect(list.length, 6);
      expect(list.every((a) => a.ownerId == DemoUsers.ownerA.id), isTrue);
    });
  });

  group('Đặt lịch', () {
    test('đặt lịch hợp lệ -> trạng thái chờ xác nhận, gắn đúng chủ trọ', () {
      final s = _service();
      final a = s.book(
        roomId: '1',
        time: _at(1, 9, 30),
        phone: _phone,
        note: ' Xem sau giờ học ',
      );
      expect(a.status, AppointmentStatus.pending);
      expect(a.ownerId, DemoUsers.ownerA.id);
      expect(a.note, 'Xem sau giờ học');
      expect(s.appointments.findById(a.id), a);
    });

    test('không đặt giờ trong quá khứ', () {
      final s = _service();
      expect(
        () => s.book(roomId: '1', time: _at(-1, 9), phone: _phone),
        throwsArgumentError,
      );
    });

    test('chỉ nhận lịch từ 07:00 đến 21:00', () {
      final s = _service();
      expect(
        () => s.book(roomId: '1', time: _at(1, 22), phone: _phone),
        throwsArgumentError,
      );
      expect(
        () => s.book(roomId: '1', time: _at(1, 6, 30), phone: _phone),
        throwsArgumentError,
      );
    });

    test('phải có số điện thoại', () {
      final s = _service();
      expect(
        () => s.book(roomId: '1', time: _at(1, 9), phone: '  '),
        throwsArgumentError,
      );
    });

    test('không đặt trùng giờ với lịch đã xác nhận của cùng phòng', () {
      final s = _service();
      // Phòng 2 đã có lịch xác nhận lúc 14:00 (3 ngày nữa).
      expect(
        () => s.book(roomId: '2', time: _at(3, 14, 30), phone: _phone),
        throwsStateError,
      );
      final ok = s.book(roomId: '2', time: _at(3, 15, 30), phone: _phone);
      expect(ok.status, AppointmentStatus.pending);
    });

    test('không tự đặt hai lịch sát giờ nhau ở cùng một phòng', () {
      final s = _service();
      // Đã có lịch chờ xác nhận phòng 1 lúc 09:30, 2 ngày nữa.
      expect(
        () => s.book(roomId: '1', time: _at(2, 10), phone: _phone),
        throwsStateError,
      );
    });

    test('chủ trọ không đặt lịch được', () {
      final s = _service()..switchRole(UserRole.owner);
      expect(
        () => s.book(roomId: '1', time: _at(1, 9), phone: _phone),
        throwsStateError,
      );
    });

    test('phòng không tồn tại thì báo lỗi', () {
      final s = _service();
      expect(
        () => s.book(roomId: '999', time: _at(1, 9), phone: _phone),
        throwsStateError,
      );
    });
  });

  group('Chủ trọ xử lý lịch hẹn', () {
    test('xác nhận rồi đánh dấu hoàn thành', () {
      final s = _service()..switchRole(UserRole.owner);
      s.confirmAppointment('1');
      expect(s.appointments.findById('1')!.status, AppointmentStatus.confirmed);
      s.completeAppointment('1');
      expect(s.appointments.findById('1')!.status, AppointmentStatus.completed);
    });

    test('từ chối phải có lý do', () {
      final s = _service()..switchRole(UserRole.owner);
      expect(() => s.rejectAppointment('1', '  '), throwsArgumentError);
      s.rejectAppointment('1', 'Phòng đã cho thuê');
      final a = s.appointments.findById('1')!;
      expect(a.status, AppointmentStatus.rejected);
      expect(a.rejectReason, 'Phòng đã cho thuê');
    });

    test('chưa xác nhận thì chưa hoàn thành được', () {
      final s = _service()..switchRole(UserRole.owner);
      expect(() => s.completeAppointment('1'), throwsStateError);
    });

    test('chủ trọ khác không xử lý được lịch của phòng này', () {
      final s = _service()..switchUser(DemoUsers.ownerB);
      expect(() => s.confirmAppointment('1'), throwsStateError);
    });

    test('người thuê không tự xác nhận được lịch của mình', () {
      final s = _service();
      expect(() => s.confirmAppointment('1'), throwsStateError);
    });

    test('không xác nhận hai lịch sát giờ nhau của cùng một phòng', () {
      final s = _service();
      final x = s.book(roomId: '1', time: _at(4, 16, 30), phone: _phone);
      s.switchRole(UserRole.owner);
      s.confirmAppointment('7'); // lịch 16:00 của người thuê khác
      expect(() => s.confirmAppointment(x.id), throwsStateError);
    });

    test('hủy lịch: người thuê hủy được lịch của mình, không hủy được lịch đã hoàn thành', () {
      final s = _service();
      s.cancelAppointment('1');
      expect(s.appointments.findById('1')!.status, AppointmentStatus.cancelled);
      expect(() => s.cancelAppointment('3'), throwsStateError); // đã hoàn thành
    });

    test('người không liên quan không hủy được lịch', () {
      final s = _service()..switchUser(DemoUsers.tenant2);
      expect(() => s.cancelAppointment('2'), throwsStateError);
    });
  });

  group('Đánh giá', () {
    test('chỉ đánh giá sau khi lịch hẹn đã hoàn thành', () {
      final s = _service();
      expect(
        () => s.addReview(appointmentId: '1', rating: 5),
        throwsStateError,
      );
      final r = s.addReview(appointmentId: '3', rating: 4, comment: ' Ổn ');
      expect(r.comment, 'Ổn');
      expect(s.reviewForAppointment('3'), r);
    });

    test('mỗi lịch hẹn chỉ đánh giá một lần', () {
      final s = _service();
      s.addReview(appointmentId: '3', rating: 4);
      expect(
        () => s.addReview(appointmentId: '3', rating: 5),
        throwsStateError,
      );
    });

    test('số sao phải từ 1 đến 5', () {
      final s = _service();
      expect(
        () => s.addReview(appointmentId: '3', rating: 6),
        throwsArgumentError,
      );
      expect(
        () => s.addReview(appointmentId: '3', rating: 0),
        throwsArgumentError,
      );
    });

    test('không đánh giá lịch hẹn của người khác', () {
      final s = _service()..switchUser(DemoUsers.tenant2);
      expect(
        () => s.addReview(appointmentId: '3', rating: 4),
        throwsStateError,
      );
    });

    test('điểm trung bình theo phòng', () {
      final s = _service();
      expect(s.ratingSummary('1').count, 1);
      expect(s.ratingSummary('1').average, 5.0);
      expect(s.ratingSummary('2').average, 4.0);
      expect(s.ratingSummary('3').count, 0);
      s.addReview(appointmentId: '3', rating: 3); // phòng 1: (5 + 3) / 2
      expect(s.ratingSummary('1').count, 2);
      expect(s.ratingSummary('1').average, 4.0);
    });

    test('chủ trọ phản hồi đánh giá về phòng của mình', () {
      final s = _service()..switchRole(UserRole.owner);
      s.replyReview('1', 'Cảm ơn bạn!');
      expect(s.reviews.findById('1')!.ownerReply, 'Cảm ơn bạn!');
    });

    test('chủ trọ khác không phản hồi được', () {
      final s = _service()..switchUser(DemoUsers.ownerB);
      expect(() => s.replyReview('1', 'Cảm ơn'), throwsStateError);
    });

    test('tác giả sửa được đánh giá của mình, người khác thì không', () {
      final s = _service()..switchUser(DemoUsers.tenant2);
      s.editReview('1', rating: 3, comment: ' Tạm ổn ');
      expect(s.reviews.findById('1')!.rating, 3);
      expect(s.reviews.findById('1')!.comment, 'Tạm ổn');
      s.switchRole(UserRole.tenant); // người thuê khác
      expect(() => s.editReview('1', rating: 1), throwsStateError);
    });

    test('tác giả và admin xóa được đánh giá, người khác thì không', () {
      final s = _service();
      expect(() => s.deleteReview('1'), throwsStateError);
      s.switchRole(UserRole.admin);
      s.deleteReview('1');
      expect(s.reviewsOfRoom('1'), isEmpty);
    });
  });

  group('Báo cáo', () {
    test('không báo cáo trùng khi báo cáo cũ còn chờ xử lý', () {
      final s = _service();
      s.submitReport(
        type: ReportTarget.room,
        targetId: '1',
        reason: 'Lừa đảo / giả mạo',
      );
      expect(
        () => s.submitReport(
          type: ReportTarget.room,
          targetId: '1',
          reason: 'Spam / quảng cáo',
        ),
        throwsStateError,
      );
      // Người thuê này đã báo cáo đánh giá '1' trong dữ liệu mẫu.
      expect(
        () => s.submitReport(
          type: ReportTarget.review,
          targetId: '1',
          reason: 'Khác',
        ),
        throwsStateError,
      );
    });

    test('phải có lý do báo cáo', () {
      final s = _service();
      expect(
        () =>
            s.submitReport(type: ReportTarget.room, targetId: '1', reason: ' '),
        throwsArgumentError,
      );
    });

    test('admin không gửi báo cáo', () {
      final s = _service()..switchRole(UserRole.admin);
      expect(
        () => s.submitReport(
          type: ReportTarget.room,
          targetId: '1',
          reason: 'Khác',
        ),
        throwsStateError,
      );
    });

    test('xác nhận báo cáo đánh giá -> đánh giá bị xóa, ghi chú xử lý', () {
      final s = _service()..switchRole(UserRole.admin);
      s.resolveReport('2', note: 'Đúng là spam');
      expect(s.reviews.findById('1'), isNull);
      final r = s.reports.findById('2')!;
      expect(r.status, ReportStatus.resolved);
      expect(r.adminNote, contains('Xóa đánh giá'));
      expect(() => s.resolveReport('2'), throwsStateError); // đã xử lý rồi
    });

    test('xác nhận báo cáo bài đăng -> bài bị ẩn và hook của module Bài đăng được gọi', () {
      final hidden = <String>[];
      final s = _service()
        ..onHideRoom = hidden.add
        ..switchRole(UserRole.admin);
      s.resolveReport('1');
      expect(hidden, ['3']);
      expect(s.isRoomHidden('3'), isTrue);
      expect(s.visibleRooms.map((r) => r.id), isNot(contains('3')));
    });

    test('bỏ qua báo cáo', () {
      final s = _service()..switchRole(UserRole.admin);
      s.dismissReport('1', note: 'Không vi phạm');
      final r = s.reports.findById('1')!;
      expect(r.status, ReportStatus.dismissed);
      expect(r.handledBy, DemoUsers.admin.id);
      expect(s.reportsByPending(true).length, 1);
      expect(s.reportsByPending(false).length, 1);
    });

    test('người không phải admin không xử lý được báo cáo', () {
      final s = _service();
      expect(() => s.resolveReport('1'), throwsStateError);
      expect(() => s.dismissReport('1'), throwsStateError);
    });

    test('tài khoản bị khóa thì không đặt lịch được nữa', () {
      final s = _service();
      final report = s.submitReport(
        type: ReportTarget.user,
        targetId: DemoUsers.tenant2.id,
        reason: 'Lừa đảo / giả mạo',
      );
      s.switchRole(UserRole.admin);
      s.resolveReport(report.id);
      expect(s.isUserLocked(DemoUsers.tenant2.id), isTrue);

      s.switchUser(DemoUsers.tenant2);
      expect(
        () => s.book(roomId: '1', time: _at(1, 9), phone: _phone),
        throwsStateError,
      );
    });
  });

  group('Liên hệ (trò chuyện)', () {
    test('nhắn lần đầu tạo cuộc trò chuyện mới với đúng chủ trọ', () {
      final s = _service();
      final before = s.contacts.count;
      final c = s.sendToOwner(roomId: '3', text: ' Phòng còn không ạ? ');
      expect(s.contacts.count, before + 1);
      expect(c.ownerId, DemoUsers.ownerB.id);
      expect(c.messages.single.text, 'Phòng còn không ạ?');
      expect(c.status, ContactStatus.newMessage);
    });

    test('nhắn tiếp về cùng phòng thì dùng lại cuộc trò chuyện cũ', () {
      final s = _service();
      final before = s.contacts.count;
      final c = s.sendToOwner(roomId: '1', text: 'Em hỏi thêm ạ');
      expect(s.contacts.count, before);
      expect(c.messages.length, 3); // 2 tin mẫu + tin mới
      expect(c.lastMessage!.text, 'Em hỏi thêm ạ');
      expect(c.status, ContactStatus.newMessage);
    });

    test('tin rỗng thì không tạo cuộc trò chuyện', () {
      final s = _service();
      final before = s.contacts.count;
      expect(() => s.sendToOwner(roomId: '3', text: '  '), throwsArgumentError);
      expect(s.contacts.count, before);
    });

    test('chủ trọ xem tin (đã đọc) rồi trả lời (đã trả lời)', () {
      final s = _service()..switchRole(UserRole.owner);
      expect(s.unreadContactCount(), 2);
      s.markContactRead('2');
      expect(s.contacts.findById('2')!.status, ContactStatus.read);
      expect(s.unreadContactCount(), 1);
      s.sendMessage('2', 'Có nhé em');
      expect(s.contacts.findById('2')!.status, ContactStatus.replied);
      expect(
        s.contacts.findById('2')!.lastMessage!.senderId,
        DemoUsers.ownerA.id,
      );
    });

    test('người ngoài cuộc trò chuyện không nhắn được', () {
      final s = _service()..switchUser(DemoUsers.ownerB);
      expect(() => s.sendMessage('1', 'xin chào'), throwsStateError);
    });

    test('danh sách trò chuyện: có hoạt động mới nhất lên đầu', () {
      // Đồng hồ chạy được: tin mẫu mới nhất (phòng 2) ghi lúc 09:05, nên phải
      // "đợi" tới 12:00 rồi mới nhắn thêm vào phòng 1 thì phòng 1 mới lên đầu.
      var current = _now;
      final s = InteractionService(clock: () => current);
      final before = s.contactsForCurrentUser();
      expect(before.length, 2); // phòng 1 và phòng 2
      expect(before.first.roomId, '2');

      current = DateTime(2026, 10, 22, 12);
      s.sendToOwner(roomId: '1', text: 'Tin mới nhất');
      expect(s.contactsForCurrentUser().first.roomId, '1');
    });
  });
}
