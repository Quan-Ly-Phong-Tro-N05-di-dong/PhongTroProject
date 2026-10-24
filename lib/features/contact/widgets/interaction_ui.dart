// lib/features/contact/widgets/interaction_ui.dart
//
// Màu sắc, hàm định dạng và tiện ích giao diện dùng chung cho module
// "Tương tác & phản hồi người dùng".
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';

class IStyle {
  IStyle._();

  static const Color primary = Color(0xFF2F5FE3);
  static const Color primarySoft = Color(0xFFEEF3FF);
  static const Color background = Color(0xFFF8F9FA);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color star = Color(0xFFF59E0B);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
}

// ---------------------------------------------------------------------------
// Định dạng ngày giờ / tiền (không cần thêm thư viện intl)
// ---------------------------------------------------------------------------

const List<String> _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

String _two(int n) => n.toString().padLeft(2, '0');

String weekdayVi(DateTime d) => _weekdays[d.weekday - 1];

/// Ví dụ: Thứ Bảy, 03/10/2026
String fmtDate(DateTime d) =>
    '${weekdayVi(d)}, ${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Ví dụ: 03/10/2026
String fmtDateShort(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Ví dụ: 09:30
String fmtHm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

String fmtTime(DateTime d) => fmtHm(d.hour, d.minute);

/// Ví dụ: 09:30 · 03/10/2026
String fmtDateTime(DateTime d) => '${fmtTime(d)} · ${fmtDateShort(d)}';

/// Giá trong RoomItem tính bằng triệu: 2.5 -> "2.500.000 VNĐ/tháng".
String fmtVnd(double millions) {
  final digits = (millions * 1000000).round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer VNĐ/tháng';
}

/// Chữ cái đầu của tên (chữ cuối cùng trong họ tên): "Nguyễn Văn A" -> "A".
String initialOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.isEmpty ? '?' : parts.last.substring(0, 1).toUpperCase();
}

// ---------------------------------------------------------------------------
// Hàm tiện ích
// ---------------------------------------------------------------------------

/// Chạy một thao tác của service. Nếu vi phạm quy tắc nghiệp vụ thì hiện lỗi
/// dễ hiểu bằng SnackBar. Trả về true nếu thành công.
bool runAction(BuildContext context, VoidCallback action, {String? success}) {
  final messenger = ScaffoldMessenger.of(context);
  try {
    action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(friendlyError(e)), backgroundColor: IStyle.danger),
    );
    return false;
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Đồng ý',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Không'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmText,
            style: TextStyle(color: danger ? IStyle.danger : IStyle.primary),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Hộp thoại nhập văn bản. Trả về null nếu người dùng bấm Hủy.
Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  String hint = '',
  String initial = '',
  String confirmText = 'Gửi',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      hint: hint,
      initial: initial,
      confirmText: confirmText,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  final String confirmText;

  const _PromptDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirmText,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: IStyle.border),
);

// ---------------------------------------------------------------------------
// Widget nhỏ dùng chung
// ---------------------------------------------------------------------------

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialsAvatar({super.key, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: IStyle.primarySoft,
      child: Text(
        initialOf(name),
        style: TextStyle(
          color: IStyle.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IStyle.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn trạng thái bo tròn (Chờ xác nhận, Đã xác nhận...).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.appointment(AppointmentStatus status) {
    final (label, color) = switch (status) {
      AppointmentStatus.pending => ('Chờ xác nhận', IStyle.warning),
      AppointmentStatus.confirmed => ('Đã xác nhận', IStyle.success),
      AppointmentStatus.completed => ('Đã hoàn thành', IStyle.muted),
      AppointmentStatus.rejected => ('Từ chối', IStyle.danger),
      AppointmentStatus.cancelled => ('Đã hủy', IStyle.muted),
    };
    return StatusChip(label: label, color: color);
  }

  factory StatusChip.report(ReportStatus status) {
    final (label, color) = switch (status) {
      ReportStatus.pending => ('Chờ xử lý', IStyle.warning),
      ReportStatus.resolved => ('Đã xử lý', IStyle.success),
      ReportStatus.dismissed => ('Đã bỏ qua', IStyle.muted),
    };
    return StatusChip(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
