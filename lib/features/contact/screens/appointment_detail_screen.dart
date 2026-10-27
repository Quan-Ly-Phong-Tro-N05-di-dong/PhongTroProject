// lib/features/contact/screens/appointment_detail_screen.dart
//
// Màn "Chi tiết lịch hẹn", dựng theo layout mẫu "Phiên đấu giá" (Câu 5):
// ảnh lớn, thẻ thông tin, đồng hồ đếm ngược, lịch sử trao đổi, nút hành động.
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/appointment_info_card.dart';
import '../widgets/countdown_timer_box.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/message_history_box.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/room_image_box.dart';
import 'contact_chat_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lịch hẹn'), centerTitle: true),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, child) {
          final a = s.appointments.findById(appointmentId);
          if (a == null) {
            return const Center(child: Text('Không tìm thấy lịch hẹn.'));
          }
          final contact = s.findContact(roomId: a.roomId, tenantId: a.tenantId);
          final messages = contact?.messages ?? const <ContactMessage>[];
          final owner = s.userById(a.ownerId);
          final tenant = s.userById(a.tenantId);
          final rejectReason = a.rejectReason;

          final rows = <(String, String)>[
            ('Chủ trọ', _person(owner, owner?.phone ?? '')),
            ('Người thuê', _person(tenant, a.phone)),
            if (a.note.isNotEmpty) ('Ghi chú', a.note),
            if (rejectReason != null) ('Lý do từ chối', rejectReason),
          ];

          // Nút nhắn tin: người thuê nhắn chủ trọ, chủ trọ nhắn người thuê (khi đã có
          // cuộc trò chuyện), admin không có nút này.
          String? buttonLabel;
          VoidCallback? onMessage;
          if (s.role == UserRole.tenant) {
            buttonLabel = 'Nhắn chủ trọ';
            onMessage = () =>
                _openChat(context, ContactChatScreen(roomId: a.roomId));
          } else if (s.role == UserRole.owner) {
            buttonLabel = 'Nhắn người thuê';
            if (contact != null) {
              onMessage = () =>
                  _openChat(context, ContactChatScreen(contactId: contact.id));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RoomImageBox(room: s.rooms[a.roomId]),
              const SizedBox(height: 16),
              AppointmentInfoCard(
                code: '#${a.id}',
                timeText: _dateTime(a.appointmentTime),
                statusText: _statusText(a.status),
              ),
              _ExtraInfo(rows: rows),
              if (InteractionService.isUpcoming(a)) ...[
                const SizedBox(height: 16),
                CountdownTimerBox(target: a.appointmentTime),
              ],
              const SizedBox(height: 16),
              MessageHistoryBox(
                messages: messages,
                nameOf: (id) => s.userById(id)?.name ?? 'Người dùng',
              ),
              const SizedBox(height: 24),
              if (buttonLabel != null)
                PillActionButton(label: buttonLabel, onPressed: onMessage),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

void _openChat(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (ctx) => screen));
}

/// Các dòng thông tin phụ: chủ trọ, người thuê, ghi chú, lý do từ chối.
class _ExtraInfo extends StatelessWidget {
  final List<(String, String)> rows;

  const _ExtraInfo({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: const TextStyle(color: IStyle.muted, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _person(DemoUser? user, String phone) {
  final name = user?.name ?? '-';
  return phone.isEmpty ? name : '$name · $phone';
}

String _statusText(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Chờ xác nhận',
  AppointmentStatus.confirmed => 'Đã xác nhận',
  AppointmentStatus.completed => 'Đã hoàn thành',
  AppointmentStatus.rejected => 'Đã từ chối',
  AppointmentStatus.cancelled => 'Đã hủy',
};

String _dateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
}
