// lib/features/contact/screens/room_demo_screens.dart
//
// TRANG MẪU để thử luồng: chi tiết phòng -> liên hệ -> đặt lịch -> đánh giá -> báo cáo.
// Khi trang chi tiết phòng thật của nhóm xong, người ghép trang chỉ cần nhúng:
//   ReviewList(roomId: ...), ReportButton(roomId: ...), RoomActionBar(roomId: ...)
// (xem room_actions.dart) rồi có thể bỏ file này và tab "Phòng".
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import '../widgets/rating_stars.dart';
import '../widgets/room_actions.dart';
import '../widgets/room_summary_card.dart';

/// Tab "Phòng": danh sách phòng mẫu (người thuê).
class RoomsDemoTab extends StatelessWidget {
  const RoomsDemoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final rooms = s.visibleRooms;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: IStyle.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: IStyle.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phòng mẫu để thử luồng Liên hệ, Đặt lịch, Đánh giá, Báo cáo. '
                      'Khi trang chi tiết phòng thật xong thì bỏ tab này.',
                      style: TextStyle(fontSize: 12.5, color: IStyle.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (rooms.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.home_work_outlined,
                  message: 'Không còn phòng nào để hiển thị.',
                ),
              ),
            for (final room in rooms)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (ctx) => RoomDetailDemoScreen(roomId: room.id),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      RoomThumb(room: room, size: 72),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fmtVnd(room.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: IStyle.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _RatingLine(roomId: room.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RatingLine extends StatelessWidget {
  final String roomId;

  const _RatingLine({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final summary = InteractionService.instance.ratingSummary(roomId);
    return Row(
      children: [
        RatingStars(rating: summary.average, size: 14),
        const SizedBox(width: 6),
        Text(
          summary.count == 0
              ? 'Chưa có đánh giá'
              : '${summary.average.toStringAsFixed(1)} (${summary.count})',
          style: const TextStyle(fontSize: 12, color: IStyle.muted),
        ),
      ],
    );
  }
}

/// Trang chi tiết phòng mẫu (giống mockup màn 1), có sẵn đánh giá, báo cáo và thanh Liên hệ / Đặt lịch.
class RoomDetailDemoScreen extends StatelessWidget {
  final String roomId;

  const RoomDetailDemoScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final room = s.rooms[roomId];
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chi tiết phòng')),
            body: const EmptyState(
              icon: Icons.home_work_outlined,
              message: 'Không tìm thấy phòng này.',
            ),
          );
        }
        final summary = s.ratingSummary(roomId);
        final owner = s.userById(s.ownerOf(roomId));

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Chi tiết phòng'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
          ),
          body: ListView(
            children: [
              Image.network(
                room.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.home_work_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fmtVnd(room.price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: IStyle.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: IStyle.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.address,
                            style: const TextStyle(color: IStyle.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          icon: Icons.square_foot,
                          text: '${room.area.toInt()} m²',
                        ),
                        _Pill(
                          icon: Icons.star_rounded,
                          iconColor: IStyle.star,
                          text: summary.count == 0
                              ? 'Chưa có đánh giá'
                              : '${summary.average.toStringAsFixed(1)}/5 · ${summary.count} đánh giá',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Thông tin chủ trọ: dữ liệu của module Đăng nhập & phân quyền.
                    if (owner != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            InitialsAvatar(name: owner.name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    owner.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${owner.phone} · Chủ trọ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: IStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    ReviewList(roomId: roomId),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ReportButton(roomId: roomId),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: RoomActionBar(roomId: roomId),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _Pill({
    required this.icon,
    required this.text,
    this.iconColor = IStyle.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
