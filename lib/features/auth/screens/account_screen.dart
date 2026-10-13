// lib/features/auth/screens/account_screen.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../widgets/role_guard.dart';
import '../widgets/user_avt.dart';
import 'admin_users_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

// Tab "Tài khoản": chưa đăng nhập thì mời đăng nhập, đã đăng nhập thì hiện thông tin
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tài khoản',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: ValueListenableBuilder<AppUser?>(
        valueListenable: AuthService.instance.currentUser,
        builder: (context, user, _) =>
            user == null ? const _GuestView() : _ProfileView(user: user),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined, size: 96, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Bạn chưa đăng nhập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Đăng nhập để đăng tin, liên hệ chủ trọ và quản lý tài khoản',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Đăng ký'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final AppUser user;
  const _ProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Bấm vào ảnh đại diện để đổi ảnh
                GestureDetector(
                  onTap: () => _showAvatarOptions(context),
                  child: Stack(
                    children: [
                      UserAvatar(user: user, radius: 40),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(user.role.label),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Số điện thoại'),
                subtitle: Text(user.phone ?? 'Chưa cập nhật'),
              ),
            ],
          ),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.blueAccent),
              title: const Text('Quản lý người dùng'),
              subtitle: const Text('Đổi vai trò, khóa tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RoleGuard(
                    allowed: [UserRole.admin],
                    child: AdminUsersScreen(),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
          onPressed: () => AuthService.instance.logout(),
        ),
      ],
    );
  }

  // Menu đổi ảnh đại diện
  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(context, ImageSource.gallery);
              },
            ),
            if (!kIsWeb) // Trình duyệt không mở camera theo cách này
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAvatar(context, ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Xóa ảnh đại diện'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _removeAvatar(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, ImageSource source) async {
    // Lấy messenger trước khi chờ, tránh dùng context sau await
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 256, // Ảnh đại diện nhỏ, 256px là đủ
      maxHeight: 256,
      imageQuality: 70, // Nén JPEG
    );
    if (picked == null) return; // Người dùng hủy
    final bytes = await picked.readAsBytes();
    if (bytes.length > 500 * 1024) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ảnh quá lớn, vui lòng chọn ảnh khác')),
      );
      return;
    }
    try {
      await AuthService.instance.updateAvatar(base64Encode(bytes));
      messenger.showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeAvatar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.removeAvatar();
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa ảnh đại diện')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
