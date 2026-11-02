// lib/features/auth/data/auth_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/avatar.dart';
import 'firestore_repository.dart';

// Lỗi nghiệp vụ, message hiển thị trực tiếp cho người dùng
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

// Xác thực bằng Firebase Authentication, thông tin và vai trò lưu ở Firestore: users/{uid}
class AuthService {
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cùng một class generic FirestoreRepository<T>, dùng cho 2 loại đối tượng khác nhau
  final _userRepo = FirestoreRepository<AppUser>(
    collectionPath: 'users',
    fromMap: AppUser.fromMap,
    toMap: (user) => user.toMap(),
  );
  final _avatarRepo = FirestoreRepository<Avatar>(
    collectionPath: 'avatars',
    fromMap: Avatar.fromMap,
    toMap: (avatar) => avatar.toMap(),
  );

  final _currentUser = ValueNotifier<AppUser?>(null);
  final _authReady = ValueNotifier<bool>(false);
  final _authReadyCompleter = Completer<void>();
  StreamSubscription<AppUser?>? _profileSubscription;
  bool _googleInitialized = false;

  AuthService._() {
    _auth.setLanguageCode('vi'); // Email đặt lại mật khẩu bằng tiếng Việt
    // Firebase tự nhớ phiên đăng nhập, mở lại app sẽ tự đăng nhập lại
    _auth.authStateChanges().listen(_onAuthStateChanged);
    // Mạng chậm cũng không để màn hình chờ mãi
    Timer(const Duration(seconds: 10), _markAuthReady);
  }

  // Người dùng đang đăng nhập (null = chưa đăng nhập). Dùng ValueListenableBuilder để lắng nghe.
  ValueListenable<AppUser?> get currentUser => _currentUser;

  // false = mới mở app, chưa biết người dùng đã đăng nhập hay chưa
  ValueListenable<bool> get isAuthReady => _authReady;

  // Hoàn thành khi đã biết trạng thái đăng nhập lúc mở app
  Future<void> get whenAuthReady => _authReadyCompleter.future;

  void _markAuthReady() {
    if (_authReady.value) return;
    _authReady.value = true;
    _authReadyCompleter.complete();
  }

  void _onAuthStateChanged(User? firebaseUser) {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    if (firebaseUser == null) {
      _currentUser.value = null;
      _markAuthReady();
      return;
    }
    // Theo dõi hồ sơ theo thời gian thực: admin đổi vai trò hoặc khóa tài khoản thì app cập nhật ngay.
    // Khi vừa đăng ký, document có thể chưa được ghi xong; register() sẽ tự cập nhật _currentUser.
    _profileSubscription = _userRepo.watch(firebaseUser.uid).listen(
      (profile) {
        if (profile == null) {
          _markAuthReady();
          return;
        }
        if (profile.disabled) {
          logout(); // authStateChanges sẽ báo null và đánh dấu đã sẵn sàng
        } else {
          _currentUser.value = profile;
          _markAuthReady();
        }
      },
      onError: (_) => _markAuthReady(), // Bỏ qua lỗi quyền truy cập ngay sau khi đăng xuất
    );
  }

  // Tài khoản Auth vừa tạo nhưng chưa có hồ sơ: xóa đi để người dùng đăng ký lại được bằng email đó
  Future<void> _rollbackRegistration(User firebaseUser) async {
    try {
      await firebaseUser.delete();
    } catch (e) {
      debugPrint('Không xóa được tài khoản ${firebaseUser.uid}: $e');
      await _signOutQuietly();
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await logout();
    } catch (e) {
      debugPrint('Không đăng xuất được: $e');
    }
  }

  // Ném lỗi nếu tài khoản bị khóa
  Future<void> _ensureNotDisabled(AppUser profile) async {
    if (profile.disabled) {
      await logout();
      throw const AuthException('Tài khoản của bạn đã bị khóa, vui lòng liên hệ quản trị viên');
    }
  }

  Future<AppUser?> _loadProfile(String uid) => _userRepo.get(uid);

  Future<AppUser> _saveProfile(AppUser user) async {
    await _userRepo.set(
      user.id,
      user,
      extraFields: {'createdAt': FieldValue.serverTimestamp()},
    );
    _currentUser.value = user;
    return user;
  }

