// lib/features/home_catalog/presentation/screens/counter_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/room_item.dart';
import '../auth/widgets/role_guard.dart';
import 'room_detail_screen.dart';

class FilterModel {
  static const String allOption = 'Tất cả';
  static const double defaultMinPrice = 500000; // 500.000 VNĐ
  static const double defaultMaxPrice = 15000000; // 15.000.000 VNĐ
  static const double defaultMinArea = 10.0;
  static const double defaultMaxArea = 80.0;

  final String region;
  final double minPrice; // Đơn vị: VNĐ
  final double maxPrice; // Đơn vị: VNĐ
  final double minArea;
  final double maxArea;
  final String furniture;
  final Set<String> selectedAmenities; // Các key tiện ích lấy động từ bài đăng
  final int minRating; // 0: Tất cả, 1 - 5 sao
  final String? hotSearch;

  const FilterModel({
    this.region = allOption,
    this.minPrice = defaultMinPrice,
    this.maxPrice = defaultMaxPrice,
    this.minArea = defaultMinArea,
    this.maxArea = defaultMaxArea,
    this.furniture = allOption,
    this.selectedAmenities = const {},
    this.minRating = 0,
    this.hotSearch,
  });

  // Kiểm tra xem bộ lọc có đang ở trạng thái mặc định không
  bool get isDefault =>
      region == allOption &&
      minPrice == defaultMinPrice &&
      maxPrice == defaultMaxPrice &&
      minArea == defaultMinArea &&
      maxArea == defaultMaxArea &&
      furniture == allOption &&
      selectedAmenities.isEmpty &&
      minRating == 0 &&
      hotSearch == null;

  FilterModel copyWith({
    String? region,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? furniture,
    Set<String>? selectedAmenities,
    int? minRating,
    String? hotSearch,
    bool clearHotSearch = false,
  }) {
    return FilterModel(
      region: region ?? this.region,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      furniture: furniture ?? this.furniture,
      selectedAmenities: selectedAmenities ?? this.selectedAmenities,
      minRating: minRating ?? this.minRating,
      hotSearch: clearHotSearch ? null : (hotSearch ?? this.hotSearch),
    );
  }
}

class CounterScreen extends StatefulWidget {
  final String title;

  const CounterScreen({super.key, required this.title});

  @override
  State<CounterScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<CounterScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RoomDetailFirebaseService _detailService =
      RoomDetailFirebaseService.instance;

  // Quản lý tìm kiếm từ khóa và Debounce
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchKeyword = '';

  // Quản lý bộ lọc Modal & Chip nhanh (dùng chuỗi tag thay vì index cố định)
  FilterModel _currentFilter = const FilterModel();
  String _selectedQuickFilter = FilterModel.allOption;

  // Các Stream lắng nghe từ Firestore:
  // 1. `posts` (bài đã duyệt & còn phòng)
  // 2. `room_detail` (chi tiết phòng: amenities, region, furniture, tags...)
  // 3. `search_tags` (các tag phục vụ đề mục "Top tìm kiếm" & bộ lọc nhanh)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _detailsSub;
  StreamSubscription<List<String>>? _tagsSub;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _postDocs = const [];
  Map<String, Map<String, dynamic>> _detailMapByPostId = const {};
  List<String> _firebaseSearchTags = const [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _subscribeFirestoreStreams();
  }

  void _subscribeFirestoreStreams() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _postsSub?.cancel();
    _detailsSub?.cancel();
    _tagsSub?.cancel();

    // 1. Lắng nghe collection `search_tags` trên Firebase phục vụ Top tìm kiếm & Chip lọc nhanh
    _tagsSub = _detailService.watchSearchTags().listen(
      (tags) {
        if (!mounted) return;
        setState(() {
          _firebaseSearchTags = tags;
        });
      },
      onError: (_) {},
    );

