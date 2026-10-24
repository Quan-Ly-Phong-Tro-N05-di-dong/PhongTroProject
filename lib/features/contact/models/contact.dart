// lib/features/contact/models/contact.dart
import '../../../core/base/base_entity.dart';
import 'contact_message.dart';

/// newMessage: tin mới nhất là của người thuê, chủ trọ chưa xem.
/// read: chủ trọ đã xem, chưa trả lời.
/// replied: tin mới nhất là của chủ trọ.
enum ContactStatus { newMessage, read, replied }

/// Cuộc trò chuyện giữa người thuê và chủ trọ về một phòng.
/// Mỗi tin nhắn là một [ContactMessage].
class Contact extends BaseEntity<String> {
  final String roomId;
  final String tenantId;
  final String ownerId;
  final List<ContactMessage> _messages;
  ContactStatus status;

  Contact({
    required String id,
    required this.roomId,
    required this.tenantId,
    required this.ownerId,
    List<ContactMessage> messages = const [],
    this.status = ContactStatus.newMessage,
    DateTime? createdAt,
  }) : _messages = List<ContactMessage>.of(messages),
       super(id: id, createdAt: createdAt ?? DateTime.now()) {
    if (tenantId == ownerId) {
      throw ArgumentError('Không thể tự liên hệ phòng của chính mình');
    }
  }

  /// Danh sách tin nhắn (chỉ đọc), tin cũ nhất ở đầu.
  List<ContactMessage> get messages => List.unmodifiable(_messages);

  ContactMessage? get lastMessage => _messages.isEmpty ? null : _messages.last;

  /// Chủ trọ chưa xem tin mới nhất của người thuê.
  bool get isUnreadForOwner => status == ContactStatus.newMessage;

  /// Gửi thêm một tin nhắn. Chỉ người thuê hoặc chủ trọ của cuộc trò chuyện được gửi.
  ContactMessage send({
    required String messageId,
    required String senderId,
    required String text,
    DateTime? sentAt,
  }) {
    if (senderId != tenantId && senderId != ownerId) {
      throw ArgumentError(
        'Chỉ người thuê hoặc chủ trọ của phòng này mới nhắn được',
      );
    }
    final message = ContactMessage(
      id: messageId,
      contactId: id,
      senderId: senderId,
      text: text,
      createdAt: sentAt,
    );
    _messages.add(message);
    status = senderId == ownerId
        ? ContactStatus.replied
        : ContactStatus.newMessage;
    return message;
  }

  /// Chủ trọ mở cuộc trò chuyện.
  void markReadByOwner() {
    if (status == ContactStatus.newMessage) status = ContactStatus.read;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'roomId': roomId,
    'tenantId': tenantId,
    'ownerId': ownerId,
    'status': status.name,
    'messages': _messages.map((m) => m.toJson()).toList(),
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    tenantId: json['tenantId'] as String,
    ownerId: json['ownerId'] as String,
    status: ContactStatus.values.byName(json['status'] as String),
    messages: (json['messages'] as List)
        .map((m) => ContactMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    createdAt: BaseEntity.parseDate(json['createdAt']),
  );
}
