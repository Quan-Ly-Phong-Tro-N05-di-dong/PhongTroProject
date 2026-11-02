// test/home_catalog_test.dart
// Chạy kiểm thử bằng lệnh:
//   flutter test test/home_catalog_test.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_test/core/base/entity_registry.dart';
import 'package:flutter_application_test/features/contact/models/appointment.dart';
import 'package:flutter_application_test/features/contact/services/interaction_service.dart';
import 'package:flutter_application_test/features/home_catalog/models/room_item.dart';
import 'package:flutter_application_test/features/home_catalog/counter_screen.dart';

/// Giả lập `DocumentSnapshot<Map<String, dynamic>>` của Firestore để kiểm thử
/// `RoomItem.fromPostAndDetail` mà không cần thêm gói `fake_cloud_firestore`.
// ignore: subtype_of_sealed_class
class FakePostDocumentSnapshot
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  final bool exists;

  FakePostDocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    this.exists = true,
  }) : _data = data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  dynamic get(Object field) => _data?[field];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ảnh JPEG 1x1 hợp lệ dạng Base64 phục vụ kiểm thử Widget `RoomImageView`
const String kValid1x1JpegDataUri =
    'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

void main() {
  setUp(() {
    // Khởi tạo lại InteractionService sạch trước mỗi test case
    InteractionService.instance = InteractionService(seed: false);
    InteractionService.instance.startRemoteMode();
  });

  // ===========================================================================
  // PHẦN 1 (Câu 8b): UNIT TEST CÁC HÀM XỬ LÝ CHUỖI, TIỀN TỆ, ĐỊA CHỈ & TIỆN ÍCH
  // ===========================================================================
  group('8b.1 - Kiểm định hàm tiện ích (Tiền tệ VNĐ, Bỏ dấu, Tách khóa, Địa chỉ)', () {
    test('formatCurrencyVnd định dạng đúng dấu chấm hàng nghìn và không tự nhân 1.000.000', () {
      expect(formatCurrencyVnd(0), '0');
      expect(formatCurrencyVnd(500), '500'); // Hồi quy lỗi nhập 500 bị thành 500.000.000
      expect(formatCurrencyVnd(500000), '500.000');
      expect(formatCurrencyVnd(2800000), '2.800.000');
      expect(formatCurrencyVnd(15000000), '15.000.000');
    });

    test('removeVietnameseDiacritics chuẩn hóa chính xác chuỗi tiếng Việt có dấu sang không dấu', () {
      expect(
        removeVietnameseDiacritics('Phòng trọ khép kín gần ĐH Phenikaa, Yên Nghĩa, Hà Đông'),
        'phong tro khep kin gan dh phenikaa, yen nghia, ha dong',
      );
      expect(
        removeVietnameseDiacritics('ĐIỀU HÒA, NÓNG LẠNH, GIƯỜNG TỦ'),
        'dieu hoa, nong lanh, giuong tu',
      );
    });

    test('parseCommaSeparatedKeys tách theo dấu phẩy, trim khoảng trắng và loại bỏ trùng lặp', () {
      expect(parseCommaSeparatedKeys(null), isEmpty);
      expect(parseCommaSeparatedKeys('   '), isEmpty);
      expect(
        parseCommaSeparatedKeys(' Điều hòa , Nóng lạnh, Giường tủ , Điều hòa , '),
        ['Điều hòa', 'Nóng lạnh', 'Giường tủ'],
      );
      expect(
        parseCommaSeparatedKeys([' Wifi ', 'Máy giặt', 'Wifi', '']),
        ['Wifi', 'Máy giặt'],
      );
    });

    test('extractDynamicRegionFromAddress & extractAddressSegments trích xuất động mọi tỉnh/thành', () {
      expect(
        extractDynamicRegionFromAddress('Số 10, Phường Yên Nghĩa, Quận Hà Đông, Hà Nội'),
        'Quận Hà Đông',
      );
      expect(
        extractDynamicRegionFromAddress(
          '123 Lê Lợi, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        ),
        'Quận 1',
      );
      // Ưu tiên explicitRegion nếu chủ trọ đã nhập trực tiếp trong room_detail
      expect(
        extractDynamicRegionFromAddress(
          'Số 10, Yên Nghĩa, Hà Đông, Hà Nội',
          explicitRegion: 'Yên Nghĩa',
        ),
        'Yên Nghĩa',
      );
      expect(
        extractAddressSegments('Số 10, Yên Nghĩa, Hà Đông, Hà Nội'),
        ['Số 10', 'Yên Nghĩa', 'Hà Đông', 'Hà Nội'],
      );
    });

    test('isPlaceholderLandlordName nhận diện đúng các tên mặc định không hợp lệ', () {
      expect(isPlaceholderLandlordName(null), isTrue);
      expect(isPlaceholderLandlordName(''), isTrue);
      expect(isPlaceholderLandlordName('   '), isTrue);
      expect(isPlaceholderLandlordName('Chủ trọ'), isTrue);
      expect(isPlaceholderLandlordName('Người dùng'), isTrue);
      expect(isPlaceholderLandlordName('Khách'), isTrue);
      expect(isPlaceholderLandlordName('Nguyễn Quang Huy'), isFalse);
    });
  });

  // ===========================================================================
  // PHẦN 2 (Câu 7 & 8b): KIỂM ĐỊNH ORM MAPPING (RoomExtraDetail & RoomItem)
  // ===========================================================================
  group('8b.2 - Kiểm định ORM Mapping & Hồi quy các lỗi dữ liệu (RoomExtraDetail, RoomItem)', () {
    test('Phòng mới chưa có đánh giá có rating = 0.0 (không bị gán giả 5.0 sao)', () {
      final detail = RoomExtraDetail.fromMap(
        const {'rating': 5.0}, // Kể cả dữ liệu cũ có lưu 5.0 nhưng chưa có review thật
        postId: 'room_unrated',
        postData: const {
          'title': 'Phòng mới đăng',
          'address': 'Yên Nghĩa, Hà Đông, Hà Nội',
          'price': 2500000,
          'area': 20,
        },
      );

      expect(detail.rating, 0.0);
    });

    test('Phòng đã có đánh giá thực tế trong InteractionService lấy đúng điểm trung bình & số lượt', () {
      final s = InteractionService.instance;
      const owner = DemoUser(
        id: 'owner_1',
        name: 'Chủ trọ A',
        phone: '0912345678',
        role: UserRole.owner,
      );
      const tenant = DemoUser(
        id: 'tenant_1',
        name: 'Sinh viên B',
        phone: '0987654321',
        role: UserRole.tenant,
      );

      s.registerRoom(
        const RoomItem(
          id: 'room_rated',
          ownerId: 'owner_1',
          title: 'Phòng có đánh giá',
          address: 'Hà Đông, Hà Nội',
          price: 3.0,
          area: 25,
          imageUrl: 'https://example.com/1.jpg',
        ),
        ownerId: owner.id,
      );

      // Đặt lịch -> Chủ trọ xác nhận & hoàn thành -> Người thuê đánh giá 4 sao
      s.switchUser(tenant);
      final appt = s.book(
        roomId: 'room_rated',
        time: s.now().add(const Duration(days: 1)).copyWith(hour: 10, minute: 0),
        phone: tenant.phone,
      );
      s.switchUser(owner);
      s.confirmAppointment(appt.id);
      s.completeAppointment(appt.id);
      s.switchUser(tenant);
      s.addReview(
        appointmentId: appt.id,
        rating: 4,
        comment: 'Phòng sạch sẽ, thoáng mát',
      );

      final postSnap = FakePostDocumentSnapshot(
        id: 'room_rated',
        data: {
          'ownerId': 'owner_1',
          'title': 'Phòng có đánh giá',
          'address': 'Hà Đông, Hà Nội',
          'price': 3000000,
          'area': 25,
          'amenities': 'Điều hòa, Nóng lạnh',
          'imageUrls': ['https://example.com/1.jpg'],
        },
      );

      final item = RoomItem.fromPostAndDetail(postDoc: postSnap);
      expect(item.reviewCount, 1);
      expect(item.effectiveRating, 4.0);
      expect(item.rating, 4.0);
    });

    test('Xóa ảnh hoặc tiện ích bên posts không bị sống lại từ dữ liệu cũ trong room_detail', () {
      final detail = RoomExtraDetail.fromMap(
        const {
          'amenities': ['Điều hòa', 'Tủ lạnh cũ đã xóa'],
          'imageUrls': [
            'https://example.com/new.jpg',
            'https://example.com/deleted_old.jpg',
          ],
          'description': 'Mô tả riêng của phòng',
        },
        postId: 'room_1',
        postData: const {
          'amenities': 'Điều hòa, Nóng lạnh',
          'imageUrls': ['https://example.com/new.jpg'],
          'address': 'Hà Đông, Hà Nội',
        },
      );

      expect(detail.amenities, ['Điều hòa', 'Nóng lạnh']);
      expect(detail.amenities.contains('Tủ lạnh cũ đã xóa'), isFalse);
      expect(detail.imageUrls, ['https://example.com/new.jpg']);
      expect(detail.description, 'Mô tả riêng của phòng');
    });

    test('Khi chưa nhập description trong room_detail, không tự ý copy amenities sang description', () {
      final detail = RoomExtraDetail.fromMap(
        const {},
        postId: 'room_no_desc',
        postData: const {
          'amenities': 'Điều hòa, Nóng lạnh, Giường tủ',
          'address': 'Yên Nghĩa, Hà Đông',
        },
      );

      expect(detail.description, isEmpty);
      expect(detail.amenities, ['Điều hòa', 'Nóng lạnh', 'Giường tủ']);
    });

    test('Hồi quy: RoomItem.fromPostAndDetail là hàm thuần túy, không bắn notifyListeners lúc build', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      InteractionService.instance.addListener(listener);
      addTearDown(() => InteractionService.instance.removeListener(listener));

      final postSnap = FakePostDocumentSnapshot(
        id: 'post_pure_test',
        data: {
          'ownerId': 'landlord_99',
          'title': 'Phòng trọ mới xây',
          'address': 'Phú La, Hà Đông, Hà Nội',
          'price': 2800000,
          'area': 24,
          'amenities': 'Điều hòa, Nóng lạnh',
          'contact': '0987654321',
          'imageUrls': [
            'https://example.com/img1.jpg',
            'https://example.com/img2.jpg',
          ],
          'availability': 'available',
          'reviewStatus': 'approved',
          'isHidden': false,
        },
      );

      final room = RoomItem.fromPostAndDetail(
        postDoc: postSnap,
        detailMap: const {
          'furniture': 'Full nội thất',
          'electricPrice': 3.5,
          'waterPrice': 25.0,
          'tags': ['Gần Phenikaa', 'Có gác xép'],
        },
      );

      expect(notifyCount, 0, reason: 'fromPostAndDetail không được gọi notifyListeners trong lúc build');
      expect(room.id, 'post_pure_test');
      expect(room.price, 2800000);
      expect(room.allImages.length, 2);
      expect(room.furniture, 'Full nội thất');
      expect(room.tags, ['Gần Phenikaa', 'Có gác xép']);
    });

    test('RoomItem đăng ký EntityRegistry và serialize/deserialize toJson/fromJson chính xác', () {
      registerRoomModels();
      const original = RoomItem(
        id: 'r_json_1',
        ownerId: 'u_owner_1',
        title: 'Studio Dương Nội',
        region: 'Dương Nội',
        address: 'KĐT Dương Nội, Hà Đông, Hà Nội',
        price: 4200000,
        area: 35,
        imageUrl: 'https://example.com/cover.jpg',
        imageUrls: ['https://example.com/cover.jpg', 'https://example.com/2.jpg'],
        furniture: 'Full nội thất',
        tags: ['Studio', 'Gần Phenikaa'],
      );

      final json = original.toJson();
      final restored = RoomItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.price, 4200000);
      expect(restored.area, 35);
      expect(restored.furniture, 'Full nội thất');
      expect(restored.allImages.length, 2);
    });
  });

  // ===========================================================================
  // PHẦN 3 (Câu 8b & 8d): KIỂM ĐỊNH BỘ LỌC FILTERMODEL & CÁC TRƯỜNG HỢP BIÊN
  // ===========================================================================
  group('8b.3 & 8d - Kiểm định FilterModel và các kịch bản lọc biên', () {
    test('Bộ lọc mặc định có defaultMinPrice = 0 và defaultMinArea = 0 để không ẩn phòng giá rẻ/nhỏ', () {
      const filter = FilterModel();
      expect(filter.isDefault, isTrue);
      expect(filter.minPrice, 0);
      expect(filter.minArea, 0);
    });

    test('FilterModel.copyWith cập nhật đúng các tiêu chí lọc và xóa hotSearch khi clearHotSearch = true', () {
      const initial = FilterModel();
      final updated = initial.copyWith(
        region: 'Hà Đông',
        minPrice: 1500000,
        maxPrice: 4000000,
        furniture: 'Full nội thất',
        selectedAmenities: {'Điều hòa', 'Nóng lạnh'},
        minRating: 4,
        hotSearch: 'Gần Phenikaa',
      );

      expect(updated.isDefault, isFalse);
      expect(updated.region, 'Hà Đông');
      expect(updated.minPrice, 1500000);
      expect(updated.maxPrice, 4000000);
      expect(updated.furniture, 'Full nội thất');
      expect(updated.selectedAmenities, containsAll(['Điều hòa', 'Nóng lạnh']));
      expect(updated.minRating, 4);
      expect(updated.hotSearch, 'Gần Phenikaa');

      final clearedHot = updated.copyWith(clearHotSearch: true);
      expect(clearedHot.hotSearch, isNull);
    });
  });

  // ===========================================================================
  // PHẦN 4 (Câu 8a & 8e): KIỂM THỬ GIAO DIỆN MOBILE APP & BẮT LỖI HIỂN THỊ ẢNH
  // ===========================================================================
  group('8a & 8e - Widget Test giao diện hiển thị ảnh (RoomImageView) & bắt lỗi dữ liệu hỏng', () {
    testWidgets('RoomImageView hiển thị icon broken_image an toàn khi nguồn ảnh rỗng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomImageView(source: '   ', height: 120),
          ),
        ),
      );

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
    });

    testWidgets('RoomImageView bắt lỗi an toàn khi chuỗi Base64 bị hỏng (không văng crash)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomImageView(
              source: 'data:image/jpeg;base64,@@@CHUOI_BASE64_LOI@@@',
              height: 120,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
    });

    testWidgets('RoomImageView giải mã và hiển thị thành công ảnh nén Base64 hợp lệ', (tester) async {
      final bytes = base64Decode(
        kValid1x1JpegDataUri.substring('data:image/jpeg;base64,'.length),
      );
      expect(bytes, isNotEmpty);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomImageView(
              source: kValid1x1JpegDataUri,
              height: 150,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}