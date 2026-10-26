// lib/features/auth/screens/register_screen.dart
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../utils/validators.dart';
import '../widgets/auth_input_decoration.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  // Người dùng chỉ được chọn Chủ trọ hoặc Khách thuê, admin do hệ thống cấp
  UserRole _role = UserRole.tenant;
  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        fullName: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công!')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Đăng ký bằng Google: vai trò đang chọn ở trên được dùng luôn, không hỏi lại
  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await AuthService.instance.signInWithGoogle(chooseRole: () async => _role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập bằng Google thành công!')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tạo tài khoản',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text('Bạn là', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.tenant,
                      label: Text('Khách thuê'),
                      icon: Icon(Icons.person_search),
                    ),
                    ButtonSegment(
                      value: UserRole.landlord,
                      label: Text('Chủ trọ'),
                      icon: Icon(Icons.house),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (selection) => setState(() => _role = selection.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: authInputDecoration(label: 'Họ và tên', icon: Icons.badge_outlined),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: authInputDecoration(label: 'Email', icon: Icons.email_outlined),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: authInputDecoration(
                    label: 'Số điện thoại (không bắt buộc)',
                    icon: Icons.phone_outlined,
                  ),
                  validator: Validators.optionalPhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: authInputDecoration(
                    label: 'Mật khẩu',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: authInputDecoration(label: 'Nhập lại mật khẩu', icon: Icons.lock_outline),
                  validator: (value) =>
                      value != _passwordController.text ? 'Mật khẩu nhập lại không khớp' : null,
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(label: 'Đăng ký', loading: _loading, onPressed: _submit),
                const SizedBox(height: 20),
                const OrDivider(),
                const SizedBox(height: 20),
                GoogleSignInButton(loading: _googleLoading, onPressed: _signInWithGoogle),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản?'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
