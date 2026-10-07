// lib/features/auth/utils/validators.dart

class Validators {
  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  // Số điện thoại Việt Nam: 10 số, bắt đầu bằng 0
  static final _phoneRegex = RegExp(r'^0\d{9}$');

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập họ tên';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
    if (!_emailRegex.hasMatch(value.trim())) return 'Email không hợp lệ';
    return null;
  }

  // Số điện thoại không bắt buộc, chỉ kiểm tra khi có nhập
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_phoneRegex.hasMatch(value.trim())) {
      return 'Số điện thoại phải gồm 10 số, bắt đầu bằng 0';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }
}
