// test/auth/validators_test.dart
// Chạy: flutter test test/auth/validators_test.dart
import 'package:flutter_application_test/features/auth/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fullName', () {
    test('bắt buộc nhập', () {
      for (final value in [null, '', '   ']) {
        expect(Validators.fullName(value), 'Vui lòng nhập họ tên');
      }
    });

    test('chấp nhận tên có dấu', () {
      expect(Validators.fullName('Nguyễn Văn An'), isNull);
    });
  });

  group('email', () {
    test('bắt buộc nhập', () {
      for (final value in [null, '', '   ']) {
        expect(Validators.email(value), 'Vui lòng nhập email');
      }
    });

    test('chấp nhận email hợp lệ', () {
      for (final value in ['a@b.com', 'a.b+c-d@sub.domain.vn', '  a@b.com  ']) {
        expect(Validators.email(value), isNull, reason: value);
      }
    });

    test('từ chối email sai định dạng', () {
      for (final value in ['abc', 'a@b', '@b.com', 'a@.com', 'a b@c.com', 'a@b..com']) {
        expect(Validators.email(value), 'Email không hợp lệ', reason: value);
      }
    });
  });

  group('optionalPhone', () {
    test('được bỏ trống', () {
      for (final value in [null, '', '   ']) {
        expect(Validators.optionalPhone(value), isNull);
      }
    });

    test('chấp nhận 10 số bắt đầu bằng 0', () {
      for (final value in ['0912345678', ' 0912345678 ']) {
        expect(Validators.optionalPhone(value), isNull, reason: value);
      }
    });

    test('từ chối số sai định dạng', () {
      for (final value in ['091234567', '09123456789', '1912345678', '09123abc78', '+84912345678']) {
        expect(
          Validators.optionalPhone(value),
          'Số điện thoại phải gồm 10 số, bắt đầu bằng 0',
          reason: value,
        );
      }
    });
  });

  group('password', () {
    test('bắt buộc nhập', () {
      for (final value in [null, '']) {
        expect(Validators.password(value), 'Vui lòng nhập mật khẩu');
      }
    });

    test('tối thiểu 6 ký tự', () {
      expect(Validators.password('12345'), 'Mật khẩu phải có ít nhất 6 ký tự');
      expect(Validators.password('123456'), isNull);
    });
  });
}
