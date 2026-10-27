# Module Tương tác & phản hồi người dùng (`lib/features/contact/`)

Gồm 4 chức năng xoay quanh việc người thuê làm việc với chủ trọ và với hệ thống:
**liên hệ (nhắn tin)**, **đặt lịch hẹn xem phòng**, **đánh giá phòng**, **báo cáo vi phạm**.

> Tên thư mục vẫn là `contact` để không ảnh hưởng đường dẫn import của các module khác. Tên hiển thị của module là "Tương tác & phản hồi người dùng".

Người thực hiện: Lê Hải Anh (MSSV 24100110).

## Chức năng theo vai trò

| Vai trò        | Làm được gì                                                                                                                                                                                    |
| :------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Người thuê** | Nhắn tin cho chủ trọ về một phòng · đặt lịch xem phòng · xem / hủy lịch hẹn · đánh giá phòng sau khi lịch hẹn hoàn thành · sửa, xóa đánh giá của mình · báo cáo bài đăng, người dùng, đánh giá |
| **Chủ trọ**    | Xem và trả lời tin nhắn (có đếm tin chưa xem) · xác nhận / từ chối (có lý do) / hoàn thành lịch hẹn · phản hồi đánh giá về phòng của mình                                                      |
| **Admin**      | Xem báo cáo chờ xử lý / đã xử lý · bỏ qua hoặc xác nhận vi phạm (ẩn bài, khóa tài khoản, xóa đánh giá) · xóa đánh giá                                                                          |

## Luật nghiệp vụ (đã có test)

- Lịch hẹn: `pending → confirmed → completed`, hoặc `pending → rejected`, hoặc `pending/confirmed → cancelled`.
- Chỉ nhận lịch từ 07:00 đến 21:00, không đặt giờ đã qua, bắt buộc có số điện thoại.
- Cùng một phòng không có hai lịch cách nhau dưới 1 giờ (với lịch đã xác nhận; người thuê cũng không tự đặt hai lịch sát giờ).
- Chỉ đánh giá được sau khi lịch hẹn **đã hoàn thành**, từ 1 đến 5 sao, mỗi lịch hẹn một đánh giá.
- Báo cáo: không gửi trùng khi báo cáo cũ của mình còn chờ xử lý; mỗi báo cáo chỉ xử lý một lần.
- Tài khoản bị khóa thì không nhắn tin, đặt lịch, đánh giá, báo cáo được nữa.
- Tin nhắn dài 1–500 ký tự; chỉ người thuê và chủ trọ của cuộc trò chuyện mới nhắn được.

## Cấu trúc

```text
lib/features/contact/
├── models/      contact.dart, contact_message.dart, appointment.dart, review.dart, report.dart
│                (mỗi model extends BaseEntity<String>; contact_models.dart gom + registerContactModels())
├── services/    interaction_service.dart   # toàn bộ nghiệp vụ, lưu bằng Repository<T> trong bộ nhớ
├── widgets/     thành phần dùng lại: thẻ lịch hẹn, form đánh giá/báo cáo, nút hành động ở trang chi tiết phòng...
└── screens/     đặt lịch, đặt lịch thành công, đánh giá/báo cáo, chat, chi tiết lịch hẹn, các tab và màn hình chính
```

Màn hình chính của module: `InteractionHomeScreen` (đổi giao diện theo vai trò: người thuê 4 tab, chủ trọ 3 tab, admin 2 tab).

## Màn hình theo layout mẫu của giáo viên (Câu 5)

Màn **Chi tiết lịch hẹn** (`screens/appointment_detail_screen.dart`) áp dụng layout mẫu "Phiên đấu giá":
ảnh phòng ở trên cùng, khối thông tin chính, đồng hồ đếm ngược tới giờ hẹn, lịch sử tin nhắn và nút hành động dạng viên thuốc.

Cách mở: tab **Liên hệ** > tab **Lịch hẹn** > bấm **Chi tiết** ở một thẻ lịch hẹn.

Các widget con của màn này nằm trong `widgets/`: `room_image_box.dart`, `appointment_info_card.dart`, `countdown_timer_box.dart`, `message_history_box.dart`, `pill_action_button.dart`.

## Gắn vào ứng dụng

**1. Tab "Liên Hệ" của `MainScreen`** (`lib/core/main_screen.dart`) – thay placeholder bằng màn hình chính của module:

```dart
import '../features/contact/screens/interaction_home_screen.dart';
// ...
const InteractionHomeScreen(),   // thay cho _PlaceholderTab(title: 'Liên Hệ')
```

**2. Trang chi tiết phòng** (người ghép trang chủ / chi tiết phòng) – chỉ cần truyền `roomId`:

```dart
import '../../contact/widgets/room_actions.dart';

ReviewList(roomId: room.id)        // điểm trung bình + danh sách đánh giá của phòng
ReportButton(roomId: room.id)      // nút "Báo cáo" bài đăng
RoomActionBar(roomId: room.id)     // thanh dưới cùng: Liên hệ + Đặt lịch
// hoặc lẻ từng nút: ContactButton(roomId: ...), BookingButton(roomId: ...)
```

**3. Điểm đánh giá cho trang chủ / tìm kiếm / gợi ý:**

```dart
final r = InteractionService.instance.ratingSummary(room.id);
// r.average (0.0 nếu chưa có), r.count
```

Ví dụ hoàn chỉnh xem `screens/room_demo_screens.dart` (trang chi tiết phòng mẫu).

## Điểm nối với các module khác

Hiện module chạy độc lập bằng **dữ liệu giả** để demo. Khi các module kia xong thì thay bằng dữ liệu thật qua các hàm sau trong `InteractionService`:

| Cần từ module          | Hàm / thuộc tính                   | Việc cần làm                                                           |
| :--------------------- | :--------------------------------- | :--------------------------------------------------------------------- |
| Đăng nhập & phân quyền | `switchUser(DemoUser)`             | Gọi sau khi đăng nhập thật (id, tên, số điện thoại, vai trò)           |
| Đăng nhập & phân quyền | `onLockUser`                       | Gán hàm khóa tài khoản; được gọi khi admin xác nhận báo cáo người dùng |
| Quản lý bài đăng       | `registerRoom(room, ownerId: ...)` | Đăng ký phòng thật (kèm id chủ trọ)                                    |
| Quản lý bài đăng       | `onHideRoom`                       | Gán hàm ẩn bài; được gọi khi admin xác nhận báo cáo bài đăng           |

**Thanh chọn vai trò ở đầu `InteractionHomeScreen` chỉ để demo** – bỏ đi khi đã có đăng nhập thật.

## Chạy thử và kiểm tra

```bash
flutter pub get
flutter test test/interaction_service_test.dart   # nghiệp vụ (không cần giao diện)
flutter test test/interaction_ui_test.dart        # các luồng giao diện chính
flutter test                                      # toàn bộ test, gồm cả test Generics
flutter run
```

## Hướng phát triển

- **Lưu dữ liệu lâu dài:** hiện dữ liệu nằm trong bộ nhớ nên tắt app là mất. Sẽ lưu xuống máy hoặc lên server khi nhóm có phần lưu trữ.
- **Tin nhắn thời gian thực:** cần server (ví dụ Firebase) để tin nhắn đến ngay mà không phải mở lại màn hình.
- **Thông báo đẩy:** báo cho người dùng khi có lịch hẹn hoặc tin nhắn mới.
- **Dùng dữ liệu thật:** thay dữ liệu giả bằng dữ liệu của các module khác, theo bảng ở mục "Điểm nối với các module khác".
