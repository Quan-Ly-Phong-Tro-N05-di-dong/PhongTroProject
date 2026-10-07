# Ứng Dụng Quản Lý & Tìm Kiếm Phòng Trọ

Hệ thống hỗ trợ tìm kiếm, quản lý bài đăng và kết nối thuê phòng trọ, được phát triển trên nền tảng Flutter theo kiến trúc Feature-First.

---

## Phân Chia Module & Trách Nhiệm

Dự án áp dụng mô hình Feature-First. Mỗi thành viên chịu trách nhiệm độc lập trên một module tương ứng trong thư mục `lib/features/`:

| Module | Đường dẫn thư mục | Chức năng chính | Người phụ trách |
| :--- | :--- | :--- | :--- |
| **Auth** | `lib/features/auth/` | Đăng nhập (email, Google), phân quyền (Admin / Chủ trọ / Khách thuê) | Le Thi Phuong Anh |
| **Home Catalog** | `lib/features/home_catalog/` | Khám phá, tìm kiếm, bộ lọc & gợi ý phòng trọ | Tên Thành Viên 2 |
| **Manage Posts** | `lib/features/manage_posts/` | Tạo, chỉnh sửa, xóa và quản lý trạng thái tin đăng | Tên Thành Viên 3 |
| **Contact** | `lib/features/contact/` | Liên hệ trực tiếp, nhắn tin & đặt lịch hẹn xem phòng | Tên Thành Viên 4 |

---

## Cấu Trúc Thư Mục Chuẩn

```text
lib/
├── core/                  # Cấu hình dùng chung (Network, Theme, Constants, Widgets dùng chung)
│   ├── routes/            # Cấu hình App Route chung
│   └── main_screen.dart   # Shell điều hướng chính (BottomNavigationBar)
├── features/              # Chia theo module tính năng độc lập
│   ├── auth/
│   │   ├── data/          # AuthService: đăng nhập, đăng ký, phân quyền (Firebase)
│   │   ├── models/        # AppUser, UserRole
│   │   ├── screens/       # Đăng nhập, đăng ký, quên mật khẩu, tài khoản, quản lý người dùng
│   │   ├── utils/         # Validators
│   │   └── widgets/       # RoleGuard, ô nhập, nút dùng chung
│   ├── contact/
│   ├── home_catalog/
│   └── manage_posts/
├── main.dart              # Entry point của ứng dụng
└── routers.dart
```

[!IMPORTANT]
### Lưu Ý Quan Trọng
1. Tuyệt đối không tự ý chỉnh sửa `lib/main.dart` và `lib/core/routes/`. Mọi thay đổi cấu hình toàn cục phải thảo luận trước với cả nhóm.
2. Test code chạy được trước khi push
3. Nên kiểm tra và pull code mới nhất (nếu có) trước khi bắt đầu code :D

---

## Cài Đặt & Chạy Dự Án

Dự án dùng **Firebase** (project `phongtroproject-77ddf`): Authentication để đăng nhập, Firestore để lưu dữ liệu.
Các file cấu hình `lib/firebase_options.dart`, `android/app/google-services.json` đã có sẵn trong dự án, **không cần chạy lại `flutterfire configure`**.

### Lần đầu
1. Bật **Developer Mode** trên Windows (bắt buộc để build plugin): chạy `start ms-settings:developers` → bật *Developer Mode*.
2. Cài thư viện:
   ```powershell
   flutter pub get
   ```
3. Chạy trên Chrome:
   ```powershell
   flutter run -d chrome
   ```

### Chạy trên Android // khong can thiet lam vi ca nhom deu chay tren chrome
- Nếu gặp lỗi *"An Application Control policy has blocked this file"*: tắt **Smart App Control** (Windows Security → App & browser control → Smart App Control settings → Off).
- **Đăng nhập Google trên Android** cần đăng ký mã SHA-1 của **từng máy**:
  1. Chạy app trên máy ảo ít nhất 1 lần.
  2. Lấy SHA-1:
     ```powershell
     & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
     ```
  3. Gửi dòng `SHA1: ...` cho người quản lý Firebase để thêm vào *Project settings → Your apps → Android → Add fingerprint*.

### Quyền truy cập Firebase Console
Nhờ người quản lý thêm email của bạn vào *Project settings → Users and permissions* để xem dữ liệu và deploy rules.

---

## Firebase

### Dữ liệu
| Collection | Module | Nội dung |
| :--- | :--- | :--- |
| `users/{uid}` | Auth | `fullName`, `email`, `phone` (có thể null), `role` (`admin` / `landlord` / `tenant`), `disabled`, `createdAt` |

Khi tạo collection mới, hãy bổ sung vào bảng này.

