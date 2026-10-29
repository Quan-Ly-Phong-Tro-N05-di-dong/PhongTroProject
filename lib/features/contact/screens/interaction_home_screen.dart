// lib/features/contact/screens/interaction_home_screen.dart
//
// Màn hình chính của module "Tương tác & phản hồi người dùng".
// Gắn vào tab "Liên Hệ" của MainScreen. Giao diện đổi theo vai trò:
//   - Người thuê: Lịch hẹn | Tin nhắn | Đánh giá | Phòng
//   - Chủ trọ:    Lịch hẹn | Tin nhắn | Đánh giá
//   - Admin:      Báo cáo | Đánh giá
//
// Có 2 chế độ (InteractionService.isDemo):
//   - Demo (dữ liệu giả, dùng trong test): có thanh chọn vai trò ở trên cùng.
//   - Thật (đã nối Firebase, xem ContactFirebase): vai trò lấy từ tài khoản đăng nhập,
//     thanh chọn vai trò được thay bằng dòng "Đang đăng nhập: ...".
import 'package:flutter/material.dart';

import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';
import 'appointments_tab.dart';
import 'conversations_tab.dart';
import 'reports_tab.dart';
import 'reviews_tab.dart';
import 'room_demo_screens.dart';

class InteractionHomeScreen extends StatelessWidget {
  const InteractionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final role = s.role;
        final unread = s.unreadContactCount();
        final tabs = <(String, Widget)>[
          if (role == UserRole.admin) ...[
            ('Báo cáo', const ReportsTab()),
            ('Đánh giá', const ReviewsTab()),
          ] else ...[
            ('Lịch hẹn', const AppointmentsTab()),
            (
              unread > 0 ? 'Tin nhắn ($unread)' : 'Tin nhắn',
              const ConversationsTab(),
            ),
            ('Đánh giá', const ReviewsTab()),
            if (role == UserRole.tenant) ('Phòng', const RoomsDemoTab()),
          ],
        ];

        return DefaultTabController(
          key: ValueKey(role),
          length: tabs.length,
          child: Scaffold(
            backgroundColor: IStyle.background,
            appBar: AppBar(
              title: const Text('Tương tác & phản hồi'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
            ),
            body: Column(
              children: [
                if (s.isDemo) _RoleBar(service: s) else _UserBar(service: s),
                Material(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: IStyle.primary,
                    unselectedLabelColor: IStyle.muted,
                    indicatorColor: IStyle.primary,
                    tabs: [for (final tab in tabs) Tab(text: tab.$1)],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [for (final tab in tabs) tab.$2]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dòng cho biết đang dùng tài khoản nào (chế độ dữ liệu thật).
class _UserBar extends StatelessWidget {
  final InteractionService service;

  const _UserBar({required this.service});

  @override
  Widget build(BuildContext context) {
    final user = service.currentUser;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'Đang đăng nhập: ${user.name} · ${user.role.label}',
        style: const TextStyle(fontSize: 12, color: IStyle.muted),
      ),
    );
  }
}

/// Chọn vai trò để xem 3 giao diện (chỉ dùng khi demo).
class _RoleBar extends StatelessWidget {
  final InteractionService service;

  const _RoleBar({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<UserRole>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: IStyle.primary,
                selectedForegroundColor: Colors.white,
              ),
              segments: [
                for (final role in UserRole.values)
                  ButtonSegment<UserRole>(value: role, label: Text(role.label)),
              ],
              selected: {service.role},
              onSelectionChanged: (value) => service.switchRole(value.first),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chế độ demo · đang xem với tư cách ${service.currentUser.name}',
            style: const TextStyle(fontSize: 11.5, color: IStyle.muted),
          ),
        ],
      ),
    );
  }
}
