// test/appointment_detail_test.dart
// Kiểm tra màn "Chi tiết lịch hẹn" (US-07), dựng theo layout mẫu "Phiên đấu giá".
// Chạy: flutter test test/appointment_detail_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_test/features/contact/models/contact_models.dart';
import 'package:flutter_application_test/features/contact/screens/appointment_detail_screen.dart';
import 'package:flutter_application_test/features/contact/screens/contact_chat_screen.dart';
import 'package:flutter_application_test/features/contact/services/interaction_service.dart';
import 'package:flutter_application_test/features/contact/widgets/appointment_info_card.dart';
import 'package:flutter_application_test/features/contact/widgets/countdown_timer_box.dart';
import 'package:flutter_application_test/features/contact/widgets/message_history_box.dart';
import 'package:flutter_application_test/features/contact/widgets/pill_action_button.dart';
import 'package:flutter_application_test/features/contact/widgets/room_image_box.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tạo dữ liệu sạch với đồng hồ cố định rồi gán làm bản dùng chung của app.
InteractionService _fresh() {
  final service = InteractionService(clock: () => DateTime(2026, 10, 22, 8));
  InteractionService.instance = service;
  return service;
}

/// Lịch hẹn của người thuê mẫu, cách giờ thật của máy 3 tiếng 30 phút.
/// Đồng hồ đếm ngược của màn này tính theo giờ thật (DateTime.now) chứ không theo
/// đồng hồ cố định của service, nên lịch hẹn mẫu (tháng 10/2026) không dùng được.
Appointment _soon(InteractionService s) => s.appointments.add(
  Appointment(
    id: s.appointments.nextId(),
    roomId: '1',
    tenantId: DemoUsers.tenant.id,
    ownerId: DemoUsers.ownerA.id,
    appointmentTime: DateTime.now().add(const Duration(hours: 3, minutes: 30)),
    note: 'Xem phòng sau giờ học',
    phone: DemoUsers.tenant.phone,
  ),
);

/// Mở màn chi tiết của lịch hẹn [appointmentId] trên màn hình đủ cao để
/// ListView dựng hết các khối (mặc định màn hình test chỉ cao 600).
Future<void> _show(WidgetTester tester, String appointmentId) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: AppointmentDetailScreen(appointmentId: appointmentId)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('US-07 - Màn Chi tiết lịch hẹn', () {
    testWidgets('lịch sắp tới: đủ 5 khối theo layout mẫu "Phiên đấu giá"', (
      tester,
    ) async {
      final s = _fresh();
      final a = _soon(s);
      await _show(tester, a.id);

      // 1. Ảnh lớn
      expect(find.byType(RoomImageBox), findsOneWidget);
      // 2. Thẻ thông tin: mã, giờ hẹn, trạng thái
      expect(find.byType(AppointmentInfoCard), findsOneWidget);
      expect(find.text('Mã lịch hẹn: #${a.id}'), findsOneWidget);
      expect(find.text('Trạng thái: Chờ xác nhận'), findsOneWidget);
      // 3. Đồng hồ đếm ngược HH:MM:SS (còn 3 giờ 29 phút hoặc 3 giờ 30 phút)
      expect(find.byType(CountdownTimerBox), findsOneWidget);
      expect(find.text('Còn lại đến giờ xem phòng'), findsOneWidget);
      expect(find.text('Đã đến giờ hẹn'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^0[23]:\d{2}:\d{2}$').hasMatch(w.data ?? ''),
        ),
        findsOneWidget,
      );
      // 4. Lịch sử trao đổi với chủ trọ (cuộc trò chuyện mẫu có 2 tin)
      expect(find.byType(MessageHistoryBox), findsOneWidget);
      expect(find.text('Trao đổi với chủ trọ'), findsOneWidget);
      expect(find.text('Tin: 2'), findsOneWidget);
      // 5. Nút hành động
      expect(find.byType(PillActionButton), findsOneWidget);
      expect(find.text('Nhắn chủ trọ'), findsOneWidget);

      // Thông tin phụ: chủ trọ, người thuê, ghi chú
      expect(find.text('Nguyễn Văn A · 0901 234 567'), findsOneWidget);
      expect(find.text('Trần Minh Anh · 0987 654 321'), findsOneWidget);
      expect(find.text('Xem phòng sau giờ học'), findsOneWidget);
    });

    testWidgets('lịch đã hoàn thành: không còn đồng hồ đếm ngược', (
      tester,
    ) async {
      _fresh();
      await _show(tester, '3'); // lịch mẫu đã hoàn thành

      expect(find.text('Trạng thái: Đã hoàn thành'), findsOneWidget);
      expect(find.byType(CountdownTimerBox), findsNothing);
      expect(find.byType(MessageHistoryBox), findsOneWidget);
    });

    testWidgets('lịch bị từ chối: hiện lý do, chưa có tin nhắn thì báo trống', (
      tester,
    ) async {
      _fresh();
      await _show(tester, '4'); // lịch mẫu bị từ chối, người thuê chưa nhắn về phòng này

      expect(find.text('Trạng thái: Đã từ chối'), findsOneWidget);
      expect(find.text('Lý do từ chối'), findsOneWidget);
      expect(find.text('Phòng đã có người đặt cọc'), findsOneWidget);
      expect(find.byType(CountdownTimerBox), findsNothing);
      expect(find.text('Tin: 0'), findsOneWidget);
      expect(find.text('Chưa có tin nhắn nào.'), findsOneWidget);
    });

    testWidgets('lịch hẹn không tồn tại: báo "Không tìm thấy lịch hẹn."', (
      tester,
    ) async {
      _fresh();
      await _show(tester, 'khong-co');

      expect(find.text('Không tìm thấy lịch hẹn.'), findsOneWidget);
      expect(find.byType(PillActionButton), findsNothing);
    });

    testWidgets('nút nhắn tin đổi theo vai trò: người thuê, chủ trọ, admin', (
      tester,
    ) async {
      final s = _fresh();
      await _show(tester, '1');
      expect(find.text('Nhắn chủ trọ'), findsOneWidget);

      s.switchRole(UserRole.owner);
      await tester.pumpAndSettle();
      expect(find.text('Nhắn người thuê'), findsOneWidget);
      expect(find.text('Nhắn chủ trọ'), findsNothing);

      s.switchRole(UserRole.admin);
      await tester.pumpAndSettle();
      expect(find.byType(PillActionButton), findsNothing);
    });

    testWidgets('có tin nhắn mới thì khung trao đổi tự cập nhật', (
      tester,
    ) async {
      final s = _fresh();
      await _show(tester, '1');
      expect(find.text('Tin: 2'), findsOneWidget);

      s.sendToOwner(roomId: '1', text: 'Em sẽ đến đúng giờ ạ');
      await tester.pump();

      expect(find.text('Tin: 3'), findsOneWidget);
      expect(find.text('Em sẽ đến đúng giờ ạ'), findsOneWidget);
    });

    testWidgets('bấm "Nhắn chủ trọ" mở màn nhắn tin của phòng', (tester) async {
      _fresh();
      await _show(tester, '1');

      await tester.tap(find.text('Nhắn chủ trọ'));
      await tester.pumpAndSettle();

      expect(find.byType(ContactChatScreen), findsOneWidget);
    });
  });
}