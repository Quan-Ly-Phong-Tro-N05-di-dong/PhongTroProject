// lib/features/contact/screens/review_report_screen.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/report_form.dart';
import '../widgets/review_form.dart';
import '../widgets/review_tile.dart';
import '../widgets/room_summary_card.dart';

const TextStyle _titleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.bold,
);

/// Màn "Đánh giá / Báo cáo" cho một lịch hẹn: đánh giá phòng (khi đã hoàn thành)
/// và báo cáo tin đăng.
class ReviewReportScreen extends StatelessWidget {
  final String appointmentId;

  const ReviewReportScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return Scaffold(
      backgroundColor: IStyle.background,
      appBar: AppBar(
        title: const Text('Đánh giá / Báo cáo'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, child) {
          final appointment = s.appointments.findById(appointmentId);
          if (appointment == null) {
            return const EmptyState(
              icon: Icons.event_busy,
              message: 'Không tìm thấy lịch hẹn.',
            );
          }
          final room = s.rooms[appointment.roomId];
          final existing = s.reviewForAppointment(appointmentId);

          final Widget reviewSection;
          if (appointment.status != AppointmentStatus.completed) {
            reviewSection = const _Notice(
              'Bạn chỉ đánh giá được sau khi lịch hẹn đã hoàn thành.',
            );
          } else if (existing != null) {
            reviewSection = ReviewTile(review: existing);
          } else {
            reviewSection = ReviewForm(appointmentId: appointmentId);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (room != null) RoomSummaryCard(room: room),
              const SizedBox(height: 20),
              const Text('Đánh giá phòng', style: _titleStyle),
              const SizedBox(height: 8),
              reviewSection,
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: IStyle.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Báo cáo tin đăng', style: _titleStyle),
                        Text(
                          'Giúp chúng tôi giữ cộng đồng an toàn.',
                          style: TextStyle(fontSize: 12, color: IStyle.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ReportForm(type: ReportTarget.room, targetId: appointment.roomId),
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IStyle.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: IStyle.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: IStyle.muted),
            ),
          ),
        ],
      ),
    );
  }
}
