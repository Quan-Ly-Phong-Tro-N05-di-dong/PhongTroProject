import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'post_service.dart';
import 'posts_page.dart';

/// Màn hình đầu vào của module. Firebase được khởi tạo bởi ứng dụng chung
/// hoặc bởi dev_main.dart khi chạy thử độc lập.
class ManagePostsPage extends StatefulWidget {
  // Khi đặt trong MainScreen, dùng thanh chọn mục phía trên nội dung.
  final bool embedded;
  const ManagePostsPage({super.key, this.embedded = false});

  @override
  State<ManagePostsPage> createState() => _ManagePostsPageState();
}

class _ManagePostsPageState extends State<ManagePostsPage> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StatusPage(message: PostService.errorText(snapshot.error!));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StatusPage(loading: true);
        }
        final user = snapshot.data;
        if (user == null) {
          return _StatusPage(
            message: widget.embedded
                ? 'Bạn chưa đăng nhập.\n\nHãy đăng nhập ở mục Tài khoản '
                    'rồi quay lại Bài đăng.'
                : 'Bạn chưa đăng nhập.\n\n'
                    'Hãy đăng nhập trong ứng dụng chung của nhóm, '
                    'sau đó chạy lại module quản lý bài đăng.',
          );
        }
        return _ProfileGate(
          key: ValueKey(user.uid),
          uid: user.uid,
          embedded: widget.embedded,
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  final String uid;
  final bool embedded;
  const _ProfileGate({super.key, required this.uid, required this.embedded});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StatusPage(message: PostService.errorText(snapshot.error!));
        }
        if (!snapshot.hasData) {
          return const _StatusPage(loading: true);
        }
        final profile = snapshot.data!.data();
        if (profile == null) {
          return _StatusPage(
            message: 'Không tìm thấy hồ sơ users/${widget.uid}.\n\n'
                'Hãy kiểm tra tài khoản với người phụ trách Auth.',
          );
        }
        if (profile['disabled'] != false) {
          return const _StatusPage(
            message: 'Tài khoản bị khóa hoặc hồ sơ chưa có disabled bằng false.',
          );
        }
        final role = profile['role'];
        if (role is! String ||
            !['landlord', 'admin', 'tenant'].contains(role)) {
          return const _StatusPage(
            message: 'Quyền tài khoản không hợp lệ.\n'
                'Các quyền hợp lệ: landlord, admin, tenant.',
          );
        }
        return PostsPage(
          key: ValueKey('${widget.uid}/$role'),
          role: role,
          embedded: widget.embedded,
        );
      },
    );
  }
}

class _StatusPage extends StatelessWidget {
  final String? message;
  final bool loading;
  const _StatusPage({this.message, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý bài đăng')),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  message ?? '',
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