  // Chuyển mọi lỗi thành AuthException để màn hình hiển thị
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Đã hủy đăng nhập bằng Google');
      }
      throw AuthException('Đăng nhập Google thất bại: ${e.description ?? e.code.name}');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } on FirebaseException catch (e) {
      // Lỗi Firestore, ví dụ permission-denied khi Rules chặn
      throw AuthException('Lỗi máy chủ (${e.code})');
    } catch (e) {
      debugPrint('Lỗi không xác định trong AuthService: $e');
      throw const AuthException('Đã có lỗi xảy ra, vui lòng thử lại');
    }
  }

  Future<AppUser> login({required String email, required String password}) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final profile = await _loadProfile(credential.user!.uid);
      if (profile == null) {
        await _auth.signOut();
        throw const AuthException('Không tìm thấy thông tin tài khoản');
      }
      await _ensureNotDisabled(profile);
      _currentUser.value = profile;
      return profile;
    });
  }

  // chooseRole chỉ được gọi khi tài khoản Google đăng nhập lần đầu,
  // trả về null nghĩa là người dùng hủy.
  Future<AppUser> signInWithGoogle({required Future<UserRole?> Function() chooseRole}) {
    return _guard(() async {
      final User firebaseUser;
      if (kIsWeb) {
        // Trên web dùng popup của Firebase
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        firebaseUser = result.user!;
      } else {
        if (!_googleInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleInitialized = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final credential = GoogleAuthProvider.credential(
          idToken: account.authentication.idToken,
        );
        firebaseUser = (await _auth.signInWithCredential(credential)).user!;
      }

      final existing = await _loadProfile(firebaseUser.uid);
      if (existing != null) {
        await _ensureNotDisabled(existing);
        _currentUser.value = existing;
        return existing;
      }

      // Lần đầu đăng nhập: hỏi vai trò rồi tạo hồ sơ
      final role = await chooseRole();
      if (role == null) {
        await logout();
        throw const AuthException('Đã hủy đăng nhập bằng Google');
      }
      try {
        return await _saveProfile(AppUser(
          id: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? firebaseUser.email ?? 'Người dùng',
          email: firebaseUser.email ?? '',
          phone: firebaseUser.phoneNumber,
          role: role,
        ));
      } catch (_) {
        // Lần đăng nhập sau sẽ hỏi lại vai trò và tạo hồ sơ
        await _signOutQuietly();
        rethrow;
      }
    });
  }

  Future<AppUser> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    required UserRole role,
  }) {
    return _guard(() async {
      // Không cho tự đăng ký tài khoản admin
      if (role == UserRole.admin) {
        throw const AuthException('Không thể đăng ký tài khoản quản trị viên');
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user!;
      try {
        await firebaseUser.updateDisplayName(fullName.trim());
        final trimmedPhone = phone?.trim();
        return await _saveProfile(AppUser(
          id: firebaseUser.uid,
          fullName: fullName.trim(),
          email: email.trim().toLowerCase(),
          phone: (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone,
          role: role,
        ));
      } catch (_) {
        await _rollbackRegistration(firebaseUser);
        rethrow;
      }
    });
  }

  Future<void> sendPasswordReset({required String email}) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  // false = tài khoản chỉ đăng nhập bằng Google, không có mật khẩu để đổi
  bool get hasPassword {
    final providers = _auth.currentUser?.providerData ?? const <UserInfo>[];
    return providers.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID);
  }

  // Tự sửa họ tên và số điện thoại. Vai trò và trạng thái khóa do admin quản lý.
  // _currentUser tự cập nhật theo hồ sơ đang được theo dõi ở _onAuthStateChanged.
  Future<void> updateProfile({required String fullName, String? phone}) {
    return _guard(() async {
      final uid = _currentUser.value?.id;
      if (uid == null) throw const AuthException('Bạn cần đăng nhập');
      final trimmedPhone = phone?.trim();
      await _userRepo.update(uid, {
        'fullName': fullName.trim(),
        'phone': (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone,
      });
    });
  }

  // ===== Dành cho admin. Firestore Rules cũng chặn nếu người gọi không phải admin. =====

  void _ensureAdmin() {
    if (_currentUser.value?.isAdmin != true) {
      throw const AuthException('Bạn không có quyền thực hiện thao tác này');
    }
  }

  // Danh sách toàn bộ người dùng, tự cập nhật khi có thay đổi
  Stream<List<AppUser>> watchAllUsers() {
    return _userRepo.watchAll(orderBy: 'createdAt', descending: true);
  }

  Future<void> updateRole(String uid, UserRole role) {
    return _guard(() async {
      _ensureAdmin();
      if (uid == _currentUser.value!.id) {
        throw const AuthException('Không thể tự đổi vai trò của chính mình');
      }
      await _userRepo.update(uid, {'role': role.name});
    });
  }

  Future<void> setDisabled(String uid, bool disabled) {
    return _guard(() async {
      _ensureAdmin();
      if (uid == _currentUser.value!.id) {
        throw const AuthException('Không thể tự khóa tài khoản của chính mình');
      }
      await _userRepo.update(uid, {'disabled': disabled});
    });
  }

  // ===== Ảnh đại diện (Base64, lưu ở avatars/{uid}) =====

  // Theo dõi ảnh đại diện của một người, trả về chuỗi base64 hoặc null
  Stream<String?> watchAvatar(String uid) {
    return _avatarRepo.watch(uid).map((avatar) => avatar?.data);
  }

  Future<void> updateAvatar(String base64) {
    return _guard(() async {
      final uid = _currentUser.value?.id;
      if (uid == null) throw const AuthException('Bạn cần đăng nhập');
      await _avatarRepo.set(
        uid,
        Avatar(userId: uid, data: base64),
        extraFields: {'updatedAt': FieldValue.serverTimestamp()},
      );
    });
  }

  Future<void> removeAvatar() {
    return _guard(() async {
      final uid = _currentUser.value?.id;
      if (uid == null) return;
      await _avatarRepo.delete(uid);
    });
  }

  Future<void> logout() async {
    if (!kIsWeb && _googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email hoặc mật khẩu không đúng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu, hãy dùng ít nhất 6 ký tự';
      case 'permission-denied':
        return 'Tài khoản đã bị khóa';
      case 'too-many-requests':
        return 'Bạn thử quá nhiều lần, vui lòng thử lại sau';
      case 'network-request-failed':
        return 'Không có kết nối mạng';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Đã hủy đăng nhập bằng Google';
      case 'account-exists-with-different-credential':
        return 'Email này đã đăng ký bằng mật khẩu, vui lòng đăng nhập bằng email';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật trên Firebase';
      case 'configuration-not-found':
        return 'Firebase Authentication chưa được bật cho project';
      default:
        return 'Đã có lỗi xảy ra (${e.code})';
    }
  }
}
