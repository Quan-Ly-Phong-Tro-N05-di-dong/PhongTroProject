// lib/features/home_catalog/presentation/screens/counter_screen.dart
import 'package:flutter/material.dart';

// Model dữ liệu mẫu cho phòng trọ
class RoomItem {
  final String id;
  final String title;
  final String address;
  final double price; // Triệu VND / tháng
  final double area;  // m²
  final String imageUrl;

  const RoomItem({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    required this.imageUrl,
  });
}

class CounterScreen extends StatefulWidget {
  final String title;

  const CounterScreen({super.key, required this.title});

  @override
  State<CounterScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<CounterScreen> {
  // Dữ liệu mock phục vụ hiển thị ngay lập tức
  final List<RoomItem> mockRooms = const [
    RoomItem(
      id: '1',
      title: 'Phòng trọ khép kín full đồ gần ĐH Phenikaa',
      address: 'Yên Nghĩa, Hà Đông, Hà Nội',
      price: 2.8,
      area: 25,
      imageUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
    ),
    RoomItem(
      id: '2',
      title: 'Chung cư mini có thang máy, ban công thoáng',
      address: 'Đồng Mai, Hà Đông, Hà Nội',
      price: 3.5,
      area: 32,
      imageUrl: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
    ),
    RoomItem(
      id: '3',
      title: 'Phòng đơn giá rẻ cho sinh viên năm nhất',
      address: 'Dương Nội, Hà Đông, Hà Nội',
      price: 1.6,
      area: 18,
      imageUrl: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600',
    ),
  ];

  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Tất cả', 'Gần Phenikaa', 'Dưới 2 triệu', 'Studio', 'Có gác xép'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Phòng Trọ Giá rẻ 123',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. THANH TÌM KIẾM
            _buildSearchBar(),

            // 2. BỘ LỌC NHANH (CATEGORY CHIPS)
            _buildFilterList(),

            // 3. DANH SÁCH PHÒNG LỰA CHỌN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Phòng nổi bật',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
            ),
            _buildRoomList(),

            const SizedBox(height: 24),

            // 4. FOOTER: Phenikaa-University & Student Name
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Component: Thanh tìm kiếm
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Tìm theo khu vực, đường, trường học...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: () {
                // Mở modal bộ lọc chi tiết
              },
            ),
          ),
        ],
      ),
    );
  }

  // Component: Danh mục lọc ngang
  Widget _buildFilterList() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return ChoiceChip(
            label: Text(
              _filters[index],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: Colors.blueAccent,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.grey.shade300),
            onSelected: (selected) {
              setState(() => _selectedFilterIndex = index);
            },
          );
        },
      ),
    );
  }

  // Component: Danh sách thẻ phòng trọ
  Widget _buildRoomList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: mockRooms.length,
      itemBuilder: (context, index) {
        final room = mockRooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh phòng trọ
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  room.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Giá & Diện tích
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${room.price.toStringAsFixed(1)} triệu/tháng',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        Text(
                          '${room.area.toInt()} m²',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Tiêu đề
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    // Địa chỉ
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Component: Footer theo yêu cầu
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Text(
            'PHENIKAA UNIVERSITY',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khoa Công nghệ Thông tin - Lập trình Di động',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Divider(color: Colors.white24, height: 24),
          const Text(
            'Nhóm sinh viên thực hiện:',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          // Thay danh sách tên thành viên nhóm tại đây
          Wrap(
            spacing: 12,
            children: const [
              Text('• Nguyễn Quang Huy', style: TextStyle(color: Colors.white, fontSize: 13)),
              Text('• Thành viên 2', style: TextStyle(color: Colors.white, fontSize: 13)),
              Text('• Thành viên 3', style: TextStyle(color: Colors.white, fontSize: 13)),
              Text('• Thành viên 4', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}