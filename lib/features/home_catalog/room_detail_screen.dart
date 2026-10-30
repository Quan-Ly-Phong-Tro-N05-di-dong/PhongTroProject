// lib/features/home_catalog/presentation/screens/room_detail_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/room_item.dart';

class RoomDetailScreen extends StatefulWidget {
  final RoomItem room; // Nhận dữ liệu cơ bản để render ngay lập tức

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late Future<RoomExtraDetail> _detailFuture;
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Kích hoạt truy vấn Firebase lấy thông tin chi tiết & chủ trọ theo ID bài đăng (postId)
    _detailFuture =
        RoomDetailFirebaseService.instance.fetchAndSyncRoomDetail(widget.room);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Tổng hợp toàn bộ ảnh đã đăng của phòng từ `RoomItem` và `RoomExtraDetail`
  List<String> _resolveAllImages(RoomExtraDetail? detail) {
    final set = <String>{
      ...widget.room.allImages,
      if (detail != null)
        ...detail.imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty),
    };
    return set.toList();
  }

  void _goToImage(int index, int total) {
    if (index < 0 || index >= total || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Mở trình xem ảnh phóng to toàn màn hình, hỗ trợ vuốt ngang trái/phải và zoom
  void _openFullScreenGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenRoomGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  /// Đầu chờ mở UI nhập/cập nhật `RoomExtraDetail` của thành viên khác (nếu đã đăng ký qua `RoomExtraDetailIntegration`)
  Future<void> _openExtraDetailFormIfRegistered(
    RoomExtraDetail? currentDetail,
  ) async {
    final updated = await RoomExtraDetailIntegration.openExtraDetailForm(
      context,
      postId: widget.room.id,
      ownerId: widget.room.ownerId,
      initialDetail: currentDetail ?? widget.room.extraDetail,
    );
    if (updated != null && mounted) {
      setState(() {
        _detailFuture = Future.value(updated);
      });
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return FutureBuilder<RoomExtraDetail>(
      future: _detailFuture,
      initialData: room.extraDetail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final images = _resolveAllImages(detail);
        final safeIndex = images.isEmpty
            ? 0
            : _currentImageIndex.clamp(0, images.length - 1);

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              // 1. SLIDER ẢNH PHÒNG CO GIÃN (SLIVER APP BAR) - LƯỚT NGANG TRÁI/PHẢI XEM TẤT CẢ ẢNH
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.blueAccent,
                actions: [
                  if (RoomExtraDetailIntegration.isFormRegistered)
                    IconButton(
                      tooltip: 'Cập nhật chi tiết phòng',
                      icon: const Icon(Icons.edit_note),
                      onPressed: () => _openExtraDetailFormIfRegistered(detail),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageCarousel(images, safeIndex),
                ),
              ),

              // 2. DẢI THUMBNAIL CHỌN NHANH ẢNH (Chỉ hiển thị khi phòng có nhiều hơn 1 ảnh)
              if (images.length > 1)
                SliverToBoxAdapter(
                  child: _buildThumbnailStrip(images, safeIndex),
                ),

              // 3. NỘI DUNG CHI TIẾT PHÒNG
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
                          Flexible(
                            child: Text(
                              '${formatCurrencyVnd(room.price)} đ/tháng',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (detail?.furniture.trim().isNotEmpty ?? false)
                                  ? '${room.area.toInt()} m² • ${detail!.furniture}'
                                  : room.furniture.trim().isNotEmpty
                                      ? '${room.area.toInt()} m² • ${room.furniture}'
                                      : '${room.area.toInt()} m²',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        room.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.address,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // 4. PHẦN DỮ LIỆU TẢI TỪ FIREBASE `room_detail` (CHỦ TRỌ, TIỆN ÍCH, MÔ TẢ)
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          detail == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError && detail == null)
                        const Center(
                          child: Text(
                            'Không thể tải thông tin chi tiết từ máy chủ.',
                          ),
                        )
                      else if (detail != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phí dịch vụ (Điện / Nước)
                            const Text(
                              'Chi phí dịch vụ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildServiceCostBadge(
                                  Icons.bolt,
                                  'Giá điện',
                                  detail.electricPrice > 0
                                      ? '${detail.electricPrice}k / kWh'
                                      : 'Theo quy định',
                                ),
                                const SizedBox(width: 12),
                                _buildServiceCostBadge(
                                  Icons.water_drop,
                                  'Giá nước',
                                  detail.waterPrice > 0
                                      ? '${detail.waterPrice.toInt()}k / khối'
                                      : 'Theo quy định',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Tiện ích phòng (đã tách bằng dấu phẩy và trim)
                            const Text(
                              'Tiện ích có sẵn',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (detail.amenities.isEmpty)
                              Text(
                                'Chưa cập nhật tiện ích.',
                                style: TextStyle(color: Colors.grey.shade600),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: detail.amenities.map((item) {
                                  return Chip(
                                    avatar: const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    label: Text(
                                      item,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    backgroundColor: Colors.grey.shade100,
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 24),

                            // Mô tả chi tiết
                            const Text(
                              'Mô tả chi tiết',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              detail.description.isNotEmpty
                                  ? detail.description
                                  : 'Chưa có mô tả chi tiết.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // THÔNG TIN CHỦ TRỌ (CARD RIÊNG BIỆT)
                            const Text(
                              'Thông tin chủ trọ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildLandlordCard(detail),
                            const SizedBox(
                              height: 80,
                            ), // Khoảng trống tránh bị che bởi BottomBar
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 5. THANH NÚT BẤM LIÊN HỆ CỐ ĐỊNH Ở ĐÁY MÀN HÌNH (STICKY ACTION BAR)
          bottomNavigationBar: _buildBottomContactBar(detail),
        );
      },
    );
  }

  /// Carousel vuốt ngang trái/phải hiển thị toàn bộ danh sách ảnh của phòng
  /// Hỗ trợ cả cảm ứng (touch) lẫn kéo chuột trên Web/Desktop, kèm nút điều hướng,
  /// chấm tròn chỉ báo trang, bộ đếm `1/N` và chạm để phóng to toàn màn hình.
  Widget _buildImageCarousel(List<String> images, int currentIndex) {
    if (images.isEmpty) {
      return const RoomImageView(source: '', fit: BoxFit.cover);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openFullScreenGallery(images, index),
                child: RoomImageView(
                  source: images[index],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),

        // Nút mũi tên Trái / Phải hỗ trợ thao tác nhanh khi có nhiều hơn 1 ảnh
        if (images.length > 1 && currentIndex > 0)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildCarouselArrowButton(
                icon: Icons.chevron_left,
                tooltip: 'Ảnh trước',
                onTap: () => _goToImage(currentIndex - 1, images.length),
              ),
            ),
          ),
        if (images.length > 1 && currentIndex < images.length - 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildCarouselArrowButton(
                icon: Icons.chevron_right,
                tooltip: 'Ảnh tiếp theo',
                onTap: () => _goToImage(currentIndex + 1, images.length),
              ),
            ),
          ),

        // Dải chấm tròn (Page Indicator) ở cạnh dưới ảnh
        if (images.length > 1)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                final isSelected = index == currentIndex;
                return GestureDetector(
                  onTap: () => _goToImage(index, images.length),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),

        // Badge hiển thị số thứ tự ảnh (VD: 1/5) & nút phóng to ở góc dưới phải
        Positioned(
          right: 12,
          bottom: 12,
          child: GestureDetector(
            onTap: () => _openFullScreenGallery(images, currentIndex),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${currentIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.fullscreen,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 26),
        onPressed: onTap,
      ),
    );
  }

  /// Thanh thumbnail ảnh thu nhỏ bên dưới ảnh chính để người dùng lướt và chọn nhanh
  Widget _buildThumbnailStrip(List<String> images, int currentIndex) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          return GestureDetector(
            onTap: () => _goToImage(index, images.length),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: RoomImageView(
                  source: images[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomContactBar(RoomExtraDetail? detail) {
    final phone = detail?.landlordPhone.isNotEmpty == true
        ? detail!.landlordPhone
        : (widget.room.contact.isNotEmpty
            ? widget.room.contact
            : 'Chưa cập nhật');
    final zalo = detail?.landlordZalo.isNotEmpty == true
        ? detail!.landlordZalo
        : phone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
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
                  side: const BorderSide(
                    color: Colors.blueAccent,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _handleContact(context, 'liên lạc', zalo),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.blueAccent,
                ),
                label: const Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _handleContact(context, 'Điện thoại', phone),
                icon: const Icon(Icons.phone_in_talk),
                label: Text(
                  'Gọi $phone',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordCard(RoomExtraDetail detail) {
    final hasAvatar = detail.landlordAvatar.trim().isNotEmpty;
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
            backgroundImage:
                hasAvatar ? NetworkImage(detail.landlordAvatar) : null,
            onBackgroundImageError: hasAvatar ? (_, __) {} : null,
            child: !hasAvatar ? const Icon(Icons.person, size: 28) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.landlordName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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

/// Màn hình xem ảnh toàn màn hình hỗ trợ vuốt ngang trái/phải và zoom từng ảnh
class _FullScreenRoomGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenRoomGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenRoomGallery> createState() => _FullScreenRoomGalleryState();
}

class _FullScreenRoomGalleryState extends State<_FullScreenRoomGallery> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    if (index < 0 || index >= widget.images.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Ảnh ${_currentIndex + 1}/${widget.images.length}'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: RoomImageView(
                      source: widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.images.length > 1 && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => _jumpTo(_currentIndex - 1),
                ),
              ),
            ),
          if (widget.images.length > 1 &&
              _currentIndex < widget.images.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                  ),
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => _jumpTo(_currentIndex + 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}