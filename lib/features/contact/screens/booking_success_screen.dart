// lib/features/contact/screens/booking_success_screen.dart
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/room_summary_card.dart';
import 'appointments_tab.dart';

/// Màn "Đặt lịch thành công!".
class BookingSuccessScreen extends StatelessWidget {
  final String appointmentId;

  const BookingSuccessScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    final appointment = s.appointments.findById(appointmentId);
    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.event_busy,
          message: 'Không tìm thấy lịch hẹn.',
        ),
      );
    }
    final room = s.rooms[appointment.roomId];
    final owner = s.userById(appointment.ownerId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F8EE),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: IStyle.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Đặt lịch thành công!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Chủ trọ sẽ xác nhận lịch hẹn của bạn.',
                        style: TextStyle(color: IStyle.muted),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardDecoration(),
                        child: Column(
                          children: [
                            if (room != null) RoomSummaryCard(room: room),
                            const SizedBox(height: 8),
                            _Line(
                              icon: Icons.calendar_today_outlined,
                              label: 'Ngày xem phòng',
                              value: fmtDate(appointment.appointmentTime),
                            ),
                            _Line(
                              icon: Icons.access_time,
                              label: 'Thời gian',
                              value: fmtTime(appointment.appointmentTime),
                            ),
                            _Line(
                              icon: Icons.person_outline,
                              label: 'Chủ trọ',
                              value: owner?.name ?? '-',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: IStyle.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: IStyle.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bạn có thể theo dõi trạng thái lịch hẹn ở mục Lịch hẹn.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: IStyle.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (ctx) => const AppointmentsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.event_note),
                  label: const Text('Xem lịch hẹn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: IStyle.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IStyle.muted,
                    side: const BorderSide(color: IStyle.border),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Line({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IStyle.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: IStyle.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: IStyle.muted),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
