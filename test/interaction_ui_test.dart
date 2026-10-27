// test/interaction_ui_test.dart
// Kiểm tra nhanh các luồng giao diện chính của module "Tương tác & phản hồi người dùng".
// Chạy: flutter test test/interaction_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_test/features/contact/screens/booking_screen.dart';
import 'package:flutter_application_test/features/contact/screens/contact_chat_screen.dart';
import 'package:flutter_application_test/features/contact/screens/interaction_home_screen.dart';
import 'package:flutter_application_test/features/contact/screens/review_report_screen.dart';
import 'package:flutter_application_test/features/contact/services/interaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tạo dữ liệu sạch với đồng hồ cố định rồi gán làm bản dùng chung của app.
InteractionService _fresh() {
  final service = InteractionService(clock: () => DateTime(2026, 10, 22, 8));
  InteractionService.instance = service;
  return service;
}

Future<void> _show(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'đổi vai trò thì giao diện đổi theo (người thuê, chủ trọ, admin)',
    (tester) async {
      final service = _fresh();
      await _show(tester, const InteractionHomeScreen());

      // Người thuê: có tab "Phòng" và chia lịch hẹn Sắp tới / Đã qua.
      expect(find.text('Lịch hẹn'), findsOneWidget);
      expect(find.text('Phòng'), findsOneWidget);
      expect(find.textContaining('Sắp tới'), findsOneWidget);

      final roleBar = find.byType(SegmentedButton<UserRole>);

      // Chủ trọ: không có tab "Phòng", thấy nút xác nhận lịch hẹn.
      await tester.tap(
        find.descendant(of: roleBar, matching: find.text('Chủ trọ')),
      );
      await tester.pumpAndSettle();
      expect(service.role, UserRole.owner);
      expect(find.text('Phòng'), findsNothing);
      expect(find.text('Xác nhận'), findsWidgets);

      // Admin: có tab "Báo cáo" và nút "Bỏ qua".
      await tester.tap(
        find.descendant(of: roleBar, matching: find.text('Admin')),
      );
      await tester.pumpAndSettle();
      expect(service.role, UserRole.admin);
      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsWidgets);
    },
  );

  testWidgets('đặt lịch xem phòng -> màn "Đặt lịch thành công!"', (
    tester,
  ) async {
    final service = _fresh();
    final before = service.appointments.count;
    await _show(tester, const BookingScreen(roomId: '1'));

    await tester.tap(find.text('Xác nhận đặt lịch'));
    await tester.pumpAndSettle();

    expect(find.text('Đặt lịch thành công!'), findsOneWidget);
    expect(service.appointments.count, before + 1);
  });

  testWidgets(
    'nhắn tin cho chủ trọ: tạo cuộc trò chuyện khi gửi tin đầu tiên',
    (tester) async {
      final service = _fresh();
      final before = service.contacts.count;
      await _show(tester, const ContactChatScreen(roomId: '3'));
      expect(find.textContaining('Chưa có tin nhắn nào'), findsOneWidget);
      expect(service.contacts.count, before); // chưa gửi thì chưa tạo

      await tester.enterText(
        find.byType(TextField),
        'Phòng còn trống không ạ?',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Phòng còn trống không ạ?'), findsOneWidget);
      expect(service.contacts.count, before + 1);
    },
  );

  testWidgets(
    'đánh giá: chưa chọn sao thì chưa gửi được, chọn sao rồi gửi thành công',
    (tester) async {
      final service = _fresh();
      await _show(tester, const ReviewReportScreen(appointmentId: '3'));

      OutlinedButton submitButton() => tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Gửi đánh giá'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
      );

      expect(submitButton().onPressed, isNull);

      await tester.tap(find.byIcon(Icons.star_border_rounded).at(3)); // 4 sao
      await tester.pump();
      expect(submitButton().onPressed, isNotNull);

      await tester.enterText(find.byType(TextField).first, 'Phòng sạch');
      await tester.ensureVisible(find.text('Gửi đánh giá'));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();

      final review = service.reviewForAppointment('3');
      expect(review?.rating, 4);
      expect(review?.comment, 'Phòng sạch');
    },
  );
}
