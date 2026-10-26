// lib/features/auth/widgets/role_guard.dart
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../screens/login_screen.dart';

// Bọc một màn hình để chỉ những vai trò được phép mới xem được.
//
// Ví dụ, chỉ chủ trọ và admin vào được màn hình quản lý bài đăng:
//   RoleGuard(
//     allowed: [UserRole.landlord, UserRole.admin],
//     child: ManagePostsScreen(),
//   )
//
// Bỏ trống `allowed` nghĩa là chỉ cần đăng nhập, vai trò nào cũng được.
class RoleGuard extends StatelessWidget {
  final List<UserRole> allowed;
  final Widget child;

  const RoleGuard({super.key, this.allowed = UserRole.values, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: AuthService.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) return const _LoginRequired();
        if (!user.hasAnyRole(allowed)) return _Forbidden(allowed: allowed);
        return child;
      },
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) {
    return _GuardMessage(
      icon: Icons.lock_outline,
      title: 'Bạn cần đăng nhập',
      message: 'Vui lòng đăng nhập để sử dụng chức năng này',
      action: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        child: const Text('Đăng nhập'),
      ),
    );
  }
}

class _Forbidden extends StatelessWidget {
  final List<UserRole> allowed;
  const _Forbidden({required this.allowed});

  @override
  Widget build(BuildContext context) {
    final roles = allowed.map((r) => r.label).join(', ');
    return _GuardMessage(
      icon: Icons.block,
      title: 'Bạn không có quyền truy cập',
      message: 'Chức năng này chỉ dành cho: $roles',
    );
  }
}

class _GuardMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _GuardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
