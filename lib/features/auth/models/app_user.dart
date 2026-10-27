// lib/features/auth/models/app_user.dart

// 3 vai trò trong hệ thống. Tên enum (admin/landlord/tenant) được lưu vào Firestore.
enum UserRole {
  admin('Quản trị viên'),
  landlord('Chủ trọ'),
  tenant('Khách thuê');

  final String label;
  const UserRole(this.label);

  static UserRole fromName(String? name) =>
      UserRole.values.firstWhere((r) => r.name == name, orElse: () => UserRole.tenant);
}

// Tương ứng với document users/{id} trên Firestore
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String? phone; // Thông tin liên hệ, không bắt buộc
  final UserRole role;
  final bool disabled; // true = bị admin khóa, không đăng nhập được

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.disabled = false,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isLandlord => role == UserRole.landlord;
  bool get isTenant => role == UserRole.tenant;

  // Kiểm tra người dùng có thuộc một trong các vai trò cho phép không
  bool hasAnyRole(List<UserRole> roles) => roles.contains(role);

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      role: UserRole.fromName(data['role'] as String?),
      disabled: data['disabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role.name,
      'disabled': disabled,
    };
  }
}
