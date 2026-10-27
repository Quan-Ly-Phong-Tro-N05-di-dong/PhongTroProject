// lib/features/home_catalog/presentation/screens/counter_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'room_detail_screen.dart';
import '../auth/widgets/role_guard.dart';

abstract class BaseModel<T> {
  final T id;
  const BaseModel({required this.id});
}

class FilterModel {
  final String region;
  final double minPrice;
  final double maxPrice;
  final double minArea;
  final double maxArea;
  final String furniture; // 'Tất cả', 'Full nội thất', 'Phòng trống'
  final int minRating;    // 0: Tất cả, 1 - 5 sao
  final String? hotSearch;

  const FilterModel({
    this.region = 'Tất cả',
    this.minPrice = 0.5,
    this.maxPrice = 15.0,
    this.minArea = 10.0,
    this.maxArea = 80.0,
    this.furniture = 'Tất cả',
    this.minRating = 0,
    this.hotSearch,
  });

  // Kiểm tra xem bộ lọc có đang ở trạng thái mặc định không
  bool get isDefault =>
      region == 'Tất cả' &&
      minPrice == 0.5 &&
      maxPrice == 15.0 &&
      minArea == 10.0 &&
      maxArea == 80.0 &&
      furniture == 'Tất cả' &&
      minRating == 0 &&
      hotSearch == null;

  FilterModel copyWith({
    String? region,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? furniture,
    int? minRating,
    String? hotSearch,
  }) {
    return FilterModel(
      region: region ?? this.region,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      furniture: furniture ?? this.furniture,
      minRating: minRating ?? this.minRating,
      hotSearch: hotSearch ?? this.hotSearch,
    );
  }
}

class RoomItem extends BaseModel<String>{
  final String title;
  final String region;
  final String address;
  final double price;
  final double area;
  final String imageURL;
  final String furniture; // Cần bổ sung
  final double rating;    // Cần bổ sung
  final List<String> tags; // Cần bổ sung (gác xép, chung cư mini, v.v.)

