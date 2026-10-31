// lib/features/home_catalog/presentation/screens/room_detail_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../contact/models/contact_models.dart';
import '../contact/services/interaction_service.dart';
import '../contact/widgets/interaction_ui.dart';
import '../contact/widgets/rating_stars.dart';
import '../contact/widgets/review_form.dart';
import '../contact/widgets/room_actions.dart';
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
  String? _selectedAppointmentIdForReview;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Đảm bảo phòng hiện tại được đăng ký trong InteractionService để Chat / Đặt lịch hoạt động ngay
    _syncRoomWithInteractionService(widget.room.ownerId);
    // Kích hoạt truy vấn Firebase lấy thông tin chi tiết & chủ trọ theo ID bài đăng (postId)
    _detailFuture = RoomDetailFirebaseService.instance
        .fetchAndSyncRoomDetail(widget.room)
        .then((detail) {
      _syncRoomWithInteractionService(
        detail.ownerId.isNotEmpty ? detail.ownerId : widget.room.ownerId,
      );
      return detail;
    });
  }

  /// Đồng bộ phòng sang `InteractionService` nếu phòng chưa có trong danh sách của module `contact/`
  void _syncRoomWithInteractionService(String rawOwnerId) {
    final service = InteractionService.instance;
    final resolvedOwnerId = rawOwnerId.trim().isNotEmpty
        ? rawOwnerId.trim()
        : (service.ownerOf(widget.room.id) ?? '');
    if (resolvedOwnerId.isEmpty) return;

    if (service.ownerOf(widget.room.id) == null ||
        service.rooms[widget.room.id] == null) {
      // Module contact/ lưu giá theo đơn vị triệu VNĐ (fmtVnd nhân 1.000.000)
      final normalizedPrice = widget.room.price >= 100000
          ? widget.room.price / 1000000
          : widget.room.price;
      service.registerRoom(
        RoomItem(
          id: widget.room.id,
          ownerId: resolvedOwnerId,
          title: widget.room.title,
          region: widget.room.region,
          address: widget.room.address,
          price: normalizedPrice,
          area: widget.room.area,
          imageUrl: widget.room.imageURL,
          imageUrls: widget.room.allImages,
          furniture: widget.room.furniture,
          rating: widget.room.rating,
          tags: widget.room.tags,
          availability: widget.room.availability,
          reviewStatus: widget.room.reviewStatus,
          isHidden: widget.room.isHidden,
          contact: widget.room.contact,
          extraDetail: widget.room.extraDetail,
          createdAt: widget.room.createdAt,
        ),
        ownerId: resolvedOwnerId,
      );
    }
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
                      const SizedBox(height: 10),

                      // Hiển thị tóm tắt điểm đánh giá sao từ InteractionService
                      _buildRatingSummaryRow(room.id),

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
                          ],
                        ),

                      const Divider(height: 36),

                      // 5. KHỐI ĐÁNH GIÁ PHÒNG & FORM THÊM ĐÁNH GIÁ (NỐI VỚI MODULE CONTACT/)
                      _buildReviewSection(room.id),

                      const SizedBox(height: 12),

                      // Nút báo cáo tin đăng từ contact/widgets/room_actions.dart
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ReportButton(roomId: room.id),
                      ),

                      const SizedBox(
                        height: 80,
                      ), // Khoảng trống tránh bị che bởi BottomBar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 6. THANH 2 NÚT LIÊN HỆ (CHAT) + ĐẶT LỊCH Ở ĐÁY MÀN HÌNH (TỪ MODULE CONTACT/)
          bottomNavigationBar: RoomActionBar(roomId: room.id),
        );
      },
    );
  }

  /// Hàng hiển thị nhanh tóm tắt số sao đánh giá (`ratingSummary`) ngay dưới địa chỉ phòng
  Widget _buildRatingSummaryRow(String roomId) {
    final service = InteractionService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final summary = service.ratingSummary(roomId);
        return Row(
          children: [
            RatingStars(rating: summary.average, size: 18),
            const SizedBox(width: 6),
            Text(
              summary.count == 0
                  ? 'Chưa có đánh giá'
                  : '${summary.average.toStringAsFixed(1)} (${summary.count} đánh giá)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: IStyle.muted,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Khối hiển thị danh sách đánh giá (`ReviewList`) kèm form thêm đánh giá (`ReviewForm`)
  /// tuân thủ đúng luật nghiệp vụ của `contact/`: chỉ người thuê có lịch hẹn `completed`
  /// chưa đánh giá tại phòng này mới hiển thị form gửi đánh giá.
  Widget _buildReviewSection(String roomId) {
    final service = InteractionService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final eligibleAppointments = service.role == UserRole.tenant
            ? service
                .appointmentsForCurrentUser()
                .where(
                  (a) =>
                      a.roomId == roomId &&
                      a.status == AppointmentStatus.completed &&
                      service.reviewForAppointment(a.id) == null,
                )
                .toList()
            : <Appointment>[];

        final hasCompletedAppointmentsForRoom =
            service.role == UserRole.tenant &&
                service.appointmentsForCurrentUser().any(
                      (a) =>
                          a.roomId == roomId &&
                          a.status == AppointmentStatus.completed,
                    );

        Appointment? selectedAppointment;
        if (eligibleAppointments.isNotEmpty) {
          selectedAppointment = eligibleAppointments.firstWhere(
            (a) => a.id == _selectedAppointmentIdForReview,
            orElse: () => eligibleAppointments.first,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Danh sách đánh giá + điểm trung bình từ contact/widgets/review_list.dart
            ReviewList(roomId: roomId),
            const SizedBox(height: 16),

            // Form thêm đánh giá nếu người thuê có lịch hẹn xem phòng đã hoàn thành & chưa đánh giá
            if (selectedAppointment != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Viết đánh giá của bạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (eligibleAppointments.length == 1)
                      Text(
                        'Lịch hẹn đã hoàn thành: ${fmtDateTime(selectedAppointment.appointmentTime)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IStyle.muted,
                        ),
                      )
                    else ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedAppointment.id,
                        decoration: InputDecoration(
                          labelText: 'Chọn lịch hẹn đã hoàn thành',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: eligibleAppointments.map((appt) {
                          return DropdownMenuItem<String>(
                            value: appt.id,
                            child: Text(
                              'Lịch hẹn ${fmtDateTime(appt.appointmentTime)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAppointmentIdForReview = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ReviewForm(
                      key: ValueKey('review_form_${selectedAppointment.id}'),
                      appointmentId: selectedAppointment.id,
                      onSubmitted: () {
                        if (mounted) {
                          setState(() {
                            _selectedAppointmentIdForReview = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              )
            else if (service.role == UserRole.tenant)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: IStyle.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: IStyle.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasCompletedAppointmentsForRoom
                            ? 'Bạn đã đánh giá tất cả lịch hẹn hoàn thành của phòng này.'
                            : 'Đặt lịch và hoàn thành xem phòng để viết đánh giá cho phòng trọ này.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: IStyle.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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