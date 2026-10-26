// lib/features/auth/models/avatar.dart

// Ảnh đại diện, tương ứng với document avatars/{userId} trên Firestore
class Avatar {
  final String userId;
  final String data; // Ảnh đã nén, dạng Base64

  const Avatar({required this.userId, required this.data});

  factory Avatar.fromMap(String id, Map<String, dynamic> map) {
    return Avatar(userId: id, data: map['data'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'data': data};
}
