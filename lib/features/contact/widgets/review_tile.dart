// lib/features/contact/widgets/review_tile.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import 'interaction_ui.dart';
import 'rating_stars.dart';
import 'report_form.dart';

/// Một đánh giá, kèm nút thao tác tùy vai trò:
/// - người thuê (tác giả): sửa / xóa
/// - chủ trọ của phòng: phản hồi
/// - admin: xóa đánh giá vi phạm
/// - người khác: báo cáo
class ReviewTile extends StatelessWidget {
  final Review review;

  /// Hiện tên phòng (dùng ở danh sách nhiều phòng).
  final bool showRoom;

  const ReviewTile({super.key, required this.review, this.showRoom = false});

  Future<void> _delete(
    BuildContext context,
    String title,
    String message,
  ) async {
    final ok = await confirmDialog(
      context,
      title: title,
      message: message,
      confirmText: 'Xóa',
      danger: true,
    );
    if (ok && context.mounted) {
      runAction(
        context,
        () => InteractionService.instance.deleteReview(review.id),
        success: 'Đã xóa đánh giá',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    final user = s.userById(review.userId);
    final room = s.rooms[review.roomId];
    final role = s.role;
    final isAuthor = review.userId == s.currentUser.id;
    final isRoomOwner =
        role == UserRole.owner &&
        s.roomOwner[review.roomId] == s.currentUser.id;
    final reply = review.ownerReply;

    final actions = <Widget>[];
    if (isAuthor && role == UserRole.tenant) {
      actions.add(
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => _EditReviewDialog(review: review),
          ),
          child: const Text('Sửa'),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () => _delete(
            context,
            'Xóa đánh giá?',
            'Đánh giá của bạn sẽ bị xóa vĩnh viễn.',
          ),
          style: TextButton.styleFrom(foregroundColor: IStyle.danger),
          child: const Text('Xóa'),
        ),
      );
    }
    if (isRoomOwner) {
      actions.add(
        TextButton(
          onPressed: () async {
            final text = await promptDialog(
              context,
              title: 'Phản hồi đánh giá',
              hint: 'Cảm ơn bạn đã đánh giá...',
              initial: reply ?? '',
            );
            if (text != null && context.mounted) {
              runAction(
                context,
                () => s.replyReview(review.id, text),
                success: 'Đã gửi phản hồi',
              );
            }
          },
          child: Text(reply == null ? 'Phản hồi' : 'Sửa phản hồi'),
        ),
      );
    }
    if (role == UserRole.admin) {
      actions.add(
        TextButton(
          onPressed: () => _delete(
            context,
            'Xóa đánh giá vi phạm?',
            'Đánh giá sẽ bị xóa khỏi phòng này.',
          ),
          style: TextButton.styleFrom(foregroundColor: IStyle.danger),
          child: const Text('Xóa vi phạm'),
        ),
      );
    }
    if (!isAuthor && role != UserRole.admin) {
      actions.add(
        TextButton.icon(
          onPressed: () => showReportSheet(
            context,
            type: ReportTarget.review,
            targetId: review.id,
            title: 'Báo cáo đánh giá',
          ),
          icon: const Icon(Icons.flag_outlined, size: 16),
          label: const Text('Báo cáo'),
          style: TextButton.styleFrom(foregroundColor: IStyle.muted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: user?.name ?? '?', radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Người dùng ẩn danh',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      fmtDateShort(review.createdAt ?? s.now()),
                      style: const TextStyle(fontSize: 12, color: IStyle.muted),
                    ),
                  ],
                ),
              ),
              RatingStars(rating: review.rating.toDouble()),
            ],
          ),
          if (showRoom && room != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                room.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: IStyle.primary),
              ),
            ),
          if (review.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(review.comment, style: const TextStyle(height: 1.4)),
            ),
          if (reply != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IStyle.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phản hồi từ chủ trọ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IStyle.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(reply, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(alignment: WrapAlignment.end, children: actions),
            ),
        ],
      ),
    );
  }
}

class _EditReviewDialog extends StatefulWidget {
  final Review review;

  const _EditReviewDialog({required this.review});

  @override
  State<_EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends State<_EditReviewDialog> {
  late int _rating = widget.review.rating;
  late final TextEditingController _comment = TextEditingController(
    text: widget.review.comment,
  );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa đánh giá'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingInput(
              value: _rating,
              size: 28,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () {
            final ok = runAction(
              context,
              () => InteractionService.instance.editReview(
                widget.review.id,
                rating: _rating,
                comment: _comment.text,
              ),
              success: 'Đã cập nhật đánh giá',
            );
            if (ok) Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
