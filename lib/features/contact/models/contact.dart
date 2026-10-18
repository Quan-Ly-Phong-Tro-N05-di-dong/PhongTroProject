// lib/features/contact/models/contact.dart
import '../../../core/base/base_entity.dart';

enum ContactStatus { newMessage, read, replied }

/// Tin nhắn liên hệ của người thuê gửi chủ trọ về một phòng.
class Contact extends BaseEntity<String> {
  static const int maxMessageLength = 500;

  final String roomId;
  final String senderId;
  final String ownerId;
  final String message;
  String? reply;
  ContactStatus status;

  Contact({
    required String id,
    required this.roomId,
    required this.senderId,
    required this.ownerId,
    required this.message,
    this.reply,
    this.status = ContactStatus.newMessage,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt ?? DateTime.now()) {
    if (senderId == ownerId) {
      throw ArgumentError('Không thể tự liên hệ phòng của chính mình');
    }
    final text = message.trim();
    if (text.isEmpty || text.length > maxMessageLength) {
      throw ArgumentError('Tin nhắn phải từ 1 đến $maxMessageLength ký tự');
    }
  }

  /// Chủ trọ đã xem tin.
  void markRead() {
    if (status == ContactStatus.newMessage) status = ContactStatus.read;
  }

  /// Chủ trọ trả lời tin.
  void replyWith(String text) {
    final answer = text.trim();
    if (answer.isEmpty) throw ArgumentError('Nội dung trả lời không được trống');
    reply = answer;
    status = ContactStatus.replied;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'roomId': roomId,
        'senderId': senderId,
        'ownerId': ownerId,
        'message': message,
        'reply': reply,
        'status': status.name,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        senderId: json['senderId'] as String,
        ownerId: json['ownerId'] as String,
        message: json['message'] as String,
        reply: json['reply'] as String?,
        status: ContactStatus.values.byName(json['status'] as String),
        createdAt: BaseEntity.parseDate(json['createdAt']),
      );
}
