// lib/features/contact/widgets/pill_action_button.dart
import 'package:flutter/material.dart';

/// Nút hành động chính, bo tròn hai đầu, màu đỏ cam, có đổ bóng.
class PillActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PillActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF65A4F),
          foregroundColor: Colors.white,
          minimumSize: const Size(260, 52),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: Colors.black54,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
