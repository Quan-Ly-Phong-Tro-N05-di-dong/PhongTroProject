// lib/features/contact/widgets/review_list.dart
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import 'interaction_ui.dart';
import 'rating_stars.dart';
import 'review_tile.dart';

/// Khối đánh giá của một phòng (điểm trung bình + danh sách), nhúng vào trang chi tiết phòng:
/// `ReviewList(roomId: room.id)`.
class ReviewList extends StatelessWidget {
  final String roomId;

  const ReviewList({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final summary = s.ratingSummary(roomId);
        final items = s.reviewsOfRoom(roomId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đánh giá',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  summary.count == 0
                      ? '--'
                      : summary.average.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingStars(rating: summary.average, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.count} đánh giá',
                      style: const TextStyle(fontSize: 12, color: IStyle.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có đánh giá nào cho phòng này.',
                  style: TextStyle(color: IStyle.muted),
                ),
              )
            else
              for (final review in items) ReviewTile(review: review),
          ],
        );
      },
    );
  }
}
