// lib/features/home_catalog/models/room_item.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/base/base_entity.dart';
import '../../../core/base/entity_registry.dart';
import '../../contact/models/review.dart';
import '../../contact/services/interaction_service.dart';

const String kPostImagePrefix = 'data:image/jpeg;base64,';

/// Định dạng giá tiền VNĐ có dấu chấm ngăn cách hàng nghìn.
/// Giữ nguyên chính xác giá trị VNĐ từ bài đăng.
String formatCurrencyVnd(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
}

/// Bỏ dấu tiếng Việt để phục vụ tìm kiếm & so khớp bộ lọc không dấu
String removeVietnameseDiacritics(String str) {
  var result = str.toLowerCase();
  const withDia =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const withoutDia =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  for (int i = 0; i < withDia.length; i++) {
    result = result.replaceAll(withDia[i], withoutDia[i]);
  }
  return result;
}

/// Tách chuỗi phân cách bởi dấu phẩy (`,`) và `.trim()` từng phần tử.
/// Dùng chung cho `amenities`, `tags`, hoặc danh sách từ khóa nhập từ form.
List<String> parseCommaSeparatedKeys(Object? raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return const [];
  return text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
}

/// Trích xuất khu vực động (Quận/Huyện/Thị xã hoặc Tỉnh/Thành phố) từ địa chỉ bất kỳ
/// dựa trên cấu trúc phân tách dấu phẩy của địa chỉ, không hardcode địa danh.
String extractDynamicRegionFromAddress(
  String address, {
  String? explicitRegion,
}) {
  if (explicitRegion != null && explicitRegion.trim().isNotEmpty) {
    return explicitRegion.trim();
  }
  final parts = address
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return parts[parts.length - 2];
}

