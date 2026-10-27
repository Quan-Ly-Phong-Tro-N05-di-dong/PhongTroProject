// lib/features/contact/widgets/room_summary_card.dart
import 'package:flutter/material.dart';

import '../../home_catalog/models/room_item.dart';
import 'interaction_ui.dart';

/// Ảnh nhỏ của phòng, có ô thay thế khi chưa tải được ảnh.
class RoomThumb extends StatelessWidget {
  final RoomItem? room;
  final double size;

  const RoomThumb({super.key, required this.room, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final current = room;
    final placeholder = Container(
      width: size,
      height: size,
      color: Colors.grey.shade300,
      child: const Icon(Icons.home_work_outlined, color: Colors.grey),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: current == null
          ? placeholder
          : Image.network(
              current.imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}

/// Thẻ tóm tắt phòng (ảnh, tên, địa chỉ, giá) dùng ở màn đặt lịch, đánh giá...
class RoomSummaryCard extends StatelessWidget {
  final RoomItem room;

  const RoomSummaryCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          RoomThumb(room: room, size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: IStyle.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  fmtVnd(room.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: IStyle.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
