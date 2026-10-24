// lib/features/contact/widgets/rating_stars.dart
import 'package:flutter/material.dart';

import 'interaction_ui.dart';

/// Hiển thị điểm sao (chỉ xem), hỗ trợ nửa sao.
class RatingStars extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStars({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : (rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_border_rounded),
            color: IStyle.star,
            size: size,
          ),
      ],
    );
  }
}

/// Chọn số sao từ 1 đến 5.
class RatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const RatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_border_rounded,
              color: IStyle.star,
              size: size,
            ),
          ),
        if (value > 0) ...[
          const SizedBox(width: 8),
          Text(
            '$value.0',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ],
    );
  }
}
