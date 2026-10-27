// lib/features/contact/widgets/appointment_card.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../screens/appointment_detail_screen.dart';
import '../screens/review_report_screen.dart';
import '../services/interaction_service.dart';
import 'interaction_ui.dart';
import 'room_summary_card.dart';

/// Thẻ lịch hẹn. Nút bên dưới thay đổi theo vai trò và trạng thái:
/// - người thuê: Chi tiết / Hủy lịch (sắp tới), Chi tiết / Đánh giá (đã hoàn thành)
/// - chủ trọ: Từ chối / Xác nhận (chờ xác nhận), Hủy / Hoàn thành (đã xác nhận)
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const AppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    final a = appointment;
    final room = s.rooms[a.roomId];
    final tenant = s.userById(a.tenantId);

    return GestureDetector(
      onTap: () => showAppointmentDetail(context, a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoomThumb(room: room, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room?.title ?? 'Phòng #${a.roomId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusChip.appointment(a.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: fmtDate(a.appointmentTime),
                      ),
                      _InfoRow(
                        icon: Icons.access_time,
                        text: fmtTime(a.appointmentTime),
                      ),
                      if (s.role != UserRole.tenant)
                        _InfoRow(
                          icon: Icons.person_outline,
                          text: _person(tenant, a.phone),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActions(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, InteractionService s) {
    final a = appointment;
    final roomName = s.rooms[a.roomId]?.title ?? 'phòng này';

    final detail = _ActionButton(
      label: 'Chi tiết',
      onPressed: () => showAppointmentDetail(context, a),
    );
    final cancel = _ActionButton(
      label: 'Hủy lịch',
      color: IStyle.danger,
      onPressed: () async {
        final ok = await confirmDialog(
          context,
          title: 'Hủy lịch hẹn?',
          message:
              'Bạn chắc chắn muốn hủy lịch xem $roomName lúc ${fmtTime(a.appointmentTime)} ngày ${fmtDateShort(a.appointmentTime)}?',
          confirmText: 'Hủy lịch',
          danger: true,
        );
        if (ok && context.mounted) {
          runAction(
            context,
            () => s.cancelAppointment(a.id),
            success: 'Đã hủy lịch hẹn',
          );
        }
      },
    );

    final List<Widget> actions;
    if (s.role == UserRole.owner && a.status == AppointmentStatus.pending) {
      actions = [
        _ActionButton(
          label: 'Từ chối',
          color: IStyle.danger,
          onPressed: () async {
            final reason = await promptDialog(
              context,
              title: 'Lý do từ chối',
              hint: 'Ví dụ: Phòng đã có người đặt cọc',
              confirmText: 'Từ chối',
            );
            if (reason != null && context.mounted) {
              runAction(
                context,
                () => s.rejectAppointment(a.id, reason),
                success: 'Đã từ chối lịch hẹn',
              );
            }
          },
        ),
        _ActionButton(
          label: 'Xác nhận',
          filled: true,
          onPressed: () => runAction(
            context,
            () => s.confirmAppointment(a.id),
            success: 'Đã xác nhận lịch hẹn',
          ),
        ),
      ];
    } else if (s.role == UserRole.owner &&
        a.status == AppointmentStatus.confirmed) {
      actions = [
        cancel,
        _ActionButton(
          label: 'Hoàn thành',
          filled: true,
          onPressed: () => runAction(
            context,
            () => s.completeAppointment(a.id),
            success: 'Đã đánh dấu hoàn thành',
          ),
        ),
      ];
    } else if (s.role == UserRole.tenant && InteractionService.isUpcoming(a)) {
      actions = [detail, cancel];
    } else if (s.role == UserRole.tenant &&
        a.status == AppointmentStatus.completed) {
      final reviewed = s.reviewForAppointment(a.id) != null;
      actions = [
        detail,
        _ActionButton(
          label: reviewed ? 'Đã đánh giá' : 'Đánh giá',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (ctx) => ReviewReportScreen(appointmentId: a.id),
            ),
          ),
        ),
      ];
    } else {
      actions = [detail];
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

String _person(DemoUser? user, String phone) {
  final name = user?.name ?? '-';
  return phone.isEmpty ? name : '$name · $phone';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: IStyle.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: IStyle.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? IStyle.primary,
          shape: shape,
          minimumSize: const Size.fromHeight(40),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? IStyle.primary,
        side: const BorderSide(color: IStyle.border),
        shape: shape,
        minimumSize: const Size.fromHeight(40),
      ),
      child: Text(label),
    );
  }
}

/// Mở màn "Chi tiết lịch hẹn" (khi bấm "Chi tiết" hoặc bấm vào thẻ).
void showAppointmentDetail(BuildContext context, Appointment a) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => AppointmentDetailScreen(appointmentId: a.id),
    ),
  );
}
