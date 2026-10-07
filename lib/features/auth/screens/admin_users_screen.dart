// lib/features/auth/screens/admin_users_screen.dart
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/app_user.dart';

// Màn hình admin: xem danh sách người dùng, đổi vai trò, khóa / mở khóa tài khoản.
// Luôn mở màn hình này qua RoleGuard(allowed: [UserRole.admin]).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  late final Stream<List<AppUser>> _usersStream = AuthService.instance.watchAllUsers();
  UserRole? _roleFilter; // null = tất cả
  bool _showLocked = false; // true = đang xem mục "Tài khoản đã khóa"

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _applyFilters(List<AppUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((u) {
      // Tài khoản đã khóa chỉ nằm trong mục "Tài khoản đã khóa"
      if (u.disabled != _showLocked) return false;
      if (!_showLocked && _roleFilter != null && u.role != _roleFilter) return false;
      if (query.isEmpty) return true;
      return u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          (u.phone?.contains(query) ?? false);
    }).toList();
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeRole(AppUser user) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Vai trò của ${user.fullName}'),
        children: UserRole.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(r),
                  child: Row(
                    children: [
                      Icon(
                        r == user.role ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(r.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (role == null || role == user.role) return;
    await _run(
      () => AuthService.instance.updateRole(user.id, role),
      'Đã đổi ${user.fullName} thành ${role.label}',
    );
  }

  Future<void> _toggleDisabled(AppUser user) async {
    final lock = !user.disabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(lock ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?'),
        content: Text(
          lock
              ? '${user.fullName} sẽ bị đăng xuất và không thể đăng nhập lại.'
              : '${user.fullName} sẽ đăng nhập lại được bình thường.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: lock ? Colors.redAccent : null),
            child: Text(lock ? 'Khóa' : 'Mở khóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => AuthService.instance.setDisabled(user.id, lock),
      lock ? 'Đã khóa ${user.fullName}' : 'Đã mở khóa ${user.fullName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService.instance.currentUser.value?.id;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quản lý người dùng',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, số điện thoại',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  selected: !_showLocked && _roleFilter == null,
                  onSelected: () => setState(() {
                    _showLocked = false;
                    _roleFilter = null;
                  }),
                ),
                for (final role in UserRole.values)
                  _buildFilterChip(
                    label: role.label,
                    selected: !_showLocked && _roleFilter == role,
                    onSelected: () => setState(() {
                      _showLocked = false;
                      _roleFilter = role;
                    }),
                  ),
                _buildFilterChip(
                  label: 'Tài khoản đã khóa',
                  selected: _showLocked,
                  selectedColor: Colors.redAccent,
                  onSelected: () => setState(() {
                    _showLocked = true;
                    _roleFilter = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Không tải được danh sách: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = _applyFilters(snapshot.data!);
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _showLocked ? 'Không có tài khoản nào bị khóa' : 'Không có người dùng nào',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (context, index) =>
                      _buildUserCard(users[index], isMe: users[index].id == currentUserId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color selectedColor = Colors.blueAccent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 13),
        ),
        selected: selected,
        selectedColor: selectedColor,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? selectedColor : Colors.grey.shade300),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _buildUserCard(AppUser user, {required bool isMe}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: user.disabled ? Colors.grey : Colors.blueAccent,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          isMe ? '${user.fullName} (bạn)' : user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                _tag(user.role.label, Colors.blue.shade50, Colors.blue.shade800),
                if (user.disabled) ...[
                  const SizedBox(width: 6),
                  _tag('Đã khóa', Colors.red.shade50, Colors.red.shade700),
                ],
              ],
            ),
          ],
        ),
        // Admin không tự đổi vai trò / tự khóa chính mình
        trailing: isMe
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'role') _changeRole(user);
                  if (value == 'lock') _toggleDisabled(user);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'role', child: Text('Đổi vai trò')),
                  PopupMenuItem(
                    value: 'lock',
                    child: Text(user.disabled ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tag(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12, color: foreground)),
    );
  }
}
