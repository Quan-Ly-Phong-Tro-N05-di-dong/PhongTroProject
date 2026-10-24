// lib/features/contact/models/contact_message.dart
import '../../../core/base/base_entity.dart';

/// Một tin nhắn trong cuộc trò chuyện giữa người thuê và chủ trọ.
class ContactMessage extends BaseEntity<String> {
  static const int maxLength = 500;

  final String contactId;
  final String senderId;
  final String text;

  ContactMessage({
    required String id,
    required this.contactId,
    required this.senderId,
    required this.text,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt ?? DateTime.now()) {
    final value = text.trim();
    if (value.isEmpty || value.length > maxLength) {
      throw ArgumentError('Tin nhắn phải từ 1 đến $maxLength ký tự');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'contactId': contactId,
    'senderId': senderId,
    'text': text,
  };

  factory ContactMessage.fromJson(Map<String, dynamic> json) => ContactMessage(
    id: json['id'] as String,
    contactId: json['contactId'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
    createdAt: BaseEntity.parseDate(json['createdAt']),
  );
}
