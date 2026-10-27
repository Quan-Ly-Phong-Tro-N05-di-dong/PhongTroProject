// lib/features/auth/widgets/auth_input_decoration.dart
import 'package:flutter/material.dart';

import '../models/app_user.dart';

// Style chung cho các ô nhập trong module Auth
InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
    ),
  );
}

// Nút "Tiếp tục với Google"
class GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const GoogleSignInButton({super.key, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'G',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Tiếp tục với Google', style: TextStyle(fontSize: 15)),
                ],
              ),
      ),
    );
  }
}

// Hộp thoại chọn vai trò khi đăng nhập Google lần đầu. Trả về null nếu người dùng hủy.
Future<UserRole?> showRolePickerDialog(BuildContext context) {
  return showDialog<UserRole>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Bạn là'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(dialogContext).pop(UserRole.tenant),
          child: const ListTile(
            leading: Icon(Icons.person_search),
            title: Text('Khách thuê'),
            subtitle: Text('Tìm và liên hệ thuê phòng'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(dialogContext).pop(UserRole.landlord),
          child: const ListTile(
            leading: Icon(Icons.house),
            title: Text('Chủ trọ'),
            subtitle: Text('Đăng tin và quản lý phòng cho thuê'),
          ),
        ),
      ],
    ),
  );
}

// Dòng phân cách "hoặc"
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('hoặc', style: TextStyle(color: Colors.grey.shade600)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// Nút chính có trạng thái loading
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
