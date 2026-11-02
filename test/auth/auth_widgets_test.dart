// test/auth/auth_widgets_test.dart
// Kiểm tra RoleGuard, requireLogin, UserAvatar và các widget dùng chung của Auth.
// Chạy: flutter test test/auth/auth_widgets_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_test/features/auth/models/app_user.dart';
import 'package:flutter_application_test/features/auth/screens/login_screen.dart';
import 'package:flutter_application_test/features/auth/widgets/auth_input_decoration.dart';
import 'package:flutter_application_test/features/auth/widgets/role_guard.dart';
import 'package:flutter_application_test/features/auth/widgets/user_avt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

const _secret = 'Nội dung bí mật';

// Ảnh PNG 1x1 hợp lệ
const _validPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group('RoleGuard', () {
    Widget guard({List<UserRole>? allowed}) => allowed == null
        ? const RoleGuard(child: Text(_secret))
        : RoleGuard(allowed: allowed, child: const Text(_secret));

    testWidgets('chưa biết trạng thái: hiện đang tải, không mời đăng nhập', (tester) async {
      final h = AuthHarness(emitInitialState: false);
      await pumpApp(tester, h, guard());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Bạn cần đăng nhập'), findsNothing);
      expect(find.text(_secret), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Bạn cần đăng nhập'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập: chặn và mở được màn hình đăng nhập', (tester) async {
      await pumpApp(tester, AuthHarness(), guard());

      expect(find.text('Bạn cần đăng nhập'), findsOneWidget);
      expect(find.text(_secret), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('sai vai trò: chặn và nêu vai trò được phép', (tester) async {
      final h = AuthHarness(signedInAs: makeUser());
      await pumpApp(tester, h, guard(allowed: [UserRole.landlord, UserRole.admin]));

      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
      expect(find.text('Chức năng này chỉ dành cho: Chủ trọ, Quản trị viên'), findsOneWidget);
      expect(find.text(_secret), findsNothing);
    });

    testWidgets('đúng vai trò: hiện nội dung', (tester) async {
      final h = AuthHarness(signedInAs: makeUser(role: UserRole.landlord));
      await pumpApp(tester, h, guard(allowed: [UserRole.landlord]));
      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('không truyền allowed: vai trò nào cũng vào được', (tester) async {
      for (final role in UserRole.values) {
        await pumpApp(tester, AuthHarness(signedInAs: makeUser(role: role)), guard());
        expect(find.text(_secret), findsOneWidget, reason: role.name);
      }
    });

    testWidgets('bị đổi vai trò khi đang xem: chặn ngay', (tester) async {
      final h = AuthHarness(signedInAs: makeUser(role: UserRole.landlord));
      await pumpApp(tester, h, guard(allowed: [UserRole.landlord]));

      h.users.seed('u1', makeUser(role: UserRole.tenant).toMap());
      await tester.pump();
      await tester.pump();

      expect(find.text(_secret), findsNothing);
      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
    });

    testWidgets('bị khóa khi đang xem: chuyển sang yêu cầu đăng nhập', (tester) async {
      final h = AuthHarness(signedInAs: makeUser());
      await pumpApp(tester, h, guard());

      h.users.seed('u1', makeUser(disabled: true).toMap());
      await tester.pump();
      await tester.pump();

      expect(find.text(_secret), findsNothing);
      expect(find.text('Bạn cần đăng nhập'), findsOneWidget);
    });
  });

  group('requireLogin', () {
    late List<bool> results;

    Future<void> pumpAndCall(WidgetTester tester, AuthHarness h) async {
      results = [];
      await pumpApp(
        tester,
        h,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await requireLogin(context)),
              child: const Text('Hành động'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hành động'));
      await tester.pumpAndSettle();
    }

    testWidgets('đã đăng nhập: cho qua, không hỏi', (tester) async {
      await pumpAndCall(tester, AuthHarness(signedInAs: makeUser()));
      expect(results, [true]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('chọn Để sau: trả về false', (tester) async {
      await pumpAndCall(tester, AuthHarness());
      expect(find.text('Bạn cần đăng nhập'), findsOneWidget);

      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(results, [false]);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('vào đăng nhập rồi quay lại: trả về false', (tester) async {
      await pumpAndCall(tester, AuthHarness());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('đăng nhập thành công: trả về true', (tester) async {
      final h = AuthHarness();
      h.addEmailAccount(makeUser(), '123456');
      await pumpAndCall(tester, h);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Email'), 'an@test.com');
      await tester.enterText(fieldWithLabel('Mật khẩu'), '123456');
      await tester.tap(submitButton('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('mới mở app: chờ biết trạng thái rồi mới hỏi', (tester) async {
      await pumpApp(
        tester,
        AuthHarness(emitInitialState: false),
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => requireLogin(context),
              child: const Text('Hành động'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hành động'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('UserAvatar', () {
    Future<void> pumpAvatar(WidgetTester tester, AuthHarness h, AppUser user, {double? radius}) =>
        pumpApp(
          tester,
          h,
          Scaffold(
            body: radius == null ? UserAvatar(user: user) : UserAvatar(user: user, radius: radius),
          ),
        );

    CircleAvatar circle(WidgetTester tester) => tester.widget(find.byType(CircleAvatar));

    testWidgets('chưa có ảnh: hiện chữ cái đầu viết hoa', (tester) async {
      await pumpAvatar(tester, AuthHarness(), makeUser(fullName: 'an'));
      expect(find.text('A'), findsOneWidget);
      expect(circle(tester).backgroundImage, isNull);
    });

    testWidgets('tên rỗng: hiện dấu hỏi', (tester) async {
      await pumpAvatar(tester, AuthHarness(), makeUser(fullName: ''));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('màu nền theo trạng thái khóa', (tester) async {
      await pumpAvatar(tester, AuthHarness(), makeUser());
      expect(circle(tester).backgroundColor, Colors.blueAccent);

      await pumpAvatar(tester, AuthHarness(), makeUser(disabled: true));
      expect(circle(tester).backgroundColor, Colors.grey);
    });

    testWidgets('truyền radius', (tester) async {
      await pumpAvatar(tester, AuthHarness(), makeUser(), radius: 40);
      expect(circle(tester).radius, 40);
    });

    testWidgets('có ảnh hợp lệ: hiện ảnh, ẩn chữ cái', (tester) async {
      final h = AuthHarness();
      h.avatars.seed('u1', {'data': _validPng});
      await pumpAvatar(tester, h, makeUser());

      final image = circle(tester).backgroundImage as MemoryImage;
      expect(image.bytes, base64Decode(_validPng));
      expect(find.text('A'), findsNothing);
    });

    testWidgets('dữ liệu rỗng hoặc không phải Base64: hiện chữ cái, không lỗi', (tester) async {
      for (final data in ['', 'không phải base64!!!']) {
        final h = AuthHarness();
        h.avatars.seed('u1', {'data': data});
        await pumpAvatar(tester, h, makeUser());
        expect(tester.takeException(), isNull);
        expect(find.text('A'), findsOneWidget, reason: data);
      }
    });

    testWidgets('đúng Base64 nhưng không phải ảnh: quay về chữ cái', (tester) async {
      final h = AuthHarness();
      h.avatars.seed('u1', {'data': base64Encode(utf8.encode('không phải ảnh'))});
      await pumpAvatar(tester, h, makeUser());
      expect(circle(tester).onBackgroundImageError, isNotNull);

      circle(tester).onBackgroundImageError!(Exception('Lỗi giải mã'), null);
      await tester.pump();

      expect(circle(tester).backgroundImage, isNull);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('ảnh đổi theo thời gian thực', (tester) async {
      final h = AuthHarness();
      await pumpAvatar(tester, h, makeUser());
      expect(circle(tester).backgroundImage, isNull);

      h.avatars.seed('u1', {'data': _validPng});
      await tester.pump();
      await tester.pump();
      expect(circle(tester).backgroundImage, isNotNull);

      h.avatars.remove('u1');
      await tester.pump();
      await tester.pump();
      expect(circle(tester).backgroundImage, isNull);
    });

    testWidgets('đổi sang người khác thì theo dõi ảnh của người đó', (tester) async {
      final h = AuthHarness();
      h.avatars.seed('u1', {'data': _validPng});
      await pumpAvatar(tester, h, makeUser());
      expect(circle(tester).backgroundImage, isNotNull);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: UserAvatar(user: makeUser(id: 'u2', fullName: 'Bình')))),
      );
      await tester.pump();

      expect(circle(tester).backgroundImage, isNull);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('Widget dùng chung', () {
    Future<void> pump(WidgetTester tester, Widget child) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    testWidgets('AuthSubmitButton: bấm được khi rảnh', (tester) async {
      var pressed = 0;
      await pump(
        tester,
        AuthSubmitButton(label: 'Lưu', loading: false, onPressed: () => pressed++),
      );
      await tester.tap(find.text('Lưu'));
      expect(pressed, 1);
    });

    testWidgets('AuthSubmitButton: khóa nút và hiện đang tải', (tester) async {
      await pump(tester, AuthSubmitButton(label: 'Lưu', loading: true, onPressed: () {}));
      expect(find.text('Lưu'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    });

    testWidgets('GoogleSignInButton: bấm được khi rảnh', (tester) async {
      var pressed = 0;
      await pump(tester, GoogleSignInButton(loading: false, onPressed: () => pressed++));
      await tester.tap(find.text('Tiếp tục với Google'));
      expect(pressed, 1);
    });

    testWidgets('GoogleSignInButton: khóa nút và hiện đang tải', (tester) async {
      await pump(tester, GoogleSignInButton(loading: true, onPressed: () {}));
      expect(find.text('Tiếp tục với Google'), findsNothing);
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    });

    testWidgets('OrDivider hiện chữ hoặc', (tester) async {
      await pump(tester, const OrDivider());
      expect(find.text('hoặc'), findsOneWidget);
    });

    test('authInputDecoration gắn nhãn, biểu tượng và nút phụ', () {
      const suffix = Icon(Icons.visibility);
      final decoration = authInputDecoration(label: 'Email', icon: Icons.email, suffixIcon: suffix);
      expect(decoration.labelText, 'Email');
      expect((decoration.prefixIcon as Icon).icon, Icons.email);
      expect(decoration.suffixIcon, suffix);
    });

    group('showRolePickerDialog', () {
      late List<UserRole?> picked;

      Future<void> open(WidgetTester tester) async {
        picked = [];
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked.add(await showRolePickerDialog(context)),
              child: const Text('Chọn'),
            ),
          ),
        );
        await tester.tap(find.text('Chọn'));
        await tester.pumpAndSettle();
      }

      testWidgets('chỉ có khách thuê và chủ trọ, không có admin', (tester) async {
        await open(tester);
        expect(find.text('Khách thuê'), findsOneWidget);
        expect(find.text('Chủ trọ'), findsOneWidget);
        expect(find.text('Quản trị viên'), findsNothing);
      });

      testWidgets('trả về vai trò được chọn', (tester) async {
        await open(tester);
        await tester.tap(find.text('Chủ trọ'));
        await tester.pumpAndSettle();
        expect(picked, [UserRole.landlord]);
      });

      testWidgets('bấm ra ngoài thì trả về null', (tester) async {
        await open(tester);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(picked, [null]);
      });
    });
  });
}
