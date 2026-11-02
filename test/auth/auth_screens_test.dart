// test/auth/auth_screens_test.dart
// Kiểm tra các màn hình Auth qua thao tác người dùng, chạy trên Firebase giả.
// Chạy: flutter test test/auth/auth_screens_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_test/features/auth/models/app_user.dart';
import 'package:flutter_application_test/features/auth/screens/account_screen.dart';
import 'package:flutter_application_test/features/auth/screens/admin_users_screen.dart';
import 'package:flutter_application_test/features/auth/screens/edit_profile_screen.dart';
import 'package:flutter_application_test/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter_application_test/features/auth/screens/login_screen.dart';
import 'package:flutter_application_test/features/auth/screens/register_screen.dart';
import 'package:flutter_application_test/features/auth/widgets/user_avt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

const _password = '123456';
const _serverError = 'Lỗi máy chủ (permission-denied)';

FakeUser _googleUser() => FakeUser(
      uid: 'g1',
      email: 'g@test.com',
      displayName: 'Google User',
      providers: ['google.com'],
    );

// Vòng xoay của nút vẫn chạy sau hộp thoại nên không dùng được pumpAndSettle
Future<void> pumpDialogOpen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('LoginScreen', () {
    Future<void> fillAndSubmit(WidgetTester tester, String email, String password) async {
      await tester.enterText(fieldWithLabel('Email'), email);
      await tester.enterText(fieldWithLabel('Mật khẩu'), password);
      await tester.tap(submitButton('Đăng nhập'));
      await tester.pumpAndSettle();
    }

    testWidgets('bỏ trống: báo lỗi, không gọi đăng nhập', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const LoginScreen());

      await tester.tap(submitButton('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(h.auth.signInCalls, 0);
    });

    testWidgets('email sai định dạng: báo lỗi, không gọi đăng nhập', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const LoginScreen());
      await fillAndSubmit(tester, 'abc', _password);

      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(h.auth.signInCalls, 0);
    });

    testWidgets('thành công: chào người dùng và đóng màn hình', (tester) async {
      final h = AuthHarness();
      h.addEmailAccount(makeUser(), _password);
      await openScreen(tester, h, const LoginScreen());
      await fillAndSubmit(tester, 'an@test.com', _password);

      expect(find.text('Xin chào An Nguyễn!'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(h.service.currentUser.value?.id, 'u1');
    });

    testWidgets('sai mật khẩu: báo lỗi và ở lại', (tester) async {
      final h = AuthHarness();
      h.addEmailAccount(makeUser(), _password);
      await openScreen(tester, h, const LoginScreen());
      await fillAndSubmit(tester, 'an@test.com', 'sai-mat-khau');

      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('đang gửi: khóa nút, xong thì mở lại', (tester) async {
      final h = AuthHarness();
      h.auth.signInGate = Completer<void>();
      await openScreen(tester, h, const LoginScreen());
      await tester.enterText(fieldWithLabel('Email'), 'an@test.com');
      await tester.enterText(fieldWithLabel('Mật khẩu'), _password);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsNothing);

      h.auth.signInGate!.complete();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);
    });

    testWidgets('nút con mắt ẩn hiện mật khẩu', (tester) async {
      await openScreen(tester, AuthHarness(), const LoginScreen());
      bool obscured() => tester
          .widget<EditableText>(
            find.descendant(of: fieldWithLabel('Mật khẩu'), matching: find.byType(EditableText)),
          )
          .obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('mở màn hình quên mật khẩu', (tester) async {
      await openScreen(tester, AuthHarness(), const LoginScreen());
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('chuyển sang đăng ký', (tester) async {
      await openScreen(tester, AuthHarness(), const LoginScreen());
      await tester.tap(find.text('Đăng ký ngay'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Google lần đầu: hỏi vai trò rồi tạo hồ sơ', (tester) async {
      final h = AuthHarness()..googleUser = _googleUser();
      await openScreen(tester, h, const LoginScreen());

      await tester.tap(find.text('Tiếp tục với Google'));
      await pumpDialogOpen(tester);
      await tester.tap(find.text('Chủ trọ'));
      await tester.pumpAndSettle();

      expect(find.text('Xin chào Google User!'), findsOneWidget);
      expect(h.users.docs['g1']?['role'], 'landlord');
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Google bị hủy: báo lỗi, ở lại và bấm lại được', (tester) async {
      final h = AuthHarness()..googleUser = _googleUser();
      await openScreen(tester, h, const LoginScreen());

      await tester.tap(find.text('Tiếp tục với Google'));
      await pumpDialogOpen(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Đã hủy đăng nhập bằng Google'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
    });
  });

  group('RegisterScreen', () {
    Future<void> fill(
      WidgetTester tester, {
      String name = 'An',
      String email = 'an@test.com',
      String phone = '',
      String password = _password,
      String? confirm,
    }) async {
      await tester.enterText(fieldWithLabel('Họ và tên'), name);
      await tester.enterText(fieldWithLabel('Email'), email);
      await tester.enterText(fieldWithLabel('Số điện thoại (không bắt buộc)'), phone);
      await tester.enterText(fieldWithLabel('Mật khẩu'), password);
      await tester.enterText(fieldWithLabel('Nhập lại mật khẩu'), confirm ?? password);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(submitButton('Đăng ký'));
      await tester.pumpAndSettle();
    }

    testWidgets('bỏ trống: báo lỗi, không tạo tài khoản', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const RegisterScreen());
      await submit(tester);

      expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(h.auth.registerCalls, 0);
    });

    testWidgets('mật khẩu nhập lại không khớp', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const RegisterScreen());
      await fill(tester, confirm: 'khac-mat-khau');
      await submit(tester);

      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
      expect(h.auth.registerCalls, 0);
    });

    testWidgets('số điện thoại sai định dạng', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const RegisterScreen());
      await fill(tester, phone: '123');
      await submit(tester);

      expect(find.text('Số điện thoại phải gồm 10 số, bắt đầu bằng 0'), findsOneWidget);
      expect(h.auth.registerCalls, 0);
    });

    testWidgets('không có lựa chọn quản trị viên', (tester) async {
      await openScreen(tester, AuthHarness(), const RegisterScreen());
      expect(find.text('Quản trị viên'), findsNothing);
    });

    testWidgets('mặc định là khách thuê: báo thành công và đóng màn hình', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const RegisterScreen());
      await fill(tester);
      await submit(tester);

      expect(find.text('Đăng ký thành công!'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(h.users.docs.values.single['role'], 'tenant');
      expect(h.users.docs.values.single['phone'], isNull);
    });

    testWidgets('chọn chủ trọ thì lưu vai trò chủ trọ', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const RegisterScreen());
      await tester.tap(find.text('Chủ trọ'));
      await tester.pumpAndSettle();
      await fill(tester, phone: '0912345678');
      await submit(tester);

      expect(h.users.docs.values.single['role'], 'landlord');
      expect(h.users.docs.values.single['phone'], '0912345678');
    });

    testWidgets('email đã dùng: báo lỗi và ở lại', (tester) async {
      final h = AuthHarness();
      h.addEmailAccount(makeUser(), _password);
      await openScreen(tester, h, const RegisterScreen());
      await fill(tester);
      await submit(tester);

      expect(find.text('Email đã được sử dụng'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('Google dùng luôn vai trò đang chọn, không hỏi lại', (tester) async {
      final h = AuthHarness()..googleUser = _googleUser();
      await openScreen(tester, h, const RegisterScreen());
      await tester.tap(find.text('Chủ trọ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.text('Đăng nhập bằng Google thành công!'), findsOneWidget);
      expect(h.users.docs['g1']?['role'], 'landlord');
    });

    testWidgets('Google lỗi: báo lỗi và ở lại', (tester) async {
      final h = AuthHarness()..googleError = FirebaseAuthException(code: 'network-request-failed');
      await openScreen(tester, h, const RegisterScreen());

      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();

      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('chuyển sang đăng nhập', (tester) async {
      await openScreen(tester, AuthHarness(), const RegisterScreen());
      await tester.tap(find.widgetWithText(TextButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('email sai: báo lỗi, không gửi', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const ForgotPasswordScreen());
      await tester.enterText(fieldWithLabel('Email'), 'abc');
      await tester.tap(submitButton('Gửi yêu cầu'));
      await tester.pumpAndSettle();

      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(h.auth.resetEmails, isEmpty);
    });

    testWidgets('thành công: báo đã gửi, bấm OK thì đóng màn hình', (tester) async {
      final h = AuthHarness();
      await openScreen(tester, h, const ForgotPasswordScreen());
      await tester.enterText(fieldWithLabel('Email'), ' an@test.com ');
      await tester.tap(submitButton('Gửi yêu cầu'));
      await pumpDialogOpen(tester);

      expect(h.auth.resetEmails, ['an@test.com']);
      expect(find.text('Đã gửi yêu cầu'), findsOneWidget);
      expect(find.textContaining('an@test.com'), findsWidgets);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsNothing);
    });

    testWidgets('gửi lỗi: báo lỗi và ở lại', (tester) async {
      final h = AuthHarness();
      h.auth.resetError = FirebaseAuthException(code: 'too-many-requests');
      await openScreen(tester, h, const ForgotPasswordScreen());
      await tester.enterText(fieldWithLabel('Email'), 'an@test.com');
      await tester.tap(submitButton('Gửi yêu cầu'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn thử quá nhiều lần, vui lòng thử lại sau'), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });

  group('EditProfileScreen', () {
    final user = makeUser(phone: '0912345678');
    const phoneLabel = 'Số điện thoại (không bắt buộc)';

    Future<void> save(WidgetTester tester) async {
      await tester.tap(submitButton('Lưu'));
      await tester.pumpAndSettle();
    }

    testWidgets('điền sẵn thông tin hiện tại', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      expect(find.text('An Nguyễn'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
    });

    testWidgets('xóa tên: báo lỗi, không lưu', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      await tester.enterText(fieldWithLabel('Họ và tên'), '  ');
      await save(tester);

      expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
      expect(h.users.docs['u1']?['fullName'], 'An Nguyễn');
    });

    testWidgets('số điện thoại sai: báo lỗi, không lưu', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      await tester.enterText(fieldWithLabel(phoneLabel), '123');
      await save(tester);

      expect(find.text('Số điện thoại phải gồm 10 số, bắt đầu bằng 0'), findsOneWidget);
      expect(h.users.docs['u1']?['phone'], '0912345678');
    });

    testWidgets('thành công: báo đã lưu, đóng màn hình, cập nhật người dùng', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      await tester.enterText(fieldWithLabel('Họ và tên'), 'Tên mới');
      await tester.enterText(fieldWithLabel(phoneLabel), '0987654321');
      await save(tester);

      expect(find.text('Đã cập nhật thông tin'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(h.service.currentUser.value?.fullName, 'Tên mới');
      expect(h.service.currentUser.value?.phone, '0987654321');
    });

    testWidgets('xóa số điện thoại: lưu null', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      await tester.enterText(fieldWithLabel(phoneLabel), '');
      await save(tester);

      expect(h.users.docs['u1']?['phone'], isNull);
    });

    testWidgets('ghi lỗi: báo lỗi, ở lại và lưu lại được', (tester) async {
      final h = AuthHarness(signedInAs: user);
      await openScreen(tester, h, EditProfileScreen(user: user));
      await tester.enterText(fieldWithLabel('Họ và tên'), 'Tên mới');
      h.users.writeError = firestoreError();
      await save(tester);

      expect(find.text(_serverError), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);

      h.users.writeError = null;
      await save(tester);
      expect(find.byType(EditProfileScreen), findsNothing);
    });
  });

  group('AccountScreen', () {
    const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');

    void mockPicker(WidgetTester tester, Future<Object?> Function() result) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pickerChannel, (_) => result());
      addTearDown(() => messenger.setMockMethodCallHandler(pickerChannel, null));
    }

    Future<void> openAvatarMenu(WidgetTester tester) async {
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();
    }

    Future<void> pickFromGallery(WidgetTester tester) async {
      await openAvatarMenu(tester);
      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();
    }

    // Đọc file là việc thật, không chạy theo đồng hồ giả của test nên phải chờ
    Future<void> waitForText(WidgetTester tester, String text) async {
      for (var i = 0; i < 100 && find.text(text).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.text(text), findsOneWidget);
    }

    Future<String> tempImage(WidgetTester tester, int size) async {
      final path = await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('auth_test');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/avatar.jpg');
        await file.writeAsBytes(Uint8List(size));
        return file.path;
      });
      return path!;
    }

    testWidgets('chưa biết trạng thái: hiện đang tải', (tester) async {
      final h = AuthHarness(emitInitialState: false);
      await pumpApp(tester, h, const AccountScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Bạn chưa đăng nhập'), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Bạn chưa đăng nhập'), findsOneWidget);
    });

    testWidgets('khách: mời đăng nhập, mở được đăng nhập', (tester) async {
      await pumpApp(tester, AuthHarness(), const AccountScreen());
      expect(find.text('Bạn chưa đăng nhập'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('khách: mở được đăng ký', (tester) async {
      await pumpApp(tester, AuthHarness(), const AccountScreen());
      await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('đã đăng nhập: hiện đủ thông tin', (tester) async {
      final h = AuthHarness(
        signedInAs: makeUser(phone: '0912345678', role: UserRole.landlord),
      );
      await pumpApp(tester, h, const AccountScreen());

      expect(find.text('An Nguyễn'), findsOneWidget);
      expect(find.text('an@test.com'), findsOneWidget);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('Chủ trọ'), findsOneWidget);
    });

    testWidgets('chưa có số điện thoại: hiện Chưa cập nhật', (tester) async {
      await pumpApp(tester, AuthHarness(signedInAs: makeUser()), const AccountScreen());
      expect(find.text('Chưa cập nhật'), findsOneWidget);
    });

    testWidgets('sửa thông tin: mở màn hình và cập nhật khi quay về', (tester) async {
      final h = AuthHarness(signedInAs: makeUser());
      await pumpApp(tester, h, const AccountScreen());

      await tester.tap(find.text('Sửa thông tin'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);

      await tester.enterText(fieldWithLabel('Họ và tên'), 'Tên mới');
      await tester.tap(submitButton('Lưu'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Tên mới'), findsOneWidget);
    });

    testWidgets('tài khoản Google: ẩn đổi mật khẩu', (tester) async {
      final h = AuthHarness(signedInAs: makeUser(), providers: ['google.com']);
      await pumpApp(tester, h, const AccountScreen());
      expect(find.text('Đổi mật khẩu'), findsNothing);
    });

    group('Đổi mật khẩu', () {
      Future<void> openDialog(WidgetTester tester, AuthHarness h) async {
        await pumpApp(tester, h, const AccountScreen());
        await tester.tap(find.text('Đổi mật khẩu'));
        await tester.pumpAndSettle();
      }

      testWidgets('bấm Hủy: không gửi email', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        await openDialog(tester, h);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(h.auth.resetEmails, isEmpty);
      });

      testWidgets('bấm Gửi: gửi tới email của tài khoản', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        await openDialog(tester, h);
        await tester.tap(find.text('Gửi'));
        await tester.pumpAndSettle();

        expect(h.auth.resetEmails, ['an@test.com']);
        expect(find.text('Đã gửi link tới an@test.com'), findsOneWidget);
      });

      testWidgets('gửi lỗi: hiện thông báo', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        h.auth.resetError = FirebaseAuthException(code: 'network-request-failed');
        await openDialog(tester, h);
        await tester.tap(find.text('Gửi'));
        await tester.pumpAndSettle();
        expect(find.text('Không có kết nối mạng'), findsOneWidget);
      });
    });

    testWidgets('chỉ admin thấy và mở được quản lý người dùng', (tester) async {
      await pumpApp(tester, AuthHarness(signedInAs: makeUser()), const AccountScreen());
      expect(find.text('Quản lý người dùng'), findsNothing);

      final admin = AuthHarness(signedInAs: makeUser(role: UserRole.admin));
      await pumpApp(tester, admin, const AccountScreen());
      await tester.pump();
      await tester.tap(find.text('Quản lý người dùng'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersScreen), findsOneWidget);
    });

    testWidgets('đăng xuất: quay về màn hình khách', (tester) async {
      final h = AuthHarness(signedInAs: makeUser());
      await pumpApp(tester, h, const AccountScreen());

      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();

      expect(h.auth.currentUser, isNull);
      expect(find.text('Bạn chưa đăng nhập'), findsOneWidget);
    });

    group('Ảnh đại diện', () {
      testWidgets('menu có thư viện, chụp ảnh và xóa ảnh', (tester) async {
        await pumpApp(tester, AuthHarness(signedInAs: makeUser()), const AccountScreen());
        await openAvatarMenu(tester);
        expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);
        expect(find.text('Chụp ảnh'), findsOneWidget);
        expect(find.text('Xóa ảnh đại diện'), findsOneWidget);
      });

      testWidgets('xóa ảnh thành công', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        h.avatars.seed('u1', {'data': 'abc'});
        await pumpApp(tester, h, const AccountScreen());
        await openAvatarMenu(tester);
        await tester.tap(find.text('Xóa ảnh đại diện'));
        await tester.pumpAndSettle();

        expect(h.avatars.docs, isEmpty);
        expect(find.text('Đã xóa ảnh đại diện'), findsOneWidget);
      });

      testWidgets('xóa ảnh lỗi: hiện thông báo', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        h.avatars.writeError = firestoreError();
        await pumpApp(tester, h, const AccountScreen());
        await openAvatarMenu(tester);
        await tester.tap(find.text('Xóa ảnh đại diện'));
        await tester.pumpAndSettle();
        expect(find.text(_serverError), findsOneWidget);
      });

      testWidgets('hủy chọn ảnh: không đổi gì', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        mockPicker(tester, () async => null);
        await pumpApp(tester, h, const AccountScreen());
        await pickFromGallery(tester);

        expect(h.avatars.docs, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('thư viện ảnh báo lỗi, ví dụ không được cấp quyền', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        mockPicker(tester, () async => throw PlatformException(code: 'photo_access_denied'));
        await pumpApp(tester, h, const AccountScreen());
        await pickFromGallery(tester);

        expect(find.text('Không chọn được ảnh, vui lòng thử lại'), findsOneWidget);
        expect(h.avatars.docs, isEmpty);
      });

      testWidgets('chọn ảnh: lưu dạng Base64', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        await pumpApp(tester, h, const AccountScreen());
        final path = await tempImage(tester, 100);
        mockPicker(tester, () async => path);

        await pickFromGallery(tester);
        await waitForText(tester, 'Đã cập nhật ảnh đại diện');

        expect(h.avatars.docs['u1']?['data'], base64Encode(Uint8List(100)));
      });

      testWidgets('ảnh quá 500KB: báo lỗi, không lưu', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        await pumpApp(tester, h, const AccountScreen());
        final path = await tempImage(tester, 500 * 1024 + 1);
        mockPicker(tester, () async => path);

        await pickFromGallery(tester);
        await waitForText(tester, 'Ảnh quá lớn, vui lòng chọn ảnh khác');

        expect(h.avatars.docs, isEmpty);
      });

      testWidgets('lưu ảnh lỗi: hiện lỗi máy chủ', (tester) async {
        final h = AuthHarness(signedInAs: makeUser());
        h.avatars.writeError = firestoreError();
        await pumpApp(tester, h, const AccountScreen());
        final path = await tempImage(tester, 100);
        mockPicker(tester, () async => path);

        await pickFromGallery(tester);
        await waitForText(tester, _serverError);
      });
    });
  });

  group('AdminUsersScreen', () {
    final admin = makeUser(id: 'admin', fullName: 'Quản Lý', email: 'admin@test.com', role: UserRole.admin);
    final tenant = makeUser(id: 'u1', fullName: 'An', email: 'an@test.com', phone: '0911111111');
    final landlord = makeUser(
      id: 'u2',
      fullName: 'Bình',
      email: 'binh@test.com',
      phone: '0922222222',
      role: UserRole.landlord,
    );
    final locked = makeUser(id: 'u3', fullName: 'Cường', email: 'cuong@test.com', disabled: true);

    Future<AuthHarness> pumpAdmin(WidgetTester tester) async {
      final h = AuthHarness(signedInAs: admin);
      h.seedUser(admin, createdAt: 1);
      h.seedUser(tenant, createdAt: 2);
      h.seedUser(landlord, createdAt: 3);
      h.seedUser(locked, createdAt: 4);
      await pumpApp(tester, h, const AdminUsersScreen());
      // Đủ rộng để mọi nút lọc cùng hiện, không phải cuộn ngang
      tester.view.physicalSize = const Size(1400, 2000);
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester, String name, String item) async {
      final card = find.ancestor(of: find.text(name), matching: find.byType(Card));
      await tester.tap(
        find.descendant(of: card, matching: find.byType(PopupMenuButton<String>)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('mặc định hiện người chưa khóa, mới tạo xếp trước', (tester) async {
      await pumpAdmin(tester);
      final names = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data)
          .toList();
      expect(names, ['Bình', 'An', 'Quản Lý (bạn)']);
    });

    testWidgets('dòng của chính mình không có menu', (tester) async {
      await pumpAdmin(tester);
      expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
      final mine = find.ancestor(of: find.text('Quản Lý (bạn)'), matching: find.byType(Card));
      expect(
        find.descendant(of: mine, matching: find.byType(PopupMenuButton<String>)),
        findsNothing,
      );
    });

    testWidgets('tìm theo tên, email, số điện thoại, không phân biệt hoa thường', (tester) async {
      await pumpAdmin(tester);
      for (final query in ['BÌNH', 'binh@', '0922']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump();
        expect(find.text('Bình'), findsOneWidget, reason: query);
        expect(find.text('An'), findsNothing, reason: query);
      }
    });

    testWidgets('không tìm thấy', (tester) async {
      await pumpAdmin(tester);
      await tester.enterText(find.byType(TextField), 'không có ai');
      await tester.pump();
      expect(find.text('Không có người dùng nào'), findsOneWidget);
    });

    testWidgets('lọc theo vai trò, bấm Tất cả thì bỏ lọc', (tester) async {
      await pumpAdmin(tester);
      await tapChip(tester, 'Chủ trọ');
      expect(find.text('Bình'), findsOneWidget);
      expect(find.text('An'), findsNothing);

      await tapChip(tester, 'Tất cả');
      expect(find.text('An'), findsOneWidget);
    });

    testWidgets('tài khoản khóa chỉ nằm trong mục đã khóa', (tester) async {
      final h = await pumpAdmin(tester);
      expect(find.text('Cường'), findsNothing);

      await tapChip(tester, 'Tài khoản đã khóa');
      expect(find.text('Cường'), findsOneWidget);
      expect(find.text('Đã khóa'), findsOneWidget);
      expect(find.text('Bình'), findsNothing);

      h.users.seed('u3', {...locked.toMap(), 'disabled': false});
      await tester.pump();
      await tester.pump();
      expect(find.text('Không có tài khoản nào bị khóa'), findsOneWidget);
    });

    testWidgets('đổi vai trò', (tester) async {
      final h = await pumpAdmin(tester);
      await openMenu(tester, 'An', 'Đổi vai trò');
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Chủ trọ'));
      await tester.pumpAndSettle();

      expect(h.users.docs['u1']?['role'], 'landlord');
      expect(find.text('Đã đổi An thành Chủ trọ'), findsOneWidget);
    });

    testWidgets('chọn lại vai trò cũ: không ghi, không báo', (tester) async {
      final h = await pumpAdmin(tester);
      await openMenu(tester, 'An', 'Đổi vai trò');
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Khách thuê'));
      await tester.pumpAndSettle();

      expect(h.users.docs['u1']?['role'], 'tenant');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('khóa tài khoản: bấm Hủy thì giữ nguyên', (tester) async {
      final h = await pumpAdmin(tester);
      await openMenu(tester, 'An', 'Khóa tài khoản');
      expect(find.text('Khóa tài khoản?'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(h.users.docs['u1']?['disabled'], isFalse);
    });

    testWidgets('khóa tài khoản: xác nhận thì chuyển sang mục đã khóa', (tester) async {
      final h = await pumpAdmin(tester);
      await openMenu(tester, 'An', 'Khóa tài khoản');
      await tester.tap(find.widgetWithText(TextButton, 'Khóa'));
      await tester.pumpAndSettle();

      expect(h.users.docs['u1']?['disabled'], isTrue);
      expect(find.text('Đã khóa An'), findsOneWidget);
      expect(find.widgetWithText(Card, 'An'), findsNothing);
    });

    testWidgets('mở khóa tài khoản', (tester) async {
      final h = await pumpAdmin(tester);
      await tapChip(tester, 'Tài khoản đã khóa');
      await openMenu(tester, 'Cường', 'Mở khóa tài khoản');
      expect(find.text('Mở khóa tài khoản?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Mở khóa'));
      await tester.pumpAndSettle();

      expect(h.users.docs['u3']?['disabled'], isFalse);
      expect(find.text('Đã mở khóa Cường'), findsOneWidget);
    });

    testWidgets('Rules chặn: hiện lỗi máy chủ', (tester) async {
      final h = await pumpAdmin(tester);
      h.users.writeError = firestoreError();
      await openMenu(tester, 'An', 'Đổi vai trò');
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Chủ trọ'));
      await tester.pumpAndSettle();

      expect(find.text(_serverError), findsOneWidget);
    });

    testWidgets('không tải được danh sách: hiện lỗi', (tester) async {
      final h = AuthHarness(signedInAs: admin);
      await tester.pump();
      h.users.watchError = firestoreError();
      await pumpApp(tester, h, const AdminUsersScreen());

      expect(find.textContaining('Không tải được danh sách'), findsOneWidget);
    });
  });
}
