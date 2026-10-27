// lib/features/contact/widgets/room_image_box.dart
import 'package:flutter/material.dart';

import '../../home_catalog/models/room_item.dart';

/// Ảnh lớn của phòng (tỉ lệ 2:1).
/// Chưa có ảnh hoặc tải ảnh lỗi thì hiện khung xám có hai đường chéo.
class RoomImageBox extends StatelessWidget {
  final RoomItem? room;

  const RoomImageBox({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final current = room;
    return AspectRatio(
      aspectRatio: 2,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: current == null
            ? const _CrossBox(label: 'Ảnh phòng')
            : Image.network(
                current.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _CrossBox(label: 'Ảnh phòng'),
              ),
      ),
    );
  }
}

/// Khung xám có hai đường chéo và chữ ở giữa.
class _CrossBox extends StatelessWidget {
  final String label;

  const _CrossBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CrossPainter(),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 18))),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
