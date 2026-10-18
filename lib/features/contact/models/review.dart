// lib/features/contact/models/review.dart
import '../../../core/base/base_entity.dart';
import 'appointment.dart';

/// Số liệu tổng hợp đánh giá của một phòng (cho trang chủ / tìm kiếm / gợi ý dùng).
class RatingSummary {
  final double average;
  final int count;

  const RatingSummary({required this.average, required this.count});

  Map<String, dynamic> toJson() => {'avg': average, 'count': count};

  @override
  String toString() =>
      'RatingSummary(avg: ${average.toStringAsFixed(1)}, count: $count)';
}

/// Đánh giá phòng (1-5 sao) sau khi lịch hẹn đã hoàn thành.
class Review extends BaseEntity<String> {
  static const int minRating = 1;
  static const int maxRating = 5;

  final String roomId;
  final String userId;
  final String appointmentId;
  int rating;
  String comment;
  String? ownerReply;

  Review({
    required String id,
    required this.roomId,
    required this.userId,
    required this.appointmentId,
    required this.rating,
    this.comment = '',
    this.ownerReply,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt ?? DateTime.now()) {
    _checkRating(rating);
  }

  /// Tạo đánh giá từ một lịch hẹn: chỉ được đánh giá khi lịch đã hoàn thành.
  factory Review.forAppointment(
    Appointment appointment, {
    required String id,
    required int rating,
    String comment = '',
  }) {
    if (appointment.status != AppointmentStatus.completed) {
      throw StateError('Chỉ được đánh giá khi lịch hẹn đã hoàn thành');
    }
    return Review(
      id: id,
      roomId: appointment.roomId,
      userId: appointment.tenantId,
      appointmentId: appointment.id,
      rating: rating,
      comment: comment,
    );
  }

  void edit({int? rating, String? comment}) {
    if (rating != null) {
      _checkRating(rating);
      this.rating = rating;
    }
    if (comment != null) this.comment = comment;
  }

  void replyAsOwner(String text) {
    final answer = text.trim();
    if (answer.isEmpty) throw ArgumentError('Nội dung phản hồi không được trống');
    ownerReply = answer;
  }

  static void _checkRating(int value) {
    if (value < minRating || value > maxRating) {
      throw ArgumentError('Số sao phải từ $minRating đến $maxRating');
    }
  }

  /// Điểm trung bình + số lượt đánh giá (dùng cho API rating-summary).
  static RatingSummary summarize(Iterable<Review> reviews) {
    if (reviews.isEmpty) return const RatingSummary(average: 0, count: 0);
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return RatingSummary(average: total / reviews.length, count: reviews.length);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'roomId': roomId,
        'userId': userId,
        'appointmentId': appointmentId,
        'rating': rating,
        'comment': comment,
        'ownerReply': ownerReply,
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        userId: json['userId'] as String,
        appointmentId: json['appointmentId'] as String,
        rating: json['rating'] as int,
        comment: (json['comment'] as String?) ?? '',
        ownerReply: json['ownerReply'] as String?,
        createdAt: BaseEntity.parseDate(json['createdAt']),
      );
}