### Firestore Rules
Rules nằm trong file [`firestore.rules`](firestore.rules). **Không sửa rules trực tiếp trên Firebase Console** (sẽ bị ghi đè ở lần deploy sau).

Cập nhật rules:
1. Sửa file `firestore.rules`.
2. Deploy (cần cài `npm install -g firebase-tools` và `firebase login` trước):
   ```powershell
   firebase deploy --only firestore:rules
   ```
   Nếu sai cú pháp, lệnh sẽ báo lỗi kèm số dòng và **không** đẩy lên.

Hiện tại các collection ngoài `users` dùng quy tắc tạm: **ai cũng đọc được, tài khoản đã đăng nhập (không bị khóa) mới ghi được**. Khi làm module của mình, hãy thêm rules riêng phía trên đoạn *"Tạm thời cho các module khác"* và loại collection đó khỏi quy tắc tạm, ví dụ cho bài đăng:
```
match /posts/{postId} {
  allow read: if true;
  allow create: if isActive() && myProfile().role == 'landlord'
    && request.resource.data.ownerId == request.auth.uid;
  allow update, delete: if isActive()
    && (resource.data.ownerId == request.auth.uid || isAdmin());
}

match /{collection}/{document=**} {
  allow read: if collection != 'users' && collection != 'posts';
  allow write: if collection != 'users' && collection != 'posts' && isActive();
}
```
Các hàm có sẵn trong rules: `signedIn()`, `isAdmin()`, `isActive()` (đăng nhập và không bị khóa), `myProfile()` (hồ sơ của người đang gọi).

---

## Hướng Dẫn Dùng Module Auth (cho các module khác)

Mọi thứ đi qua `AuthService.instance`. Import:
```dart
import 'package:flutter_application_test/features/auth/data/auth_service.dart';
import 'package:flutter_application_test/features/auth/models/app_user.dart';
import 'package:flutter_application_test/features/auth/widgets/role_guard.dart';
import 'package:flutter_application_test/features/auth/screens/login_screen.dart';
```

### Vai trò
| `UserRole` | Hiển thị | Cách có |
| :--- | :--- | :--- |
| `UserRole.tenant` | Khách thuê | Tự chọn khi đăng ký |
| `UserRole.landlord` | Chủ trọ | Tự chọn khi đăng ký |
| `UserRole.admin` | Quản trị viên | Admin khác cấp trong *Tài khoản → Quản lý người dùng*. Admin đầu tiên: sửa `role` thành `admin` trực tiếp trên Firestore Console |

### Lấy người dùng đang đăng nhập
```dart
final AppUser? user = AuthService.instance.currentUser.value; // null = chưa đăng nhập

user?.id;          // uid, dùng làm ownerId / senderId khi lưu dữ liệu
user?.fullName;
user?.email;
user?.phone;       // có thể null
user?.role;        // UserRole
user?.isAdmin;     // cũng có isLandlord, isTenant
user?.hasAnyRole([UserRole.landlord, UserRole.admin]);
```

### Giao diện tự cập nhật khi đăng nhập / đăng xuất / đổi vai trò
```dart
ValueListenableBuilder<AppUser?>(
  valueListenable: AuthService.instance.currentUser,
  builder: (context, user, _) {
    if (user?.isLandlord == true) {
      return const Text('Nút Đăng tin chỉ chủ trọ thấy');
    }
    return const SizedBox.shrink();
  },
)
```

### Chặn cả màn hình theo vai trò: `RoleGuard`
```dart
// Chỉ chủ trọ và admin vào được
RoleGuard(
  allowed: [UserRole.landlord, UserRole.admin],
  child: ManagePostsScreen(),
)

// Chỉ cần đăng nhập, vai trò nào cũng được
RoleGuard(child: ChatScreen())
```
Chưa đăng nhập → hiện nút Đăng nhập. Sai vai trò → hiện "Bạn không có quyền truy cập".

### Yêu cầu đăng nhập trước một hành động (ví dụ bấm "Liên hệ")
```dart
void _onContactPressed() {
  final user = AuthService.instance.currentUser.value;
  if (user == null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return;
  }
  // ... xử lý liên hệ với user.id
}
```

### Lưu ý
- **Luôn kiểm tra quyền ở cả hai nơi:** trong app (RoleGuard / `user.role`) để ẩn giao diện, và trong `firestore.rules` để chặn thật. Kiểm tra trong app có thể bị vượt qua.
- Admin có thể **khóa tài khoản** (`disabled = true`): người bị khóa tự bị đăng xuất, không đăng nhập lại được và không ghi được dữ liệu.
- Không gọi trực tiếp `FirebaseAuth.instance` trong module khác, hãy dùng `AuthService` để trạng thái đăng nhập luôn đồng bộ.

## Giao diện demo ứng dụng
![Giao diện trang chủ và tìm kiếm](assets/home.png)