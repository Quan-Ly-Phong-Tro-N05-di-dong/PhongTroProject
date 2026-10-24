// lib/features/contact/models/appointment.dart
import '../../../core/base/base_entity.dart';

enum AppointmentStatus { pending, confirmed, completed, rejected, cancelled }

/// Lịch hẹn xem phòng.
/// Luồng: pending -> confirmed -> completed
///        pending -> rejected
///        pending/confirmed -> cancelled
class Appointment extends BaseEntity<String> {
  final String roomId;
  final String tenantId;
  final String ownerId;
  final DateTime appointmentTime;
  final String note;
  final String phone; // SĐT người thuê để chủ trọ liên lạc
  AppointmentStatus status;
  String? rejectReason;

  Appointment({
    required String id,
    required this.roomId,
    required this.tenantId,
    required this.ownerId,
    required this.appointmentTime,
    this.note = '',
    this.phone = '',
    this.status = AppointmentStatus.pending,
    this.rejectReason,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt ?? DateTime.now());

  /// Đặt lịch mới (có kiểm tra nghiệp vụ). Dùng factory này khi người dùng bấm "Đặt lịch".
  factory Appointment.book({
    required String id,
    required String roomId,
    required String tenantId,
    required String ownerId,
    required DateTime time,
    String note = '',
    String phone = '',
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!time.isAfter(current)) {
      throw ArgumentError('Không thể đặt lịch trong quá khứ');
    }
    if (tenantId == ownerId) {
      throw ArgumentError('Không thể đặt lịch xem phòng của chính mình');
    }
    return Appointment(
      id: id,
      roomId: roomId,
      tenantId: tenantId,
      ownerId: ownerId,
      appointmentTime: time,
      note: note,
      phone: phone,
    );
  }

  void confirm() =>
      _moveTo(AppointmentStatus.confirmed, const {AppointmentStatus.pending});

  void reject(String reason) {
    final text = reason.trim();
    if (text.isEmpty) throw ArgumentError('Cần ghi lý do từ chối');
    _moveTo(AppointmentStatus.rejected, const {AppointmentStatus.pending});
    rejectReason = text;
  }

  void cancel() => _moveTo(AppointmentStatus.cancelled, const {
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
  });

  void complete() =>
      _moveTo(AppointmentStatus.completed, const {AppointmentStatus.confirmed});

  void _moveTo(AppointmentStatus next, Set<AppointmentStatus> allowedFrom) {
    if (!allowedFrom.contains(status)) {
      throw StateError(
        'Không thể chuyển lịch hẹn từ "${status.name}" sang "${next.name}"',
      );
    }
    status = next;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'roomId': roomId,
    'tenantId': tenantId,
    'ownerId': ownerId,
    'appointmentTime': appointmentTime.toIso8601String(),
    'note': note,
    'phone': phone,
    'status': status.name,
    'rejectReason': rejectReason,
  };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    tenantId: json['tenantId'] as String,
    ownerId: json['ownerId'] as String,
    appointmentTime: DateTime.parse(json['appointmentTime'] as String),
    note: (json['note'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    status: AppointmentStatus.values.byName(json['status'] as String),
    rejectReason: json['rejectReason'] as String?,
    createdAt: BaseEntity.parseDate(json['createdAt']),
  );
}
