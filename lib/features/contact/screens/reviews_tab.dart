// lib/features/contact/screens/reviews_tab.dart
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/review_tile.dart';

/// Danh sách đánh giá theo vai trò:
/// - người thuê: đánh giá của mình (sửa / xóa)
/// - chủ trọ: đánh giá về phòng của mình (phản hồi)
/// - admin: tất cả đánh giá (xóa đánh giá vi phạm)
class ReviewsTab extends StatelessWidget {
  const ReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final list = s.reviewsForCurrentUser();
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.star_border_rounded,
            message: switch (s.role) {
              UserRole.tenant => 'Bạn chưa đánh giá phòng nào.\nSau khi lịch hẹn hoàn thành, vào mục Lịch hẹn > Đã qua để đánh giá.',
              UserRole.owner => 'Phòng của bạn chưa có đánh giá nào.',
              UserRole.admin => 'Chưa có đánh giá nào.',
            },
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) =>
              ReviewTile(review: list[index], showRoom: true),
        );
      },
    );
  }
}