/// Lấy toàn bộ các cấp địa giới hành chính trong địa chỉ (tách theo dấu phẩy)
/// để hỗ trợ lọc theo Phường/Xã, Quận/Huyện hoặc Tỉnh/Thành phố.
List<String> extractAddressSegments(String address) {
  return address
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Kiểm tra một chuỗi tên chủ trọ có phải là giá trị mặc định/rỗng hay không
bool isPlaceholderLandlordName(String? name) {
  if (name == null) return true;
  final trimmed = name.trim();
  return trimmed.isEmpty ||
      trimmed == 'Chủ trọ' ||
      trimmed == 'Người dùng' ||
      trimmed == 'Khách';
}

/// ---------------------------------------------------------------------------
/// ĐẦU NỐI (HOOK & INPUT MODEL) DÀNH CHO UI/UX NHẬP CHI TIẾT PHÒNG
/// ---------------------------------------------------------------------------

class RoomExtraDetailInput {
  final String description;
  final double electricPrice;
  final double waterPrice;
  final String? amenitiesText; // VD: "Điều hòa, Nóng lạnh, Giường tủ"
  final List<String>? amenitiesList;
  final List<String>? imageUrls;
  final String? region;
  final String? furniture;
  final double? rating;
  final String? tagsText; // VD: "Gần bến xe, Có ban công, Giờ giấc tự do"
  final List<String>? tagsList;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordZalo;
  final String? landlordAvatar;
  final int? totalRoomsOwned;

  const RoomExtraDetailInput({
    this.description = '',
    this.electricPrice = 0.0,
    this.waterPrice = 0.0,
    this.amenitiesText,
    this.amenitiesList,
    this.imageUrls,
    this.region,
    this.furniture,
    this.rating,
    this.tagsText,
    this.tagsList,
    this.landlordName,
    this.landlordPhone,
    this.landlordZalo,
    this.landlordAvatar,
    this.totalRoomsOwned,
  });

  List<String> get resolvedAmenities => amenitiesList != null
      ? parseCommaSeparatedKeys(amenitiesList)
      : parseCommaSeparatedKeys(amenitiesText);

  List<String> get resolvedTags => tagsList != null
      ? parseCommaSeparatedKeys(tagsList)
      : parseCommaSeparatedKeys(tagsText);
}

typedef RoomExtraDetailFormBuilder = Future<RoomExtraDetail?> Function(
  BuildContext context, {
  required String postId,
  required String ownerId,
  RoomExtraDetail? initialDetail,
});

class RoomExtraDetailIntegration {
  RoomExtraDetailIntegration._();

  static RoomExtraDetailFormBuilder? _formLauncher;

  static void registerFormLauncher(RoomExtraDetailFormBuilder launcher) {
    _formLauncher = launcher;
  }

  static bool get isFormRegistered => _formLauncher != null;

  static Future<RoomExtraDetail?> openExtraDetailForm(
    BuildContext context, {
    required String postId,
    required String ownerId,
    RoomExtraDetail? initialDetail,
  }) async {
    final launcher = _formLauncher;
    if (launcher == null) return null;
    final updated = await launcher(
      context,
      postId: postId,
      ownerId: ownerId,
      initialDetail: initialDetail,
    );
    if (updated != null) {
      await RoomDetailFirebaseService.instance.saveRoomExtraDetail(
        postId: postId,
        detail: updated,
      );
    }
    return updated;
  }
}

/// ---------------------------------------------------------------------------
/// MODEL CHI TIẾT PHÒNG (`RoomExtraDetail`) LƯU TRÊN FIREBASE `room_detail`
/// ---------------------------------------------------------------------------

class RoomExtraDetail {
  final String postId;
  final String ownerId;
  final String description;
  final double electricPrice; // Nghìn/kWh
  final double waterPrice; // Nghìn/khối
  final List<String> amenities; // Lấy từ chuỗi cách nhau bằng dấu phẩy và trim()
  final List<String> imageUrls; // Toàn bộ ảnh của phòng
  final String landlordName;
  final String landlordPhone;
  final String landlordZalo;
  final String landlordAvatar;
  final int totalRoomsOwned;
  final String region;
  final String furniture;
  final double rating; // 0.0 nếu chưa có đánh giá
  final List<String> tags;
  final bool isHidden;

  const RoomExtraDetail({
    required this.postId,
    this.ownerId = '',
    required this.description,
    required this.electricPrice,
    required this.waterPrice,
    required this.amenities,
    this.imageUrls = const [],
    required this.landlordName,
    required this.landlordPhone,
    required this.landlordZalo,
    required this.landlordAvatar,
    required this.totalRoomsOwned,
    this.region = '',
    this.furniture = '',
    this.rating = 0.0,
    this.tags = const [],
    this.isHidden = false,
  });

  String get amenitiesCommaText => amenities.join(', ');
  String get tagsCommaText => tags.join(', ');

  RoomExtraDetail copyWith({
    String? postId,
    String? ownerId,
    String? description,
    double? electricPrice,
    double? waterPrice,
    List<String>? amenities,
    List<String>? imageUrls,
    String? landlordName,
    String? landlordPhone,
    String? landlordZalo,
    String? landlordAvatar,
    int? totalRoomsOwned,
    String? region,
    String? furniture,
    double? rating,
    List<String>? tags,
    bool? isHidden,
  }) {
    return RoomExtraDetail(
      postId: postId ?? this.postId,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      electricPrice: electricPrice ?? this.electricPrice,
      waterPrice: waterPrice ?? this.waterPrice,
      amenities: amenities ?? this.amenities,
      imageUrls: imageUrls ?? this.imageUrls,
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      landlordZalo: landlordZalo ?? this.landlordZalo,
      landlordAvatar: landlordAvatar ?? this.landlordAvatar,
      totalRoomsOwned: totalRoomsOwned ?? this.totalRoomsOwned,
      region: region ?? this.region,
      furniture: furniture ?? this.furniture,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  static String extractPhone(String contact) {
    final match = RegExp(r'(0|\+84)[0-9]{8,10}').firstMatch(
      contact.replaceAll(RegExp(r'[\s\.\-]'), ''),
    );
    return match?.group(0) ?? (contact.trim().isNotEmpty ? contact.trim() : '');
  }

  /// Chỉ lưu những trường thuộc `room_detail` xuống Firestore.
  /// Không lưu đè `Chủ trọ` mặc định hay copy cứng `imageUrls`/`amenities` của `posts`
  /// để tránh làm sống lại ảnh/tiện ích đã xóa bên `posts`.
  Map<String, dynamic> toMap() => {
        'postId': postId,
        'ownerId': ownerId,
        'description': description,
        'electricPrice': electricPrice,
        'waterPrice': waterPrice,
        if (!isPlaceholderLandlordName(landlordName))
          'landlordName': landlordName.trim(),
        if (landlordPhone.trim().isNotEmpty)
          'landlordPhone': landlordPhone.trim(),
        if (landlordZalo.trim().isNotEmpty) 'landlordZalo': landlordZalo.trim(),
        if (landlordAvatar.trim().isNotEmpty)
          'landlordAvatar': landlordAvatar.trim(),
        'totalRoomsOwned': totalRoomsOwned,
        'region': region,
        'furniture': furniture,
        'tags': tags,
        'isHidden': isHidden,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory RoomExtraDetail.fromMap(
    Map<String, dynamic> data, {
    required String postId,
    Map<String, dynamic>? postData,
  }) {
    final address = postData?['address']?.toString().trim() ?? '';
    final contact = postData?['contact']?.toString().trim() ?? '';
    final ownerId =
        (postData?['ownerId'] ?? data['ownerId'] ?? '').toString().trim();

    // 1. Tiện ích (`amenities`) và Ảnh (`imageUrls`):
    // `posts` là nguồn dữ liệu gốc (Single Source of Truth).
    // Nếu có `postData`, chỉ lấy từ `postData` để khi chủ trọ xóa ảnh/tiện ích bên `posts`,
    // dữ liệu cũ trong `room_detail` không bao giờ làm sống lại ảnh/tiện ích đã xóa.
    final List<String> resolvedAmenities;
    if (postData != null && postData.containsKey('amenities')) {
      resolvedAmenities = parseCommaSeparatedKeys(postData['amenities']);
    } else {
      resolvedAmenities = parseCommaSeparatedKeys(data['amenities']);
    }

    final List<String> resolvedImages;
    if (postData != null && postData['imageUrls'] is List) {
      resolvedImages = (postData['imageUrls'] as List)
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (data['imageUrls'] is List) {
      resolvedImages = (data['imageUrls'] as List)
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      resolvedImages = const <String>[];
    }

    // 2. Mô tả chi tiết (`description`):
    // Chỉ lấy từ `room_detail.description`, tuyệt đối không lấy bản sao của `amenities`.
    final desc = data['description']?.toString().trim() ?? '';

    // 3. Thông tin liên hệ & Tên chủ trọ:
    // Ưu tiên lấy tên thật từ `InteractionService.users` (`contact_profiles`) nếu có.
    final cachedOwner = ownerId.isNotEmpty
        ? InteractionService.instance.userById(ownerId)
        : null;
    final rawDetailName = data['landlordName']?.toString().trim();
    final String resolvedLandlordName;
    if (!isPlaceholderLandlordName(rawDetailName)) {
      resolvedLandlordName = rawDetailName!;
    } else if (cachedOwner != null &&
        !isPlaceholderLandlordName(cachedOwner.name)) {
      resolvedLandlordName = cachedOwner.name.trim();
    } else {
      resolvedLandlordName = 'Chủ trọ';
    }

    final extractedPhone = extractPhone(contact);
    final rawDetailPhone = data['landlordPhone']?.toString().trim() ?? '';
    final cachedPhone = cachedOwner?.phone.trim() ?? '';
    final phone = rawDetailPhone.isNotEmpty
        ? rawDetailPhone
        : (extractedPhone.isNotEmpty
            ? extractedPhone
            : (cachedPhone.isNotEmpty ? cachedPhone : contact));
    final zalo = (data['landlordZalo']?.toString().trim().isNotEmpty ?? false)
        ? data['landlordZalo'].toString().trim()
        : phone;

    final region = extractDynamicRegionFromAddress(
      address,
      explicitRegion: data['region']?.toString(),
    );

    final rawFurniture = data['furniture']?.toString().trim() ?? '';
    final parsedTags = parseCommaSeparatedKeys(data['tags']);

    // 4. Điểm đánh giá sao (`rating`):
    // Chỉ lấy điểm từ các đánh giá thực tế (`summary.count > 0`).
    // Phòng chưa có đánh giá phải có `rating = 0.0` (không gán 5.0 giả).
    final summary = InteractionService.instance.ratingSummary(postId);
    final resolvedRating = summary.count > 0 ? summary.average : 0.0;

    return RoomExtraDetail(
      postId: postId,
      ownerId: ownerId,
      description: desc,
      electricPrice: (data['electricPrice'] as num?)?.toDouble() ?? 0.0,
      waterPrice: (data['waterPrice'] as num?)?.toDouble() ?? 0.0,
      amenities: resolvedAmenities,
      imageUrls: resolvedImages,
      landlordName: resolvedLandlordName,
      landlordPhone: phone,
      landlordZalo: zalo,
      landlordAvatar: data['landlordAvatar']?.toString().trim() ?? '',
      totalRoomsOwned: (data['totalRoomsOwned'] as num?)?.toInt() ?? 1,
      region: region,
      furniture: rawFurniture,
      rating: resolvedRating,
      tags: parsedTags,
      isHidden: data['isHidden'] == true,
    );
  }

  factory RoomExtraDetail.fromInput({
    required String postId,
    required String ownerId,
    required RoomExtraDetailInput input,
    RoomExtraDetail? existing,
  }) {
    final summary = InteractionService.instance.ratingSummary(postId);
    return RoomExtraDetail(
      postId: postId,
      ownerId: ownerId.isNotEmpty ? ownerId : (existing?.ownerId ?? ''),
      description: input.description.trim(),
      electricPrice: input.electricPrice,
      waterPrice: input.waterPrice,
      amenities: input.amenitiesList != null || input.amenitiesText != null
          ? input.resolvedAmenities
          : (existing?.amenities ?? const []),
      imageUrls: input.imageUrls != null
          ? input.imageUrls!
          : (existing?.imageUrls ?? const []),
      landlordName: !isPlaceholderLandlordName(input.landlordName)
          ? input.landlordName!.trim()
          : (existing?.landlordName ?? 'Chủ trọ'),
      landlordPhone:
          input.landlordPhone?.trim() ?? existing?.landlordPhone ?? '',
      landlordZalo: input.landlordZalo?.trim() ??
          input.landlordPhone?.trim() ??
          existing?.landlordZalo ??
          '',
      landlordAvatar:
          input.landlordAvatar?.trim() ?? existing?.landlordAvatar ?? '',
      totalRoomsOwned:
          input.totalRoomsOwned ?? existing?.totalRoomsOwned ?? 1,
      region: input.region?.trim() ?? existing?.region ?? '',
      furniture: input.furniture?.trim() ?? existing?.furniture ?? '',
      rating: summary.count > 0 ? summary.average : 0.0,
      tags: input.tagsList != null || input.tagsText != null
          ? input.resolvedTags
          : (existing?.tags ?? const []),
      isHidden: existing?.isHidden ?? false,
    );
  }
}

/// ---------------------------------------------------------------------------
/// MODEL PHÒNG TRỌ (`RoomItem`) KẾ THỪA `BaseEntity<String>`
/// ---------------------------------------------------------------------------

class RoomItem extends BaseEntity<String> {
  final String ownerId;
  final String title;
  final String region;
  final String address;
  final double price; // Đơn vị: VNĐ / tháng
  final double area; // m²
  final String imageUrl;
  final List<String> imageUrls;
  final String furniture;
  final double rating; // 0.0 nếu chưa có đánh giá
  final List<String> tags;
  final String availability; // 'available' | 'rented'
  final String reviewStatus; // 'pending' | 'approved' | 'rejected'
  final bool isHidden;
  final String contact;
  final RoomExtraDetail? extraDetail;

  const RoomItem({
    required String id,
    this.ownerId = '',
    required this.title,
    this.region = '',
    required this.address,
    required this.price,
    required this.area,
    required this.imageUrl,
    this.imageUrls = const [],
    this.furniture = '',
    this.rating = 0.0,
    this.tags = const [],
    this.availability = 'available',
    this.reviewStatus = 'approved',
    this.isHidden = false,
    this.contact = '',
    this.extraDetail,
    DateTime? createdAt,
  }) : super(id: id, createdAt: createdAt);

  /// Số liệu đánh giá thực tế (`average`, `count`) từ `InteractionService` (module `contact/`)
  RatingSummary get ratingSummary =>
      InteractionService.instance.ratingSummary(id);

  /// Điểm sao thực tế: chỉ trả về số sao > 0 khi phòng đã có ít nhất 1 đánh giá (`count > 0`).
  double get effectiveRating {
    final summary = ratingSummary;
    return summary.count > 0 ? summary.average : 0.0;
  }

  /// Số lượt đánh giá thực tế của phòng
  int get reviewCount => ratingSummary.count;

  /// Giữ getter `imageURL` (ảnh bìa) tương thích với thẻ phòng ở trang chủ
  String get imageURL => imageUrl.isNotEmpty
      ? imageUrl
      : (imageUrls.isNotEmpty ? imageUrls.first : '');

  /// Trả về toàn bộ danh sách ảnh hiện hành của phòng (lấy theo bài đăng `posts`)
  List<String> get allImages {
    if (imageUrls.isNotEmpty) {
      return imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (imageUrl.trim().isNotEmpty) {
      return [imageUrl.trim()];
    }
    return const [];
  }

  /// Danh sách tiện ích (đã tách bằng dấu phẩy và trim)
  List<String> get amenities => extraDetail?.amenities ?? const [];

  /// Tất cả các phân đoạn địa chỉ (tách theo dấu phẩy) phục vụ lọc khu vực đa cấp
  List<String> get addressSegments => extractAddressSegments(address);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          region == other.region &&
          address == other.address &&
          price == other.price &&
          area == other.area &&
          imageUrl == other.imageUrl &&
          listEquals(imageUrls, other.imageUrls) &&
          furniture == other.furniture &&
          rating == other.rating &&
          availability == other.availability &&
          reviewStatus == other.reviewStatus &&
          isHidden == other.isHidden &&
          listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        region,
        address,
        price,
        area,
        imageUrl,
        Object.hashAll(imageUrls),
        furniture,
        rating,
        availability,
        reviewStatus,
        isHidden,
        Object.hashAll(tags),
      );

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'ownerId': ownerId,
        'title': title,
        'region': region,
        'address': address,
        'price': price,
        'area': area,
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'furniture': furniture,
        'rating': rating,
        'tags': tags,
        'availability': availability,
        'reviewStatus': reviewStatus,
        'isHidden': isHidden,
        'contact': contact,
      };

  factory RoomItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final urls = json['imageUrls'] is List
        ? List<String>.from((json['imageUrls'] as List).whereType<String>())
        : <String>[];
    final primaryImage = (json['imageUrl'] ?? json['imageURL'] ?? '').toString();
    final address = (json['address'] ?? '').toString();
    final summary = id.isNotEmpty
        ? InteractionService.instance.ratingSummary(id)
        : const RatingSummary(average: 0, count: 0);
    return RoomItem(
      id: id,
      ownerId: (json['ownerId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      region: extractDynamicRegionFromAddress(
        address,
        explicitRegion: json['region']?.toString(),
      ),
      address: address,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      imageUrl: primaryImage.isNotEmpty
          ? primaryImage
          : (urls.isNotEmpty ? urls.first : ''),
      imageUrls: urls,
      furniture: (json['furniture'] ?? '').toString(),
      rating: summary.count > 0 ? summary.average : 0.0,
      tags: parseCommaSeparatedKeys(json['tags']),
      availability: (json['availability'] ?? 'available').toString(),
      reviewStatus: (json['reviewStatus'] ?? 'approved').toString(),
      isHidden: json['isHidden'] == true,
      contact: (json['contact'] ?? '').toString(),
      createdAt: BaseEntity.parseDate(json['createdAt']),
    );
  }

  /// Khởi tạo `RoomItem` bằng cách ghép dữ liệu từ document `posts` và document `room_detail`.
  /// Hàm thuần túy (pure factory), không gọi `registerRoom` hay gây side-effect `notifyListeners` trong lúc build.
  factory RoomItem.fromPostAndDetail({
    required DocumentSnapshot<Map<String, dynamic>> postDoc,
    Map<String, dynamic>? detailMap,
  }) {
    final postData = postDoc.data() ?? <String, dynamic>{};
    final detail = RoomExtraDetail.fromMap(
      detailMap ?? const <String, dynamic>{},
      postId: postDoc.id,
      postData: postData,
    );

    final imageList = detail.imageUrls;
    final coverImage = imageList.isNotEmpty
        ? imageList.first
        : (postData['imageURL'] ?? postData['imageUrl'] ?? '').toString();

    DateTime? parsedCreatedAt;
    final rawCreated = postData['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else {
      parsedCreatedAt = BaseEntity.parseDate(rawCreated);
    }

    final resolvedOwnerId = (postData['ownerId'] ?? detail.ownerId).toString();
    final isHidden = postData['isHidden'] == true ||
        detail.isHidden ||
        InteractionService.instance.isRoomHidden(postDoc.id);

    return RoomItem(
      id: postDoc.id,
      ownerId: resolvedOwnerId,
      title: (postData['title'] ?? '').toString(),
      region: detail.region,
      address: (postData['address'] ?? '').toString(),
      price: (postData['price'] as num?)?.toDouble() ?? 0.0,
      area: (postData['area'] as num?)?.toDouble() ?? 0.0,
      imageUrl: coverImage,
      imageUrls: imageList,
      furniture: detail.furniture,
      rating: detail.rating,
      tags: detail.tags,
      availability: (postData['availability'] ?? 'available').toString(),
      reviewStatus: (postData['reviewStatus'] ?? 'approved').toString(),
      isHidden: isHidden,
      contact: (postData['contact'] ?? '').toString(),
      extraDetail: detail,
      createdAt: parsedCreatedAt,
    );
  }
}

/// ---------------------------------------------------------------------------
/// SERVICE KẾT NỐI FIREBASE CHO `room_detail` & `search_tags`
/// ---------------------------------------------------------------------------

class RoomDetailFirebaseService {
  RoomDetailFirebaseService._() {
    _bindInteractionHooks();
  }

  static final RoomDetailFirebaseService instance =
      RoomDetailFirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get roomDetailsRef =>
      _db.collection('room_detail');

  CollectionReference<Map<String, dynamic>> get searchTagsRef =>
      _db.collection('search_tags');

  /// Gắn hook `onHideRoom` vào `InteractionService` để khi Admin xử lý báo cáo
  /// "Ẩn bài", trạng thái ẩn được lưu xuống `room_detail/{roomId}` (và `posts/{roomId}` nếu có quyền).
  void _bindInteractionHooks() {
    final s = InteractionService.instance;
    final previousHideHook = s.onHideRoom;
    s.onHideRoom = (String roomId) {
      previousHideHook?.call(roomId);
      unawaited(hideRoomByAdmin(roomId));
    };
  }

  /// Ẩn bài đăng khi Admin xác nhận báo cáo vi phạm
  Future<void> hideRoomByAdmin(String roomId) async {
    InteractionService.instance.hiddenRoomIds.add(roomId);
    InteractionService.instance.refresh();
    try {
      await roomDetailsRef.doc(roomId).set(
        {
          'postId': roomId,
          'isHidden': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
    try {
      await _db.collection('posts').doc(roomId).update({
        'isHidden': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Chỉ được gọi khi Chủ trọ hoặc Admin chủ động bấm Lưu trên form chi tiết phòng.
  /// Không bao giờ tự động gọi khi người dùng chỉ đang xem trang chủ hay trang chi tiết.
  Future<void> saveRoomExtraDetail({
    required String postId,
    required RoomExtraDetail detail,
  }) async {
    await roomDetailsRef.doc(postId).set(
          detail.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<RoomExtraDetail> saveExtraDetailFromInput({
    required String postId,
    required String ownerId,
    required RoomExtraDetailInput input,
    RoomExtraDetail? existing,
  }) async {
    final detail = RoomExtraDetail.fromInput(
      postId: postId,
      ownerId: ownerId,
      input: input,
      existing: existing,
    );
    await saveRoomExtraDetail(postId: postId, detail: detail);
    return detail;
  }

  /// Dọn dẹp dữ liệu mồ côi trong `room_detail` khi phát hiện bài đăng gốc trong `posts` đã bị xóa
  Future<void> cleanupOrphanedRoomDetail(String postId) async {
    try {
      await roomDetailsRef.doc(postId).delete();
    } catch (_) {}
  }

  Stream<List<String>> watchSearchTags() {
    return searchTagsRef.snapshots().map((snapshot) {
      final result = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['active'] == false) continue;
        final single =
            (data['name'] ?? data['label'] ?? data['tag'] ?? '').toString().trim();
        if (single.isNotEmpty) {
          result.addAll(parseCommaSeparatedKeys(single));
        }
        if (data['tags'] != null) {
          result.addAll(parseCommaSeparatedKeys(data['tags']));
        }
      }
      return result.toList();
    });
  }

  /// Trích xuất chuỗi ảnh đại diện từ document trong collection `avatars/{uid}`
  static String _extractAvatarSource(Map<String, dynamic>? data) {
    if (data == null) return '';
    for (final key in const [
      'dataUrl',
      'avatar',
      'avatarUrl',
      'imageUrl',
      'url',
      'photoURL',
      'photoUrl',
      'base64',
      'data',
    ]) {
      final raw = data[key]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;
      if (raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('data:image/')) {
        return raw;
      }
      if (raw.length > 64 && !raw.contains(' ')) {
        return '$kPostImagePrefix$raw';
      }
    }
    return '';
  }

  /// Chỉ ĐỌC (Read-only) chi tiết phòng từ `room_detail/{roomId}`, `posts/{roomId}`,
  /// `contact_profiles/{ownerId}`, `avatars/{ownerId}` và `users/{ownerId}`.
  /// Tuyệt đối KHÔNG tự động ghi xuống `room_detail` khi người dùng chỉ xem phòng.
  Future<RoomExtraDetail> fetchAndSyncRoomDetail(RoomItem room) async {
    final detailDocRef = roomDetailsRef.doc(room.id);

    final results = await Future.wait([
      detailDocRef.get(),
      _db.collection('posts').doc(room.id).get(),
    ]);

    final detailSnap = results[0];
    final postSnap = results[1];

    if (!postSnap.exists && detailSnap.exists) {
      unawaited(cleanupOrphanedRoomDetail(room.id));
    }

    final postData = postSnap.data() ?? room.toJson();

    final postOwnerId = postData['ownerId']?.toString().trim() ?? '';
    final roomOwnerId = room.ownerId.trim();
    final ownerId = postOwnerId.isNotEmpty
        ? postOwnerId
        : (roomOwnerId.isNotEmpty
            ? roomOwnerId
            : (InteractionService.instance.ownerOf(room.id) ?? '').trim());

    final detailData = Map<String, dynamic>.from(detailSnap.data() ?? {});

    if (ownerId.isNotEmpty) {
      String? resolvedName;
      String? resolvedPhone;
      String? resolvedAvatar;

      final cachedOwner = InteractionService.instance.userById(ownerId);
      if (cachedOwner != null) {
        if (!isPlaceholderLandlordName(cachedOwner.name)) {
          resolvedName = cachedOwner.name.trim();
        }
        if (cachedOwner.phone.trim().isNotEmpty) {
          resolvedPhone = cachedOwner.phone.trim();
        }
      }

      try {
        final profileAndAvatar = await Future.wait([
          _db.collection('contact_profiles').doc(ownerId).get(),
          _db.collection('avatars').doc(ownerId).get(),
        ]);

        final contactProfile = profileAndAvatar[0].data();
        if (contactProfile != null) {
          final pName = (contactProfile['name'] ??
                  contactProfile['fullName'] ??
                  contactProfile['displayName'])
              ?.toString()
              .trim();
          if (!isPlaceholderLandlordName(pName)) {
            resolvedName = pName;
          }
          final pPhone = contactProfile['phone']?.toString().trim() ?? '';
          if (pPhone.isNotEmpty) {
            resolvedPhone = pPhone;
          }
          final pAvatar = _extractAvatarSource(contactProfile);
          if (pAvatar.isNotEmpty) {
            resolvedAvatar = pAvatar;
          }
        }

        final avatarDoc = profileAndAvatar[1].data();
        final avatarFromCollection = _extractAvatarSource(avatarDoc);
        if (avatarFromCollection.isNotEmpty) {
          resolvedAvatar = avatarFromCollection;
        }
      } catch (_) {}

      try {
        final ownerPostsSnap = await _db
            .collection('posts')
            .where('ownerId', isEqualTo: ownerId)
            .where('reviewStatus', isEqualTo: 'approved')
            .where('isHidden', isEqualTo: false)
            .get();
        detailData['totalRoomsOwned'] = ownerPostsSnap.docs.isNotEmpty
            ? ownerPostsSnap.docs.length
            : (detailData['totalRoomsOwned'] ?? 1);
      } catch (_) {}

      if (isPlaceholderLandlordName(resolvedName) ||
          (resolvedAvatar == null || resolvedAvatar.isEmpty)) {
        try {
          final ownerSnap = await _db.collection('users').doc(ownerId).get();
          final ownerProfile = ownerSnap.data();
          if (ownerProfile != null) {
            final uName = (ownerProfile['fullName'] ??
                    ownerProfile['name'] ??
                    ownerProfile['displayName'])
                ?.toString()
                .trim();
            if (isPlaceholderLandlordName(resolvedName) &&
                !isPlaceholderLandlordName(uName)) {
              resolvedName = uName;
            }
            final uPhone = ownerProfile['phone']?.toString().trim() ?? '';
            if ((resolvedPhone == null || resolvedPhone.isEmpty) &&
                uPhone.isNotEmpty) {
              resolvedPhone = uPhone;
            }
            final uAvatar = _extractAvatarSource(ownerProfile);
            if ((resolvedAvatar == null || resolvedAvatar.isEmpty) &&
                uAvatar.isNotEmpty) {
              resolvedAvatar = uAvatar;
            }
          }
        } catch (_) {}
      }

      if (!isPlaceholderLandlordName(resolvedName) &&
          isPlaceholderLandlordName(detailData['landlordName']?.toString())) {
        detailData['landlordName'] = resolvedName;
      }
      if (resolvedPhone != null &&
          resolvedPhone.isNotEmpty &&
          (detailData['landlordPhone']?.toString().trim().isEmpty ?? true)) {
        detailData['landlordPhone'] = resolvedPhone;
      }
      if (resolvedAvatar != null &&
          resolvedAvatar.isNotEmpty &&
          (detailData['landlordAvatar']?.toString().trim().isEmpty ?? true)) {
        detailData['landlordAvatar'] = resolvedAvatar;
      }
    }

    return RoomExtraDetail.fromMap(
      detailData,
      postId: room.id,
      postData: postData,
    );
  }
}

/// Widget hiển thị ảnh hỗ trợ cả ảnh Base64 (`data:image/...;base64,...`)
/// lẫn đường dẫn ảnh mạng HTTPS.
class RoomImageView extends StatelessWidget {
  final String source;
  final double? height;
  final double? width;
  final BoxFit fit;

  const RoomImageView({
    super.key,
    required this.source,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  Widget _errorBox() {
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, size: 36, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return _errorBox();

    if (trimmed.startsWith('data:image/')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < trimmed.length) {
        try {
          final Uint8List bytes = base64Decode(
            trimmed.substring(commaIndex + 1),
          );
          return Image.memory(
            bytes,
            height: height,
            width: width ?? double.infinity,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _errorBox(),
          );
        } catch (_) {
          return _errorBox();
        }
      }
    }

    return Image.network(
      trimmed,
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => _errorBox(),
    );
  }
}

/// Đăng ký RoomItem với EntityRegistry (gọi 1 lần lúc khởi động app).
void registerRoomModels() {
  EntityRegistry.register<RoomItem>(RoomItem.fromJson, name: 'rooms');
}