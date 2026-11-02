// test/auth/auth_models_test.dart
// Chạy: flutter test test/auth/auth_models_test.dart
import 'package:flutter_application_test/features/auth/models/app_user.dart';
import 'package:flutter_application_test/features/auth/models/avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole', () {
    test('có đúng 3 vai trò với nhãn tiếng Việt', () {
      expect(UserRole.values.map((r) => r.label), ['Quản trị viên', 'Chủ trọ', 'Khách thuê']);
    });

    test('fromName đọc đúng tên đã lưu', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromName(role.name), role);
      }
    });

    test('tên lạ hoặc null thì mặc định là khách thuê', () {
      expect(UserRole.fromName(null), UserRole.tenant);
      expect(UserRole.fromName('superadmin'), UserRole.tenant);
      expect(UserRole.fromName('ADMIN'), UserRole.tenant);
    });
  });

  group('AppUser', () {
    AppUser withRole(UserRole role) =>
        AppUser(id: 'u1', fullName: 'An', email: 'a@b.com', role: role);

    test('mặc định không bị khóa và không có số điện thoại', () {
      final user = withRole(UserRole.tenant);
      expect(user.disabled, isFalse);
      expect(user.phone, isNull);
    });

    test('isAdmin, isLandlord, isTenant chỉ đúng với vai trò tương ứng', () {
      final admin = withRole(UserRole.admin);
      expect([admin.isAdmin, admin.isLandlord, admin.isTenant], [true, false, false]);
      final landlord = withRole(UserRole.landlord);
      expect([landlord.isAdmin, landlord.isLandlord, landlord.isTenant], [false, true, false]);
      final tenant = withRole(UserRole.tenant);
      expect([tenant.isAdmin, tenant.isLandlord, tenant.isTenant], [false, false, true]);
    });

    test('hasAnyRole kiểm tra theo danh sách cho phép', () {
      final landlord = withRole(UserRole.landlord);
      expect(landlord.hasAnyRole([UserRole.landlord, UserRole.admin]), isTrue);
      expect(landlord.hasAnyRole([UserRole.tenant]), isFalse);
      expect(landlord.hasAnyRole([]), isFalse);
    });

    test('fromMap đọc đủ các trường', () {
      final user = AppUser.fromMap('u1', {
        'fullName': 'An',
        'email': 'a@b.com',
        'phone': '0912345678',
        'role': 'landlord',
        'disabled': true,
      });
      expect(user.id, 'u1');
      expect(user.fullName, 'An');
      expect(user.email, 'a@b.com');
      expect(user.phone, '0912345678');
      expect(user.role, UserRole.landlord);
      expect(user.disabled, isTrue);
    });

    test('fromMap dùng giá trị mặc định khi thiếu trường', () {
      final user = AppUser.fromMap('u1', {});
      expect(user.fullName, '');
      expect(user.email, '');
      expect(user.phone, isNull);
      expect(user.role, UserRole.tenant);
      expect(user.disabled, isFalse);
    });

    test('toMap không chứa id và lưu vai trò theo tên', () {
      final map = const AppUser(
        id: 'u1',
        fullName: 'An',
        email: 'a@b.com',
        phone: '0912345678',
        role: UserRole.admin,
        disabled: true,
      ).toMap();
      expect(map, {
        'fullName': 'An',
        'email': 'a@b.com',
        'phone': '0912345678',
        'role': 'admin',
        'disabled': true,
      });
    });

    test('toMap rồi fromMap giữ nguyên dữ liệu', () {
      const original = AppUser(
        id: 'u1',
        fullName: 'An',
        email: 'a@b.com',
        role: UserRole.landlord,
      );
      expect(AppUser.fromMap('u1', original.toMap()).toMap(), original.toMap());
    });
  });

  group('Avatar', () {
    test('fromMap lấy userId từ id của document', () {
      final avatar = Avatar.fromMap('u1', {'data': 'abc'});
      expect(avatar.userId, 'u1');
      expect(avatar.data, 'abc');
    });

    test('fromMap trả về chuỗi rỗng khi thiếu dữ liệu', () {
      expect(Avatar.fromMap('u1', {}).data, '');
    });

    test('toMap chỉ lưu dữ liệu ảnh', () {
      expect(const Avatar(userId: 'u1', data: 'abc').toMap(), {'data': 'abc'});
    });
  });
}
