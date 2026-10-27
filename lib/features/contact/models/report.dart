// lib/features/contact/models/report.dart
import '../../../core/base/base_entity.dart';

enum ReportTarget { room, user, review }

enum ReportStatus { pending, resolved, dismissed }

/// Báo cáo vi phạm (bài đăng / người dùng / đánh giá), admin xử lý.
class Report extends BaseEntity<String> {
  final String reporterId;
  final ReportTarget targetType;
  final String targetId;
  final String reason;
  final String description;
  ReportStatus status;
  String? handledBy;
  DateTime? handledAt;
  String? adminNote;

  Report({
    required String id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description = '',
    this.status = ReportStatus.pending,
    this.handledBy,
    this.handledAt,
    this.adminNote,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt ?? DateTime.now()) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Cần chọn lý do báo cáo');
    }
  }

  /// Admin xác nhận vi phạm và đã xử lý.
  void resolve({required String adminId, String note = ''}) =>
      _close(ReportStatus.resolved, adminId, note);

  /// Admin bỏ qua báo cáo.
  void dismiss({required String adminId, String note = ''}) =>
      _close(ReportStatus.dismissed, adminId, note);

  void _close(ReportStatus next, String adminId, String note) {
    if (status != ReportStatus.pending) {
      throw StateError('Báo cáo này đã được xử lý');
    }
    status = next;
    handledBy = adminId;
    handledAt = DateTime.now();
    adminNote = note.isEmpty ? null : note;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'reporterId': reporterId,
    'targetType': targetType.name,
    'targetId': targetId,
    'reason': reason,
    'description': description,
    'status': status.name,
    'handledBy': handledBy,
    'handledAt': handledAt?.toIso8601String(),
    'adminNote': adminNote,
  };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] as String,
    reporterId: json['reporterId'] as String,
    targetType: ReportTarget.values.byName(json['targetType'] as String),
    targetId: json['targetId'] as String,
    reason: json['reason'] as String,
    description: (json['description'] as String?) ?? '',
    status: ReportStatus.values.byName(json['status'] as String),
    handledBy: json['handledBy'] as String?,
    handledAt: BaseEntity.parseDate(json['handledAt']),
    adminNote: json['adminNote'] as String?,
    createdAt: BaseEntity.parseDate(json['createdAt']),
  );
}
