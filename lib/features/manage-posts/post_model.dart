import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

const maxPostImages = 6;
const maxPostImageBytes = 100 * 1024;
const maxEmbeddedImageLength = 140000;
const postImagePrefix = 'data:image/jpeg;base64,';

const availabilityLabels = {
  'available': 'Còn phòng',
  'rented': 'Đã cho thuê',
};

const reviewLabels = {
  'pending': 'Chờ duyệt',
  'approved': 'Đã duyệt',
  'rejected': 'Bị từ chối',
};

class PostException implements Exception {
  final String message;
  const PostException(this.message);

  @override
  String toString() => message;
}

class RentalPost {
  final String id;
  final String ownerId;
  final String title;
  final String address;
  final double price;
  final double area;
  final String amenities;
  final String contact;
  final List<String> imageUrls;
  final String availability;
  final String reviewStatus;
  final bool isHidden;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const RentalPost({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    required this.amenities,
    required this.contact,
    required this.imageUrls,
    required this.availability,
    required this.reviewStatus,
    required this.isHidden,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RentalPost.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const PostException('Bài đăng không còn tồn tại.');
    }
    final images = data['imageUrls'];
    return RentalPost(
      id: document.id,
      ownerId: _text(data['ownerId']),
      title: _text(data['title']),
      address: _text(data['address']),
      price: _number(data['price']),
      area: _number(data['area']),
      amenities: _text(data['amenities']),
      contact: _text(data['contact']),
      imageUrls: List<String>.unmodifiable(
        images is List ? images.whereType<String>() : <String>[],
      ),
      availability: _text(data['availability']),
      reviewStatus: _text(data['reviewStatus']),
      isHidden: data['isHidden'] == true,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
    );
  }

  static String _text(Object? value) => value?.toString() ?? '';

  static double _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return 0;
  }

  String get availabilityLabel =>
      availabilityLabels[availability] ?? 'Chưa cập nhật';

  String get reviewLabel => reviewLabels[reviewStatus] ?? 'Chưa cập nhật';
}

class PostDraft {
  final String title;
  final String address;
  final double price;
  final double area;
  final String amenities;
  final String contact;
  final List<String> imageUrls;

  PostDraft({
    required String title,
    required String address,
    required this.price,
    required this.area,
    required String amenities,
    required String contact,
    required List<String> imageUrls,
  }) : title = title.trim(),
       address = address.trim(),
       amenities = amenities.trim(),
       contact = contact.trim(),
       imageUrls = List<String>.unmodifiable(
         imageUrls.map((url) => url.trim()),
       );

  void validate() {
    _required(title, 120, 'Tiêu đề');
    _required(address, 300, 'Địa chỉ');
    _required(amenities, 1000, 'Tiện ích');
    _required(contact, 150, 'Liên hệ');
    if (!price.isFinite || price <= 0 || price > 1000000000000) {
      throw const PostException('Giá thuê không hợp lệ.');
    }
    if (!area.isFinite || area <= 0 || area > 1000000) {
      throw const PostException('Diện tích không hợp lệ.');
    }
    final error = validateImages(imageUrls);
    if (error != null) throw PostException(error);
  }

  static void _required(String value, int maximum, String label) {
    if (value.isEmpty || value.length > maximum) {
      throw PostException('$label phải từ 1 đến $maximum ký tự.');
    }
  }

  static String? validateImages(List<String> urls) {
    if (urls.isEmpty || urls.length > maxPostImages) {
      return 'Bài đăng cần từ 1 đến 6 ảnh.';
    }
    for (final url in urls) {
      if (url.startsWith(postImagePrefix)) {
        if (url.length > maxEmbeddedImageLength) {
          return 'Ảnh quá lớn. Hãy xóa ảnh này và chọn lại từ thư viện.';
        }
        try {
          final bytes = base64Decode(url.substring(postImagePrefix.length));
          if (bytes.length < 3 ||
              bytes.length > maxPostImageBytes ||
              bytes[0] != 0xff || bytes[1] != 0xd8 || bytes[2] != 0xff) {
            return 'Dữ liệu ảnh không hợp lệ. Hãy chọn lại ảnh.';
          }
        } on FormatException {
          return 'Dữ liệu ảnh không hợp lệ. Hãy chọn lại ảnh.';
        }
        continue;
      }
      // Giữ tương thích với các bài cũ đã lưu đường dẫn HTTPS.
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          url.length > 2048 ||
          RegExp(r'\s').hasMatch(url)) {
        return 'Ảnh không hợp lệ. Hãy xóa ảnh lỗi và chọn ảnh từ thư viện.';
      }
    }
    return null;
  }

  Map<String, dynamic> toFields() => {
    'title': title,
    'address': address,
    'price': price,
    'area': area,
    'amenities': amenities,
    'contact': contact,
    'imageUrls': imageUrls,
  };

  bool sameContentAs(RentalPost post) {
    if (title != post.title ||
        address != post.address ||
        price != post.price ||
        area != post.area ||
        amenities != post.amenities ||
        contact != post.contact ||
        imageUrls.length != post.imageUrls.length) {
      return false;
    }
    for (var i = 0; i < imageUrls.length; i++) {
      if (imageUrls[i] != post.imageUrls[i]) return false;
    }
    return true;
  }
}

String formatRent(num value) {
  final digits = value.toStringAsFixed(0);
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
}

String numberForInput(num value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
