// lib/features/contact/widgets/room_actions.dart
//
// Các nút/khối để người ghép trang CHI TIẾT PHÒNG nhúng vào, không cần viết lại:
//
//   Scaffold(
//     body: ListView(children: [
//       ...thông tin phòng (module Bài đăng)...,
//       ...thông tin chủ trọ (module Đăng nhập)...,
//       ReviewList(roomId: room.id),          // điểm sao + danh sách đánh giá
//       ReportButton(roomId: room.id),        // báo cáo tin đăng
//     ]),
//     bottomNavigationBar: RoomActionBar(roomId: room.id), // 2 nút Liên hệ / Đặt lịch
//   )
//
// Các nút Liên hệ, Đặt lịch, Báo cáo đều gọi requireLogin (module Đăng nhập):
// chưa đăng nhập thì hiện hộp thoại mời đăng nhập, đăng nhập xong mới mở tiếp.
//
// Điểm sao trung bình cho thẻ phòng ở trang chủ:
//   InteractionService.instance.ratingSummary(room.id)  -> (average, count)
import 'package:flutter/material.dart';

import '../../auth/widgets/role_guard.dart';
import '../models/contact_models.dart';
import '../screens/booking_screen.dart';
import '../screens/contact_chat_screen.dart';
import '../services/interaction_service.dart';
import 'interaction_ui.dart';
import 'report_form.dart';

export 'review_list.dart';

/// Nút "Liên hệ": mở màn nhắn tin với chủ trọ của phòng (cần đăng nhập).
class ContactButton extends StatelessWidget {
  final String roomId;

  const ContactButton({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) => OutlinedButton.icon(
        onPressed: s.role == UserRole.tenant
            ? () async {
                if (!await requireLogin(context)) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (ctx) => ContactChatScreen(roomId: roomId),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Liên hệ'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: IStyle.primary,
          side: const BorderSide(color: IStyle.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Nút "Đặt lịch": mở form đặt lịch xem phòng (cần đăng nhập).
class BookingButton extends StatelessWidget {
  final String roomId;

  const BookingButton({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) => FilledButton.icon(
        onPressed: s.role == UserRole.tenant
            ? () async {
                if (!await requireLogin(context)) return;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (ctx) => BookingScreen(roomId: roomId),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.event_available),
        label: const Text('Đặt lịch'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: IStyle.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Nút "Báo cáo tin đăng" (cần đăng nhập).
class ReportButton extends StatelessWidget {
  final String roomId;

  const ReportButton({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        if (!await requireLogin(context)) return;
        if (!context.mounted) return;
        showReportSheet(
          context,
          type: ReportTarget.room,
          targetId: roomId,
          title: 'Báo cáo tin đăng',
        );
      },
      icon: const Icon(Icons.flag_outlined),
      label: const Text('Báo cáo tin đăng'),
      style: TextButton.styleFrom(foregroundColor: IStyle.muted),
    );
  }
}

/// Thanh 2 nút Liên hệ / Đặt lịch ở đáy trang chi tiết phòng.
class RoomActionBar extends StatelessWidget {
  final String roomId;

  const RoomActionBar({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: IStyle.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: ContactButton(roomId: roomId)),
            const SizedBox(width: 12),
            Expanded(child: BookingButton(roomId: roomId)),
          ],
        ),
      ),
    );
  }
}