  const RoomItem({
    required super.id,
    required this.title,
    required this.region,
    required this.address,
    required this.price,
    required this.area,
    required this.imageURL,
    this.furniture = 'Phòng trống',
    this.rating = 5.0,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'region': region,
      'address': address,
      'price': price,
      'area': area,
      'imageURL': imageURL, // Đồng nhất với thuộc tính
      'furniture': furniture,
      'rating': rating,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RoomItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RoomItem(
      id: doc.id,
      title: data['title'] ?? '',
      region: data['region'] ?? '',
      address: data['address'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      area: (data['area'] as num?)?.toDouble() ?? 0.0,
      imageURL: data['imageURL'] ?? '',
      furniture: data['furniture'] ?? 'Phòng trống',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}

class RoomSection {
  final String title;
  final String subtitle; // Thêm mô tả ngắn tạo cảm giác mời gọi mua sắm
  final List<RoomItem> rooms;

  const RoomSection({
    required this.title,
    required this.subtitle,
    required this.rooms,
  });
}

class CounterScreen extends StatefulWidget {
  final String title;

  const CounterScreen({super.key, required this.title});

  @override
  State<CounterScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<CounterScreen> {
  FilterModel _currentFilter = const FilterModel();
  int _selectedFilterIndex = 0;
  String _searchKeyword = '';

  final List<String> _filters = [
    'Tất cả',
    'Gần Phenikaa',
    'Dưới 2 triệu',
    'Studio',
    'Có gác xép'
  ];

  // 1. Dữ liệu Mock đa dạng hóa ID, giá, nội thất để phân loại vào các danh mục
  final List<RoomItem> mockRooms = const [
    RoomItem(
      id: '1',
      title: 'Phòng trọ khép kín full đồ gần ĐH Phenikaa',
      region: 'Hà Đông',
      address: 'Yên Nghĩa, Hà Đông, Hà Nội',
      price: 2.8,
      area: 25,
      furniture: 'Full nội thất',
      rating: 4.8,
      tags: ['Gần Phenikaa', 'Có gác xép'],
      imageURL: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
    ),
    RoomItem(
      id: '2',
      title: 'Chung cư mini cao cấp có thang máy, ban công',
      region: 'Hà Đông',
      address: 'Đồng Mai, Hà Đông, Hà Nội',
      price: 4.2,
      area: 35,
      furniture: 'Full nội thất',
      rating: 4.9,
      tags: ['Studio', 'Chung cư mini'],
      imageURL: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
    ),
    RoomItem(
      id: '3',
      title: 'Phòng đơn giá rẻ cho sinh viên năm nhất',
      region: 'Yên Nghĩa',
      address: 'Yên Nghĩa, Hà Đông, Hà Nội',
      price: 1.6,
      area: 18,
      furniture: 'Phòng trống',
      rating: 4.2,
      tags: ['Gần Phenikaa', 'Dưới 2 triệu'],
      imageURL: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600',
    ),
    RoomItem(
      id: '4',
      title: 'Studio sang trọng full nội thất Dương Nội',
      region: 'Dương Nội',
      address: 'KĐT Dương Nội, Hà Đông, Hà Nội',
      price: 5.0,
      area: 40,
      furniture: 'Full nội thất',
      rating: 5.0,
      tags: ['Studio', 'Gần Phenikaa'],
      imageURL: 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=600',
    ),
    RoomItem(
      id: '5',
      title: 'Phòng trọ có gác xép thoáng mát giá sinh viên',
      region: 'Hà Đông',
      address: 'Phú La, Hà Đông, Hà Nội',
      price: 1.8,
      area: 20,
      furniture: 'Phòng trống',
      rating: 4.5,
      tags: ['Dưới 2 triệu', 'Có gác xép'],
      imageURL: 'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=600',
    ),
    RoomItem(
      id: '6',
      title: 'Phòng trọ có gác xép thoáng mát giá sinh viên',
      region: 'Hà Đông',
      address: 'Phú La, Hà Đông, Hà Nội',
      price: 1.8,
      area: 20,
      furniture: 'Phòng trống',
      rating: 4.5,
      tags: ['Dưới 2 triệu', 'Có gác xép'],
      imageURL: 'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=600',
    ),
  ];

  // Kiểm tra xem người dùng có đang kích hoạt tìm kiếm/bộ lọc không
  bool get _isFiltering =>
      !_currentFilter.isDefault ||
      _selectedFilterIndex != 0 ||
      _searchKeyword.trim().isNotEmpty;

  // 1. Danh sách cho Row đầu tiên: Top tìm kiếm / Đề xuất (Lấy các phòng rating cao)
  List<RoomItem> get _topRecommendedRooms {
    return mockRooms.where((room) => room.rating >= 4.5).toList();
  }

  // 2. Danh sách cho phần bên dưới: Tất cả phòng trọ (Tuần tự mặc định hoặc theo bộ lọc)
  List<RoomItem> get _allFilteredRooms {
    return mockRooms.where((room) {
      // Lọc theo từ khóa thanh tìm kiếm
      if (_searchKeyword.trim().isNotEmpty) {
        final kw = _searchKeyword.toLowerCase();
        final matchTitle = room.title.toLowerCase().contains(kw);
        final matchAddress = room.address.toLowerCase().contains(kw);
        if (!matchTitle && !matchAddress) return false;
      }

      // Lọc theo Chip chọn nhanh
      if (_selectedFilterIndex != 0) {
        final selectedTag = _filters[_selectedFilterIndex];
        if (selectedTag == 'Dưới 2 triệu' && room.price >= 2.0) return false;
        if (selectedTag != 'Dưới 2 triệu' &&
            !room.tags.contains(selectedTag) &&
            !room.title.toLowerCase().contains(selectedTag.toLowerCase())) {
          return false;
        }
      }

      // Lọc theo Modal FilterModel
      if (_currentFilter.region != 'Tất cả' && room.region != _currentFilter.region) {
        return false;
      }
      if (room.price < _currentFilter.minPrice || room.price > _currentFilter.maxPrice) {
        return false;
      }
      if (room.area < _currentFilter.minArea || room.area > _currentFilter.maxArea) {
        return false;
      }
      if (_currentFilter.furniture != 'Tất cả' && room.furniture != _currentFilter.furniture) {
        return false;
      }
      if (room.rating < _currentFilter.minRating) {
        return false;
      }
      if (_currentFilter.hotSearch != null && _currentFilter.hotSearch!.isNotEmpty) {
        final hotKw = _currentFilter.hotSearch!.toLowerCase();
        final matchTitle = room.title.toLowerCase().contains(hotKw);
        final matchAddress = room.address.toLowerCase().contains(hotKw);
        if (!matchTitle && !matchAddress) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allRooms = _allFilteredRooms;
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
            _buildSearchBar(),
            _buildFilterList(),
            if (!_isFiltering) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '🔥 Top tìm kiếm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildHorizontalTopList(_topRecommendedRooms),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isFiltering
                        ? 'Kết quả tìm kiếm (${allRooms.length} phòng)'
                        : 'Trọ nổi bật',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isFiltering)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentFilter = const FilterModel();
                          _selectedFilterIndex = 0;
                          _searchKeyword = '';
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Xóa bộ lọc'),
                    ),
                ],
              ),
            ),
            _buildVerticalAllRoomsList(allRooms),

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
                  hintText: 'Từ khóa tìm kiếm',
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
              onPressed: () async {
                // Mở modal bộ lọc chi tiết
                final FilterModel? result = await _openFilterModal(context, _currentFilter);
    
                // Nếu bấm "Áp dụng", result khác null -> áp dụng lọc
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

  // Component: Danh mục lọc ngang
  Widget _buildFilterList() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        // ignore: unnecessary_underscores
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

  void _applyFilter(FilterModel filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

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
      physics: const NeverScrollableScrollPhysics(), // Để cuộn chung với SingleChildScrollView cha
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rooms.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260, // Tự động chia 2 cột trên điện thoại, 4-5 cột trên Web
        mainAxisExtent: 250,     // Chiều cao cố định mỗi thẻ giúp không bao giờ bị lỗi tràn (Overflow)
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        return _buildRoomCard(rooms[index], imageHeight: 130);
      },
    );
  }

  Widget _buildRoomCard(RoomItem room, {required double imageHeight}) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async{
          if(!await requireLogin(context))return; // Kiểm tra quyền truy cập trước khi điều hướng
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
          Image.network(
            room.imageURL,
            height: imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: imageHeight,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${room.price.toStringAsFixed(1)} triệu/th',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    Text(
                      '${room.area.toInt()} m²',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        room.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      )
    );
  }

  Future<FilterModel?> _openFilterModal(
    BuildContext context,
    FilterModel initialFilter,) {
    RangeValues priceRange = RangeValues(initialFilter.minPrice, initialFilter.maxPrice);
    RangeValues areaRange = RangeValues(initialFilter.minArea, initialFilter.maxArea);
    String selectedArea = initialFilter.region;
    String furnitureOption = initialFilter.furniture;
    int selectedRating = initialFilter.minRating;
    String? selectedHotSearch = initialFilter.hotSearch;

    final List<String> areas = [
      'Tất cả',
      'Hà Đông',
      'Yên Nghĩa',
      'Dương Nội',
      'Thanh Xuân',
      'Cầu Giấy',
    ];
    final List<String> hotSearches = [
      'Gần Phenikaa',
      'Dưới 2 triệu',
      'Có gác xép',
      'Không chung chủ',
      'Chung cư mini',
    ];

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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              priceRange = const RangeValues(0.5, 15.0);
                              areaRange = const RangeValues(10.0, 80.0);
                              selectedArea = 'Tất cả';
                              furnitureOption = 'Tất cả';
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
                        const Text('Tìm kiếm phổ biến', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: hotSearches.map((tag) {
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
                        const Text('Khu vực', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedArea,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: areas.map((area) {
                            return DropdownMenuItem(value: area, child: Text(area));
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
                            const Text('Khoảng giá', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${priceRange.start.toStringAsFixed(1)} - ${priceRange.end.toStringAsFixed(1)} tr/tháng',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: priceRange,
                          min: 0.5,
                          max: 15.0,
                          divisions: 29,
                          labels: RangeLabels(
                            '${priceRange.start.toStringAsFixed(1)} tr',
                            '${priceRange.end.toStringAsFixed(1)} tr',
                          ),
                          onChanged: (values) {
                            setModalState(() => priceRange = values);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Diện tích', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${areaRange.start.round()} - ${areaRange.end.round()} m²',
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: areaRange,
                          min: 10.0,
                          max: 80.0,
                          divisions: 14,
                          labels: RangeLabels(
                            '${areaRange.start.round()} m²',
                            '${areaRange.end.round()} m²',
                          ),
                          onChanged: (values) {
                            setModalState(() => areaRange = values);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Nội thất', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Tất cả', label: Text('Tất cả')),
                            ButtonSegment(value: 'Full nội thất', label: Text('Full đồ')),
                            ButtonSegment(value: 'Phòng trống', label: Text('Phòng trống')),
                          ],
                          selected: {furnitureOption},
                          onSelectionChanged: (newSelection) {
                            setModalState(() => furnitureOption = newSelection.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text('Đánh giá tối thiểu', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            return IconButton(
                              icon: Icon(
                                star <= selectedRating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  selectedRating = (selectedRating == star) ? 0 : star;
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
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2)),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          // Đóng gói thành instance FilterModel trả về
                          final resultFilter = FilterModel(
                            region: selectedArea,
                            minPrice: priceRange.start,
                            maxPrice: priceRange.end,
                            minArea: areaRange.start,
                            maxArea: areaRange.end,
                            furniture: furnitureOption,
                            minRating: selectedRating,
                            hotSearch: selectedHotSearch,
                          );
                          Navigator.pop(context, resultFilter);
                        },
                        child: const Text('Áp dụng bộ lọc', style: TextStyle(fontSize: 16)),
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