// lib/features/contact/screens/appointments_tab.dart
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import '../widgets/appointment_card.dart';
import '../widgets/interaction_ui.dart';

/// Danh sách lịch hẹn của người dùng hiện tại, chia "Sắp tới" / "Đã qua".
/// - người thuê: lịch mình đã đặt (hủy lịch, đánh giá sau khi hoàn thành)
/// - chủ trọ: lịch hẹn của các phòng mình (xác nhận / từ chối / hoàn thành)
/// - admin: tất cả lịch hẹn
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  bool _showUpcoming = true;

  String _emptyMessage(UserRole role) {
    if (!_showUpcoming) return 'Chưa có lịch hẹn nào đã qua.';
    return switch (role) {
      UserRole.tenant => 'Bạn chưa có lịch hẹn sắp tới.\nVào chi tiết phòng và bấm "Đặt lịch" nhé.',
      UserRole.owner => 'Chưa có lịch hẹn nào cho phòng của bạn.',
      UserRole.admin => 'Chưa có lịch hẹn nào.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final all = s.appointmentsForCurrentUser();
        final upcoming = all.where(InteractionService.isUpcoming).toList();
        final past = all
            .where((a) => !InteractionService.isUpcoming(a))
            .toList()
            .reversed
            .toList();
        final shown = _showUpcoming ? upcoming : past;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: IStyle.primarySoft,
                    selectedForegroundColor: IStyle.primary,
                  ),
                  segments: [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Sắp tới · ${upcoming.length}'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Đã qua · ${past.length}'),
                    ),
                  ],
                  selected: {_showUpcoming},
                  onSelectionChanged: (value) =>
                      setState(() => _showUpcoming = value.first),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(
                      icon: Icons.event_busy_outlined,
                      message: _emptyMessage(s.role),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: shown.length,
                      itemBuilder: (context, index) =>
                          AppointmentCard(appointment: shown[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Trang riêng hiển thị danh sách lịch hẹn (mở từ màn "Đặt lịch thành công").
class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IStyle.background,
      appBar: AppBar(
        title: const Text('Lịch hẹn'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: const AppointmentsTab(),
    );
  }
}
