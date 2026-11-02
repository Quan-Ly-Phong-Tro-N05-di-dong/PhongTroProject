import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/app_user.dart';

class UserAvatar extends StatefulWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  late Stream<String?> _stream = AuthService.instance.watchAvatar(widget.user.id);
  String? _lastBase64;
  Uint8List? _bytes; // Giữ ảnh đã giải mã, tránh giải mã lại mỗi lần vẽ

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _stream = AuthService.instance.watchAvatar(widget.user.id);
    }
  }

  // Ảnh rỗng hoặc hỏng thì trả về null để hiện chữ cái đầu
  Uint8List? _decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _stream,
      builder: (context, snapshot) {
        final base64 = snapshot.data;
        if (base64 != _lastBase64) {
          _lastBase64 = base64;
          _bytes = _decode(base64);
        }
        final name = widget.user.fullName;
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.user.disabled ? Colors.grey : Colors.blueAccent,
          backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
          // Dữ liệu đúng Base64 nhưng không phải ảnh
          onBackgroundImageError: _bytes != null
              ? (_, _) {
                  if (mounted) setState(() => _bytes = null);
                }
              : null,
          child: _bytes != null
              ? null
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: widget.radius * 0.8, color: Colors.white),
                ),
        );
      },
    );
  }
}
