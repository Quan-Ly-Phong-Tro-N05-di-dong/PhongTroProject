// lib/features/home_catalog/presentation/screens/room_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'counter_screen.dart'; // Import để nhận kiểu RoomItem

// 1. Model dữ liệu mở rộng trả về từ API Chi tiết phòng & Chủ trọ
class RoomExtraDetail {
  final String description;
  final double electricPrice; // Nghìn/kWh
  final double waterPrice;    // Nghìn/khối
  final List<String> amenities;
  final String landlordName;
  final String landlordPhone;
  final String landlordZalo;
  final String landlordAvatar;
  final int totalRoomsOwned;

  const RoomExtraDetail({
    required this.description,
    required this.electricPrice,
    required this.waterPrice,
    required this.amenities,
    required this.landlordName,
    required this.landlordPhone,
    required this.landlordZalo,
    required this.landlordAvatar,
    required this.totalRoomsOwned,
  });
}

class RoomDetailScreen extends StatefulWidget {
  final RoomItem room; // Nhận dữ liệu cơ bản để render ngay lập tức

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late Future<RoomExtraDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    // Kích hoạt gọi API lấy thông tin chi tiết & chủ trọ theo ID phòng
    _detailFuture = _fetchRoomDetailFromApi(widget.room.id);
  }

  // Giả lập hàm gọi API từ chức năng khác (Sau này thay bằng http.get hoặc Firebase)
  Future<RoomExtraDetail> _fetchRoomDetailFromApi(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 600)); // Giả lập độ trễ mạng
    return const RoomExtraDetail(
      description:
          'Phòng trọ xây mới thoáng mát, có cửa sổ lớn đón ánh sáng tự nhiên.\n'
          '- Giờ giấc tự do, khóa vân tay an ninh 2 lớp, camera 24/7.\n'
          '- Cách cổng trường ĐH Phenikaa 500m, gần trạm xe buýt BRT.\n'
          '- Khu vực để xe tầng 1 rộng rãi miễn phí.',
      electricPrice: 3.5,
      waterPrice: 25.0,
      amenities: ['Điều hòa', 'Nóng lạnh', 'Giường tủ', 'Tủ lạnh', 'Máy giặt chung', 'Wifi tốc độ cao'],
      landlordName: 'Nguyễn Quang Huy',
      landlordPhone: '0987654321',
      landlordZalo: '0987654321',
      landlordAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
      totalRoomsOwned: 12,
    );
  }

  // Xử lý sự kiện liên hệ (Tương thích cả Web và Mobile mà không cần cài thêm thư viện ngoài)
  void _handleContact(BuildContext context, String type, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép số $type ($value)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    // Lưu ý: Khi lên production, nếu dùng url_launcher thì gọi:
    // launchUrl(Uri.parse(type == 'Zalo' ? 'https://zalo.me/$value' : 'tel:$value'));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. ẢNH BÌA CO GIÃN (SLIVER APP BAR) - HIỂN THỊ TỨC THÌ TỪ ROOMITEM
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.blueAccent,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                room.imageURL,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),

          // 2. NỘI DUNG CHI TIẾT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin sẵn có (Render ngay không cần chờ API)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${room.price.toStringAsFixed(1)} triệu/tháng',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${room.area.toInt()} m² • ${room.furniture}',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    room.title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.address,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // 3. PHẦN DỮ LIỆU TẢI TỪ API (CHỦ TRỌ, TIỆN ÍCH, MÔ TẢ)
                  FutureBuilder<RoomExtraDetail>(
                    future: _detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Center(child: Text('Không thể tải thông tin chi tiết từ máy chủ.'));
                      }

                      final detail = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Phí dịch vụ (Điện / Nước)
                          const Text('Chi phí dịch vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildServiceCostBadge(Icons.bolt, 'Giá điện', '${detail.electricPrice}k / kWh'),
                              const SizedBox(width: 12),
                              _buildServiceCostBadge(Icons.water_drop, 'Giá nước', '${detail.waterPrice.toInt()}k / khối'),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Tiện ích phòng
                          const Text('Tiện ích có sẵn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: detail.amenities.map((item) {
                              return Chip(
                                avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                label: Text(item, style: const TextStyle(fontSize: 13)),
                                backgroundColor: Colors.grey.shade100,
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Mô tả chi tiết
                          const Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            detail.description,
                            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                          ),
                          const SizedBox(height: 24),

                          // THÔNG TIN CHỦ TRỌ (CARD RIÊNG BIỆT)
                          const Text('Thông tin chủ trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildLandlordCard(detail),
                          const SizedBox(height: 80), // Khoảng trống tránh bị che bởi BottomBar
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 4. THANH NÚT BẤM LIÊN HỆ CỐ ĐỊNH Ở ĐÁY MÀN HÌNH (STICKY ACTION BAR)
      bottomNavigationBar: FutureBuilder<RoomExtraDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final phone = snapshot.data?.landlordPhone ?? '0987654321';
          final zalo = snapshot.data?.landlordZalo ?? '0987654321';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Nút Chat Zalo
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleContact(context, 'liên lạc', zalo),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                      label: const Text(
                        'Chat',
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nút Gọi điện trực tiếp
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleContact(context, 'Điện thoại', phone),
                      icon: const Icon(Icons.phone_in_talk),
                      label: Text(
                        'Gọi $phone',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceCostBadge(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordCard(RoomExtraDetail detail) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: NetworkImage(detail.landlordAvatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.landlordName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đang cho thuê ${detail.totalRoomsOwned} phòng • Đã xác thực SĐT',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Colors.blueAccent),
        ],
      ),
    );
  }
}