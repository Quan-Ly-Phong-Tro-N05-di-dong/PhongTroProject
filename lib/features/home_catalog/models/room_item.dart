// lib/features/home_catalog/models/room_item.dart
import '../../../core/base/base_entity.dart';
import '../../../core/base/entity_registry.dart';

/// Phòng trọ (đối tượng có sẵn trong project, nay kế thừa BaseEntity<String>).
/// Trước đây nằm trong counter_screen.dart và không có ==, toJson, fromJson.
class RoomItem extends BaseEntity<String> {
  final String title;
  final String address;
  final double price; // Triệu VND / tháng
  final double area; // m²
  final String imageUrl;

  const RoomItem({
    required String id,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    required this.imageUrl,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt);

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'title': title,
        'address': address,
        'price': price,
        'area': area,
        'imageUrl': imageUrl,
      };

  factory RoomItem.fromJson(Map<String, dynamic> json) => RoomItem(
        id: json['id'] as String,
        title: json['title'] as String,
        address: json['address'] as String,
        price: (json['price'] as num).toDouble(),
        area: (json['area'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String,
        createdAt: BaseEntity.parseDate(json['createdAt']),
      );
}

/// Đăng ký RoomItem với EntityRegistry (gọi 1 lần lúc khởi động app).
void registerRoomModels() {
  EntityRegistry.register<RoomItem>(RoomItem.fromJson, name: 'rooms');
}
