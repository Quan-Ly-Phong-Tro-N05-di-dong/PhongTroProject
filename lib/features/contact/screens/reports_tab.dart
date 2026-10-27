// lib/features/contact/screens/reports_tab.dart
import 'package:flutter/material.dart';

import '../models/contact_models.dart';
import '../services/interaction_service.dart';
import '../widgets/interaction_ui.dart';

/// Màn quản lý báo cáo của admin: xem báo cáo, bỏ qua hoặc xác nhận vi phạm
/// (ẩn bài / khóa tài khoản / xóa đánh giá tùy đối tượng bị báo cáo).
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  bool _showPending = true;

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, child) {
        final pending = s.reportsByPending(true);
        final done = s.reportsByPending(false);
        final shown = _showPending ? pending : done;

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
                      label: Text('Chờ xử lý · ${pending.length}'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Đã xử lý · ${done.length}'),
                    ),
                  ],
                  selected: {_showPending},
                  onSelectionChanged: (value) =>
                      setState(() => _showPending = value.first),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(
                      icon: Icons.verified_user_outlined,
                      message: _showPending
                          ? 'Không có báo cáo nào đang chờ xử lý.'
                          : 'Chưa có báo cáo nào được xử lý.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: shown.length,
                      itemBuilder: (context, index) =>
                          _ReportCard(report: shown[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;

  const _ReportCard({required this.report});

  Future<void> _dismiss(BuildContext context) async {
    final s = InteractionService.instance;
    final note = await promptDialog(
      context,
      title: 'Bỏ qua báo cáo?',
      hint: 'Ghi chú (không bắt buộc)',
      confirmText: 'Bỏ qua',
    );
    if (note != null && context.mounted) {
      runAction(
        context,
        () => s.dismissReport(report.id, note: note),
        success: 'Đã bỏ qua báo cáo',
      );
    }
  }

  Future<void> _resolve(BuildContext context) async {
    final s = InteractionService.instance;
    final action = report.targetType.actionLabel;
    final note = await promptDialog(
      context,
      title: '$action?',
      hint: 'Ghi chú (không bắt buộc)',
      confirmText: action,
    );
    if (note != null && context.mounted) {
      runAction(
        context,
        () => s.resolveReport(report.id, note: note),
        success: 'Đã xử lý: $action',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = InteractionService.instance;
    final reporter = s.userById(report.reporterId);
    final pending = report.status == ReportStatus.pending;
    final adminNote = report.adminNote;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: IStyle.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Báo cáo ${report.targetType.label.toLowerCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StatusChip.report(report.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.describeTarget(report),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('Lý do: ${report.reason}', style: const TextStyle(fontSize: 13)),
          if (report.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                report.description,
                style: const TextStyle(fontSize: 13, color: IStyle.muted),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Người báo cáo: ${reporter?.name ?? report.reporterId} · '
            '${fmtDateTime(report.createdAt ?? s.now())}',
            style: const TextStyle(fontSize: 12, color: IStyle.muted),
          ),
          if (adminNote != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IStyle.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Đã xử lý: $adminNote',
                style: const TextStyle(fontSize: 13, color: IStyle.primary),
              ),
            ),
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismiss(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: IStyle.muted,
                      side: const BorderSide(color: IStyle.border),
                      shape: shape,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _resolve(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: IStyle.danger,
                      shape: shape,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text(report.targetType.actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
