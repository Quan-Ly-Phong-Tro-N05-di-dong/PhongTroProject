// lib/features/contact/widgets/review_form.dart
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import 'interaction_ui.dart';
import 'rating_stars.dart';

/// Form gửi đánh giá cho một lịch hẹn đã hoàn thành.
class ReviewForm extends StatefulWidget {
  final String appointmentId;
  final VoidCallback? onSubmitted;

  const ReviewForm({super.key, required this.appointmentId, this.onSubmitted});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final TextEditingController _comment = TextEditingController();
  int _rating = 0; // chưa chọn sao thì chưa gửi được

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = runAction(
      context,
      () => InteractionService.instance.addReview(
        appointmentId: widget.appointmentId,
        rating: _rating,
        comment: _comment.text,
      ),
      success: 'Cảm ơn bạn đã đánh giá!',
    );
    if (ok) widget.onSubmitted?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trải nghiệm của bạn tại phòng trọ này thế nào?',
          style: TextStyle(color: IStyle.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        RatingInput(
          value: _rating,
          onChanged: (value) => setState(() => _rating = value),
        ),
        const SizedBox(height: 12),
        const Text('Nhận xét', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _comment,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Chia sẻ cảm nhận của bạn...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _rating == 0 ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Gửi đánh giá'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IStyle.primary,
              side: const BorderSide(color: IStyle.primary),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
