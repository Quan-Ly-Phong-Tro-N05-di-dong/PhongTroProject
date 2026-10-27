// lib/features/contact/widgets/report_form.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import 'interaction_ui.dart';

const List<String> reportReasons = [
  'Thông tin không chính xác',
  'Lừa đảo / giả mạo',
  'Nội dung phản cảm',
  'Spam / quảng cáo',
  'Khác',
];

/// Form báo cáo vi phạm (bài đăng / người dùng / đánh giá).
class ReportForm extends StatefulWidget {
  final ReportTarget type;
  final String targetId;
  final VoidCallback? onSubmitted;

  const ReportForm({
    super.key,
    required this.type,
    required this.targetId,
    this.onSubmitted,
  });

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final TextEditingController _description = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lý do báo cáo')),
      );
      return;
    }
    final ok = runAction(
      context,
      () => InteractionService.instance.submitReport(
        type: widget.type,
        targetId: widget.targetId,
        reason: reason,
        description: _description.text,
      ),
      success: 'Đã gửi báo cáo. Cảm ơn bạn!',
    );
    if (ok) {
      _description.clear();
      setState(() => _reason = null);
      widget.onSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lý do', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final reason in reportReasons)
              ChoiceChip(
                label: Text(reason),
                selected: _reason == reason,
                selectedColor: IStyle.primarySoft,
                onSelected: (_) => setState(() => _reason = reason),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Mô tả chi tiết vấn đề...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: IStyle.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Báo cáo của bạn được bảo mật.',
                  style: TextStyle(fontSize: 12, color: IStyle.danger),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Báo cáo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IStyle.danger,
              side: const BorderSide(color: IStyle.danger),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mở form báo cáo dạng bottom sheet (dùng cho nút "Báo cáo" ở bài đăng, đánh giá).
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget type,
  required String targetId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ReportForm(
              type: type,
              targetId: targetId,
              onSubmitted: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}
