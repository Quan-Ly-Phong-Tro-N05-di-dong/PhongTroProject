// lib/features/contact/widgets/appointment_info_card.dart
import 'package:flutter/material.dart';

/// Thẻ thông tin lịch hẹn: mã, giờ hẹn, trạng thái.
class AppointmentInfoCard extends StatelessWidget {
  final String code;
  final String timeText;
  final String statusText;

  const AppointmentInfoCard({
    super.key,
    required this.code,
    required this.timeText,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D7DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mã lịch hẹn: $code',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('Giờ hẹn: $timeText', style: const TextStyle(fontSize: 16)),
          Text('Trạng thái: $statusText', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
