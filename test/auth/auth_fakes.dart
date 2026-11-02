// test/auth/auth_fakes.dart
// Bản giả của Firebase Auth và Firestore, lưu dữ liệu trong bộ nhớ, không cần mạng.
// Firestore đánh dấu các class của nó là @sealed và @immutable nên phải tắt cảnh báo ở file này.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/features/auth/data/auth_service.dart';
import 'package:flutter_application_test/features/auth/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;
  FakeUserInfo(this.providerId);
}

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  String? displayName;
  @override
  final String? phoneNumber;
  final List<String> providers;

  FakeFirebaseAuth? owner;
  Object? deleteError;
  Object? updateNameError;
  bool deleted = false;

  FakeUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.providers = const ['password'],
  });

  @override
  List<UserInfo> get providerData => providers.map(FakeUserInfo.new).toList();

  @override
  Future<void> updateDisplayName(String? name) async {
    if (updateNameError != null) throw updateNameError!;
    displayName = name;
  }

  @override
  Future<void> delete() async {
    if (deleteError != null) throw deleteError!;
    deleted = true;
    owner?.removeAccount(this);
  }
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User user;
  FakeUserCredential(this.user);
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final _changes = StreamController<User?>();
  final _passwords = <String, String>{};
  final _accounts = <String, FakeUser>{};
  FakeUser? _current;

  @override
  String? languageCode;
  final resetEmails = <String>[];
  int signInCalls = 0;
  int registerCalls = 0;
  int signOutCalls = 0;

  Object? signInError;
  Object? registerError;
  Object? resetError;
  Object? signOutError;
  Object? newUserDeleteError;
  Object? newUserUpdateNameError;

  // Chưa hoàn thành thì lệnh đăng nhập còn treo, dùng để kiểm tra trạng thái đang tải
  Completer<void>? signInGate;

  // emitInitialState = false giả lập Firebase chưa trả lời, ví dụ mạng chậm
  FakeFirebaseAuth({FakeUser? signedIn, bool emitInitialState = true}) : _current = signedIn {
    signedIn?.owner = this;
    if (emitInitialState) _changes.add(signedIn);
  }

  void addAccount(FakeUser user, String password) {
    user.owner = this;
    _accounts[user.email!] = user;
    _passwords[user.email!] = password;
  }

  bool hasAccount(String email) => _accounts.containsKey(email);

  void removeAccount(FakeUser user) {
    _accounts.remove(user.email);
    _passwords.remove(user.email);
    if (identical(_current, user)) signInAs(null);
  }

  // Đổi người dùng hiện tại và báo qua authStateChanges như Firebase thật
  void signInAs(FakeUser? user) {
    user?.owner = this;
    _current = user;
    _changes.add(user);
  }

  @override
  User? get currentUser => _current;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  @override
  Future<void> setLanguageCode(String? code) async => languageCode = code;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInGate != null) await signInGate!.future;
    if (signInError != null) throw signInError!;
    if (_passwords[email] != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    final user = _accounts[email]!;
    signInAs(user);
    return FakeUserCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registerCalls++;
    if (registerError != null) throw registerError!;
    if (_accounts.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final user = FakeUser(uid: 'new-${_accounts.length + 1}', email: email)
      ..deleteError = newUserDeleteError
      ..updateNameError = newUserUpdateNameError;
    addAccount(user, password);
    signInAs(user);
    return FakeUserCredential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    signInAs(null);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    if (resetError != null) throw resetError!;
    resetEmails.add(email);
  }
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data == null ? null : Map.of(_data);
}

class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;
  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => Map.of(_data);
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  FakeQuerySnapshot(this.docs);
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final FakeCollection _collection;
  @override
  final String id;
  FakeDocumentReference(this._collection, this.id);

  FakeDocumentSnapshot _read() => FakeDocumentSnapshot(id, _collection.docs[id]);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (_collection.readError != null) throw _collection.readError!;
    return _read();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      _collection.live(_read);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (_collection.writeError != null) throw _collection.writeError!;
    _collection.seed(id, data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (_collection.writeError != null) throw _collection.writeError!;
    final current = _collection.docs[id];
    if (current == null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    _collection.seed(id, {...current, ...data.cast<String, dynamic>()});
  }

  @override
  Future<void> delete() async {
    if (_collection.writeError != null) throw _collection.writeError!;
    _collection.remove(id);
  }
}

class FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  final FakeCollection _collection;
  final String _field;
  final bool _descending;
  FakeQuery(this._collection, this._field, this._descending);

  FakeQuerySnapshot _read() {
    final entries = _collection.docs.entries.toList()
      ..sort((a, b) {
        final left = a.value[_field];
        final right = b.value[_field];
        if (left is! Comparable || right is! Comparable) return 0;
        return _descending ? right.compareTo(left) : left.compareTo(right);
      });
    return FakeQuerySnapshot(
      entries.map((e) => FakeQueryDocumentSnapshot(e.key, e.value)).toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      _collection.live(_read);
}

class FakeCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  final docs = <String, Map<String, dynamic>>{};
  final _changes = StreamController<void>.broadcast();

  Object? readError;
  Object? writeError;
  Object? watchError; // Giả lập listener bị Rules từ chối

  // Ghi trực tiếp, không qua lỗi giả lập. Dùng để chuẩn bị dữ liệu hoặc giả lập admin sửa.
  void seed(String id, Map<String, dynamic> data) {
    docs[id] = data;
    _changes.add(null);
  }

  void remove(String id) {
    docs.remove(id);
    _changes.add(null);
  }

  // Phát giá trị hiện tại, rồi phát lại mỗi khi dữ liệu đổi
  Stream<R> live<R>(R Function() read) {
    late final StreamController<R> controller;
    StreamSubscription<void>? subscription;
    void emit() {
      if (watchError != null) {
        controller.addError(watchError!);
      } else {
        controller.add(read());
      }
    }

    controller = StreamController<R>(
      onListen: () {
        emit();
        subscription = _changes.stream.listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => FakeDocumentReference(this, path!);

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) =>
      FakeQuery(this, field as String, descending);

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      live(() => FakeQuerySnapshot(
            docs.entries.map((e) => FakeQueryDocumentSnapshot(e.key, e.value)).toList(),
          ));
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final _collections = <String, FakeCollection>{};

  @override
  FakeCollection collection(String collectionPath) =>
      _collections.putIfAbsent(collectionPath, FakeCollection.new);
}

// Một AuthService thật chạy trên Firebase giả
class AuthHarness {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  late final FakeFirebaseAuth auth;
  late final AuthService service;

  // Tài khoản trả về khi bấm đăng nhập Google, thay cho SDK Google
  FakeUser? googleUser;
  Object? googleError;

  // signedInAs: mở app khi đã có phiên đăng nhập và hồ sơ của người này
  AuthHarness({
    AppUser? signedInAs,
    List<String> providers = const ['password'],
    bool emitInitialState = true,
  }) {
    if (signedInAs != null) seedUser(signedInAs);
    auth = FakeFirebaseAuth(
      signedIn: signedInAs == null
          ? null
          : FakeUser(uid: signedInAs.id, email: signedInAs.email, providers: providers),
      emitInitialState: emitInitialState,
    );
    service = AuthService.forTest(
      auth: auth,
      firestore: firestore,
      googleSignIn: () async {
        if (googleError != null) throw googleError!;
        auth.signInAs(googleUser);
        return googleUser!;
      },
    );
  }

  FakeCollection get users => firestore.collection('users');
  FakeCollection get avatars => firestore.collection('avatars');

  void seedUser(AppUser user, {Object? createdAt}) {
    users.seed(user.id, {...user.toMap(), 'createdAt': ?createdAt});
  }

  // Tạo tài khoản email kèm hồ sơ, chưa đăng nhập
  void addEmailAccount(AppUser user, String password) {
    auth.addAccount(FakeUser(uid: user.id, email: user.email), password);
    seedUser(user);
  }
}

AppUser makeUser({
  String id = 'u1',
  String fullName = 'An Nguyễn',
  String email = 'an@test.com',
  String? phone,
  UserRole role = UserRole.tenant,
  bool disabled = false,
}) =>
    AppUser(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      disabled: disabled,
    );

// Lỗi AuthException với đúng thông báo hiển thị cho người dùng
Matcher throwsAuth(String message) =>
    throwsA(isA<AuthException>().having((e) => e.message, 'message', message));

FirebaseException firestoreError([String code = 'permission-denied']) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

// Chờ các stream giả phát xong, dùng trong test không có WidgetTester
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// Màn hình đủ cao để mọi nút trong form đều nhìn thấy, không cần cuộn
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// Dùng harness này cho AuthService.instance, rồi hiển thị home
Future<void> pumpApp(WidgetTester tester, AuthHarness harness, Widget home) async {
  useTallScreen(tester);
  AuthService.instance = harness.service;
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
}

const openScreenLabel = 'Mở màn hình';

// Mở screen từ một trang khác, để kiểm tra được màn hình có tự đóng hay không
Future<void> openScreen(WidgetTester tester, AuthHarness harness, Widget screen) async {
  await pumpApp(
    tester,
    harness,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => screen),
          ),
          child: const Text(openScreenLabel),
        ),
      ),
    ),
  );
  await tester.tap(find.text(openScreenLabel));
  await tester.pumpAndSettle();
}

Finder fieldWithLabel(String label) => find.widgetWithText(TextFormField, label);

Finder submitButton(String label) => find.widgetWithText(ElevatedButton, label);