    // 2. Lắng nghe collection `room_detail` để lấy RoomExtraDetail phục vụ bộ lọc
    _detailsSub = _detailService.roomDetailsRef.snapshots().listen(
      (snapshot) {
        final map = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final postId = (data['postId'] ?? doc.id).toString();
          map[postId] = data;
          map[doc.id] = data;
        }
        if (!mounted) return;
        setState(() {
          _detailMapByPostId = map;
        });
      },
      onError: (_) {},
    );

    // 3. Lắng nghe các bài đăng đã được phê duyệt (`approved`) và không bị ẩn (`isHidden == false`)
    _postsSub = _db
        .collection('posts')
        .where('reviewStatus', isEqualTo: 'approved')
        .where('isHidden', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _postDocs = snapshot.docs;
          _isLoading = false;
          _errorMessage = null;
        });
        // Tự động đồng bộ ngầm bản ghi `room_detail` cho những bài mới được duyệt mà chưa có `room_detail`
        _syncMissingRoomDetails(snapshot.docs);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải danh sách phòng trọ: $error';
        });
      },
    );
  }

  /// Nếu bài đăng trên `posts` chưa có document tương ứng trong `room_detail`,
  /// tự động khởi tạo từ dữ liệu bài đăng (tách tiện ích theo dấu phẩy) để liên kết 2 bảng.
  Future<void> _syncMissingRoomDetails(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    for (final doc in docs) {
      if (_detailMapByPostId.containsKey(doc.id)) continue;
      final postData = doc.data();
      final detail = RoomExtraDetail.fromMap(
        const <String, dynamic>{},
        postId: doc.id,
        postData: postData,
      );
      try {
        await _detailService.saveRoomExtraDetail(
          postId: doc.id,
          detail: detail,
        );
      } catch (_) {
        // Bỏ qua nếu người dùng hiện tại không có quyền ghi trên Firestore
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _postsSub?.cancel();
    _detailsSub?.cancel();
    _tagsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Ghép nối dữ liệu từ `posts` và `room_detail` thành danh sách `RoomItem`
  /// Chỉ hiển thị các phòng có trạng thái `availability == 'available'`
  List<RoomItem> get _approvedAvailableRooms {
    final rooms = <RoomItem>[];
    for (final doc in _postDocs) {
      final data = doc.data();
      final availability = (data['availability'] ?? 'available').toString();
      if (availability != 'available') continue;

      final detailMap = _detailMapByPostId[doc.id];
      rooms.add(
        RoomItem.fromPostAndDetail(
          postDoc: doc,
          detailMap: detailMap,
        ),
      );
    }

    rooms.sort((a, b) {
      final timeA = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final timeB = b.createdAt?.millisecondsSinceEpoch ?? 0;
      final cmp = timeB.compareTo(timeA);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });
    return rooms;
  }

  /// Danh sách các tag hiển thị ở thanh chọn nhanh và mục "Tìm kiếm phổ biến":
  /// Lấy từ collection `search_tags` trên Firebase kết hợp với các `tags` & `amenities` thực tế của phòng
  List<String> get _dynamicQuickTags {
    final tags = <String>{..._firebaseSearchTags};
    for (final room in _approvedAvailableRooms) {
      tags.addAll(room.tags);
    }
    // Nếu chưa có tag nào trong `search_tags` hoặc `room.tags`, lấy các key tiện ích đã tách dấu phẩy
    if (tags.isEmpty) {
      for (final room in _approvedAvailableRooms) {
        tags.addAll(room.amenities);
      }
    }
    return tags.toList();
  }

  /// Danh sách Chip hiển thị trên thanh ngang màn hình chính (luôn có 'Tất cả' ở đầu)
  List<String> get _quickFilterChips => [
        FilterModel.allOption,
        ..._dynamicQuickTags,
      ];

  /// Danh sách Khu vực (Region) lấy động từ dữ liệu phòng thực tế trên toàn thành phố/vùng miền
  List<String> get _dynamicRegions {
    final regions = <String>{};
    for (final room in _approvedAvailableRooms) {
      if (room.region.trim().isNotEmpty) {
        regions.add(room.region.trim());
      }
      // Lấy thêm cấp Tỉnh/Thành phố hoặc Quận/Huyện ở cuối địa chỉ (nếu có)
      final segments = room.addressSegments;
      if (segments.length >= 2) {
        regions.add(segments.last);
        regions.add(segments[segments.length - 2]);
      }
    }
    final sorted = regions.toList()..sort();
    return [FilterModel.allOption, ...sorted];
  }

  /// Danh sách tất cả các key tiện ích (`amenities`) được tách bằng dấu phẩy từ các bài đăng
  List<String> get _dynamicAmenityKeys {
    final keys = <String>{};
    for (final room in _approvedAvailableRooms) {
      keys.addAll(room.amenities);
    }
    final sorted = keys.toList()..sort();
    return sorted;
  }

  /// Danh sách các tùy chọn tình trạng nội thất (`furniture`) lấy động từ `RoomExtraDetail`
  List<String> get _dynamicFurnitureOptions {
    final options = <String>{};
    for (final room in _approvedAvailableRooms) {
      if (room.furniture.trim().isNotEmpty) {
        options.add(room.furniture.trim());
      }
    }
    return [FilterModel.allOption, ...options];
  }

  // Kiểm tra xem người dùng có đang kích hoạt bất kỳ bộ lọc/tìm kiếm nào không
  bool get _isFiltering =>
      !_currentFilter.isDefault ||
      _selectedQuickFilter != FilterModel.allOption ||
      _searchKeyword.trim().isNotEmpty;

  /// Kiểm tra 1 phòng có khớp với 1 tag tìm kiếm (từ Firebase `search_tags` hoặc `room.tags`) hay không
  bool _roomMatchesTag(RoomItem room, String tag) {
    final normTag = removeVietnameseDiacritics(tag.trim());
    if (normTag.isEmpty) return true;

    final inTags = room.tags.any(
      (t) => removeVietnameseDiacritics(t).contains(normTag),
    );
    final inAmenities = room.amenities.any(
      (am) => removeVietnameseDiacritics(am).contains(normTag),
    );
    final inTitle = removeVietnameseDiacritics(room.title).contains(normTag);
    final inAddress =
        removeVietnameseDiacritics(room.address).contains(normTag);
    final inDesc = removeVietnameseDiacritics(
      room.extraDetail?.description ?? '',
    ).contains(normTag);

    return inTags || inAmenities || inTitle || inAddress || inDesc;
  }

  // 1. Danh sách cho Row đầu tiên: Top tìm kiếm / Đề xuất
  // Phục vụ các phòng khớp với collection `search_tags` trên Firebase hoặc có rating cao
  List<RoomItem> get _topRecommendedRooms {
    final rooms = _approvedAvailableRooms;
    if (_firebaseSearchTags.isNotEmpty) {
      final matched = rooms
          .where(
            (room) =>
                _firebaseSearchTags.any((tag) => _roomMatchesTag(room, tag)) ||
                room.rating >= 4.5,
          )
          .toList();
      if (matched.isNotEmpty) return matched;
    }
    return rooms.where((room) => room.rating >= 4.5).toList();
  }

  // 2. Danh sách cho phần bên dưới: Lọc dựa trên cả RoomItem lẫn RoomExtraDetail
  List<RoomItem> get _allFilteredRooms {
    return _approvedAvailableRooms.where((room) {
      final extra = room.extraDetail;
      final extraDescription = extra?.description ?? '';
      final extraAmenities = room.amenities;

      // Lọc theo từ khóa thanh tìm kiếm (Hỗ trợ không dấu, tìm trong cả RoomExtraDetail)
      if (_searchKeyword.trim().isNotEmpty) {
        final normalizedQuery =
            removeVietnameseDiacritics(_searchKeyword.trim());
        final matchTitle =
            removeVietnameseDiacritics(room.title).contains(normalizedQuery);
        final matchAddress =
            removeVietnameseDiacritics(room.address).contains(normalizedQuery);
        final matchRegion =
            removeVietnameseDiacritics(room.region).contains(normalizedQuery);
        final matchTags = room.tags.any(
          (tag) => removeVietnameseDiacritics(tag).contains(normalizedQuery),
        );
        final matchAmenities = extraAmenities.any(
          (am) => removeVietnameseDiacritics(am).contains(normalizedQuery),
        );
        final matchDescription = removeVietnameseDiacritics(extraDescription)
            .contains(normalizedQuery);

        if (!matchTitle &&
            !matchAddress &&
            !matchRegion &&
            !matchTags &&
            !matchAmenities &&
            !matchDescription) {
          return false;
        }
      }

      // Lọc theo Chip chọn nhanh trên màn hình chính (Lấy từ Firebase `search_tags` / `room.tags`)
      if (_selectedQuickFilter != FilterModel.allOption) {
        if (!_roomMatchesTag(room, _selectedQuickFilter)) {
          return false;
        }
      }

      // Lọc theo Khu vực (động toàn thành phố/vùng)
      if (_currentFilter.region != FilterModel.allOption) {
        final normSelectedRegion =
            removeVietnameseDiacritics(_currentFilter.region);
        final matchRoomRegion =
            removeVietnameseDiacritics(room.region).contains(normSelectedRegion);
        final matchAddressSegment = room.addressSegments.any(
          (seg) => removeVietnameseDiacritics(seg).contains(normSelectedRegion),
        );
        if (!matchRoomRegion && !matchAddressSegment) {
          return false;
        }
      }

      // Lọc theo khoảng giá VNĐ
      if (room.price < _currentFilter.minPrice) {
        return false;
      }
      if (_currentFilter.maxPrice < FilterModel.defaultMaxPrice &&
          room.price > _currentFilter.maxPrice) {
        return false;
      }

      // Lọc theo diện tích
      if (room.area < _currentFilter.minArea) {
        return false;
      }
      if (_currentFilter.maxArea < FilterModel.defaultMaxArea &&
          room.area > _currentFilter.maxArea) {
        return false;
      }

      // Lọc theo tình trạng nội thất (nếu được chọn)
      if (_currentFilter.furniture != FilterModel.allOption &&
          removeVietnameseDiacritics(room.furniture) !=
              removeVietnameseDiacritics(_currentFilter.furniture)) {
        return false;
      }

      // Lọc theo các key tiện ích (`amenities` tách bằng dấu phẩy từ bài đăng)
      if (_currentFilter.selectedAmenities.isNotEmpty) {
        final normalizedRoomAmenities =
            extraAmenities.map(removeVietnameseDiacritics).toList();
        for (final reqAmenity in _currentFilter.selectedAmenities) {
          final normReq = removeVietnameseDiacritics(reqAmenity);
          final hasAmenity = normalizedRoomAmenities.any(
            (am) => am.contains(normReq) || normReq.contains(am),
          );
          if (!hasAmenity) return false;
        }
      }

      // Lọc theo đánh giá tối thiểu
      if (room.rating < _currentFilter.minRating) {
        return false;
      }

      // Lọc theo Tag tìm kiếm phổ biến trong Modal
      if (_currentFilter.hotSearch != null &&
          _currentFilter.hotSearch!.isNotEmpty) {
        if (!_roomMatchesTag(room, _currentFilter.hotSearch!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _resetAllFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _currentFilter = const FilterModel();
      _selectedQuickFilter = FilterModel.allOption;
      _searchKeyword = '';
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final allRooms = _allFilteredRooms;
    final topRooms = _topRecommendedRooms;

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
            tooltip: 'Tải lại dữ liệu',
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _subscribeFirestoreStreams,
          ),
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
            // 1. THANH TÌM KIẾM & NÚT MỞ MODAL BỘ LỌC
            _buildSearchBar(),

            // 2. DANH MỤC CHỌN NHANH (CHIPS LẤY ĐỘNG TỪ FIREBASE `search_tags` & DỮ LIỆU PHÒNG)
            _buildFilterList(),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            else ...[
              // 3. HÀNG NGANG ĐẦU TIÊN: TOP TÌM KIẾM (Ẩn khi đang lọc hoặc khi danh sách trống)
              if (!_isFiltering && topRooms.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '🔥 Top tìm kiếm & Đề xuất',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildHorizontalTopList(topRooms),
              ],

              // 4. DANH SÁCH TẤT CẢ CÁC TRỌ TRẢI DỌC XUỐNG DƯỚI
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isFiltering
                          ? 'Kết quả tìm kiếm (${allRooms.length} phòng)'
                          : 'Danh sách phòng trọ (${allRooms.length} phòng)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isFiltering)
                      TextButton.icon(
                        onPressed: _resetAllFilters,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Xóa bộ lọc'),
                      ),
                  ],
                ),
              ),
              _buildVerticalAllRoomsList(allRooms),
            ],

            const SizedBox(height: 24),

            // 5. FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Component: Thanh tìm kiếm tích hợp tìm theo từ khóa & mở Modal bộ lọc
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
                border: Border.all(
                  color: _searchKeyword.isNotEmpty
                      ? Colors.blueAccent
                      : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () {
                    setState(() {
                      _searchKeyword = value.trim();
                    });
                  });
                },
                onSubmitted: (value) {
                  _debounce?.cancel();
                  setState(() => _searchKeyword = value.trim());
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  hintText: 'Tìm theo tên phòng, đường, khu vực, tiện ích...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              // Đổi sang màu cam khi đang có bộ lọc nâng cao được kích hoạt
              color: _currentFilter.isDefault
                  ? Colors.blueAccent
                  : Colors.orangeAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final FilterModel? result = await _openFilterModal(
                  context,
                  _currentFilter,
                );
                if (result != null) {
                  _applyFilter(result);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Component: Danh mục lọc ngang lấy động từ `_quickFilterChips`
  Widget _buildFilterList() {
    final chips = _quickFilterChips;
    if (chips.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        // ignore: unnecessary_underscores
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = chips[index];
          final isSelected = _selectedQuickFilter == label;
          return ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            selectedColor: Colors.blueAccent,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
            ),
            onSelected: (_) {
              setState(() => _selectedQuickFilter = label);
            },
          );
        },
      ),
    );
  }

  void _applyFilter(FilterModel filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  // Component: Hàng ngang cho Top tìm kiếm
  Widget _buildHorizontalTopList(List<RoomItem> rooms) {
    return SizedBox(
      height: 245,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return Container(
            width: 210,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            child: _buildRoomCard(room, imageHeight: 125),
          );
        },
      ),
    );
  }

  // Component: Danh sách tất cả phòng trọ bên dưới (Dạng Grid tự co giãn)
  Widget _buildVerticalAllRoomsList(List<RoomItem> rooms) {
    if (rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'Không tìm thấy phòng trọ nào khớp với yêu cầu.',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rooms.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 250,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        return _buildRoomCard(rooms[index], imageHeight: 130);
      },
    );
  }

  // Component: Card hiển thị từng phòng trọ (Hỗ trợ cả ảnh Base64 và HTTPS, giá VNĐ có dấu chấm)
  Widget _buildRoomCard(RoomItem room, {required double imageHeight}) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (!await requireLogin(context)) return;
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoomDetailScreen(room: room),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoomImageView(
              source: room.imageURL,
              height: imageHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${formatCurrencyVnd(room.price)} đ/th',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.area.toInt()} m²',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          room.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modal bộ lọc chi tiết: Toàn bộ danh sách Khu vực, Tags, Tiện ích, Nội thất được lấy động
  Future<FilterModel?> _openFilterModal(
    BuildContext context,
    FilterModel initialFilter,
  ) {
    final List<String> availableRegions = _dynamicRegions;
    final List<String> availableHotTags = _dynamicQuickTags;
    final List<String> availableAmenityKeys = _dynamicAmenityKeys;
    final List<String> availableFurnitureOptions = _dynamicFurnitureOptions;

    RangeValues priceRange = RangeValues(
      initialFilter.minPrice.clamp(
        FilterModel.defaultMinPrice,
        FilterModel.defaultMaxPrice,
      ),
      initialFilter.maxPrice.clamp(
        FilterModel.defaultMinPrice,
        FilterModel.defaultMaxPrice,
      ),
    );
    RangeValues areaRange = RangeValues(
      initialFilter.minArea,
      initialFilter.maxArea,
    );
    String selectedArea = availableRegions.contains(initialFilter.region)
        ? initialFilter.region
        : FilterModel.allOption;
    String furnitureOption =
        availableFurnitureOptions.contains(initialFilter.furniture)
            ? initialFilter.furniture
            : FilterModel.allOption;
    Set<String> selectedAmenities =
        Set<String>.from(initialFilter.selectedAmenities);
    int selectedRating = initialFilter.minRating;
    String? selectedHotSearch = initialFilter.hotSearch;

    return showModalBottomSheet<FilterModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bộ lọc tìm kiếm',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              priceRange = const RangeValues(
                                FilterModel.defaultMinPrice,
                                FilterModel.defaultMaxPrice,
                              );
                              areaRange = const RangeValues(
                                FilterModel.defaultMinArea,
                                FilterModel.defaultMaxArea,
                              );
                              selectedArea = FilterModel.allOption;
                              furnitureOption = FilterModel.allOption;
                              selectedAmenities.clear();
                              selectedRating = 0;
                              selectedHotSearch = null;
                            });
                          },
                          child: const Text('Thiết lập lại'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (availableHotTags.isNotEmpty) ...[
                          const Text(
                            'Tìm kiếm phổ biến',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableHotTags.map((tag) {
                              final isSelected = selectedHotSearch == tag;
                              return ChoiceChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    selectedHotSearch = selected ? tag : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Khu vực',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedArea,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: availableRegions.map((area) {
                            return DropdownMenuItem(
                              value: area,
                              child: Text(area),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedArea = value);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Khoảng giá (VNĐ/tháng)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Flexible(
                              child: Text(
                                '${formatCurrencyVnd(priceRange.start)} - ${formatCurrencyVnd(priceRange.end)} đ',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: priceRange,
                          min: FilterModel.defaultMinPrice,
                          max: FilterModel.defaultMaxPrice,
                          divisions: 29,
                          labels: RangeLabels(
                            '${formatCurrencyVnd(priceRange.start)} đ',
                            '${formatCurrencyVnd(priceRange.end)} đ',
                          ),
                          onChanged: (values) {
                            setModalState(() => priceRange = values);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Diện tích',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${areaRange.start.round()} - ${areaRange.end.round()} m²',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: areaRange,
                          min: FilterModel.defaultMinArea,
                          max: FilterModel.defaultMaxArea,
                          divisions: 14,
                          labels: RangeLabels(
                            '${areaRange.start.round()} m²',
                            '${areaRange.end.round()} m²',
                          ),
                          onChanged: (values) {
                            setModalState(() => areaRange = values);
                          },
                        ),
                        if (availableAmenityKeys.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Tiện ích phòng (từ chi tiết phòng)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableAmenityKeys.map((amenityKey) {
                              final isChecked =
                                  selectedAmenities.contains(amenityKey);
                              return FilterChip(
                                label: Text(amenityKey),
                                selected: isChecked,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      selectedAmenities.add(amenityKey);
                                    } else {
                                      selectedAmenities.remove(amenityKey);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        if (availableFurnitureOptions.length > 1) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Nội thất',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableFurnitureOptions.map((option) {
                              final isSelected = furnitureOption == option;
                              return ChoiceChip(
                                label: Text(option),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(
                                      () => furnitureOption = option,
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Đánh giá tối thiểu',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            return IconButton(
                              icon: Icon(
                                star <= selectedRating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  selectedRating =
                                      (selectedRating == star) ? 0 : star;
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final resultFilter = FilterModel(
                            region: selectedArea,
                            minPrice: priceRange.start,
                            maxPrice: priceRange.end,
                            minArea: areaRange.start,
                            maxArea: areaRange.end,
                            furniture: furnitureOption,
                            selectedAmenities: selectedAmenities,
                            minRating: selectedRating,
                            hotSearch: selectedHotSearch,
                          );
                          Navigator.pop(context, resultFilter);
                        },
                        child: const Text(
                          'Áp dụng bộ lọc',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
            'Khoa Công nghệ thông tin - Lập trình di động',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Divider(color: Colors.white24, height: 24),
          const Text(
            'Nhóm sinh viên thực hiện:',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lê Thị Phương Anh - MSSV: 24100263\n'
            'Nguyễn Quang Huy - MSSV: 24100245\n'
            'Lê Hải Anh - MSSV: 24100110\n'
            'Hoàng Việt Anh - MSSV: 23010117',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}