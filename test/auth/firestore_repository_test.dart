// test/auth/firestore_repository_test.dart
// Chạy: flutter test test/auth/firestore_repository_test.dart
import 'package:flutter_application_test/features/auth/data/firestore_repository.dart';
import 'package:flutter_application_test/features/auth/models/avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeCollection collection;
  late FirestoreRepository<Avatar> repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    collection = firestore.collection('avatars');
    repo = FirestoreRepository<Avatar>(
      collectionPath: 'avatars',
      fromMap: Avatar.fromMap,
      toMap: (avatar) => avatar.toMap(),
      firestore: firestore,
    );
  });

  test('get trả về đối tượng, kèm id lấy từ document', () async {
    collection.seed('u1', {'data': 'abc'});
    final avatar = await repo.get('u1');
    expect(avatar?.userId, 'u1');
    expect(avatar?.data, 'abc');
  });

  test('get trả về null khi document không tồn tại', () async {
    expect(await repo.get('u1'), isNull);
  });

  test('watch phát giá trị hiện tại rồi phát lại khi thêm, sửa, xóa', () async {
    collection.seed('u1', {'data': 'a'});
    final seen = <String?>[];
    final subscription = repo.watch('u1').listen((avatar) => seen.add(avatar?.data));
    addTearDown(subscription.cancel);
    await settle();

    collection.seed('u1', {'data': 'b'});
    await settle();
    collection.remove('u1');
    await settle();

    expect(seen, ['a', 'b', null]);
  });

  group('watchAll', () {
    setUp(() {
      collection.seed('u1', {'data': 'b', 'at': 2});
      collection.seed('u2', {'data': 'a', 'at': 1});
      collection.seed('u3', {'data': 'c', 'at': 3});
    });

    Future<List<String>> ids({String? orderBy, bool descending = false}) async {
      final list = await repo.watchAll(orderBy: orderBy, descending: descending).first;
      return list.map((a) => a.userId).toList();
    }

    test('không sắp xếp thì trả về toàn bộ', () async {
      expect(await ids(), unorderedEquals(['u1', 'u2', 'u3']));
    });

    test('sắp xếp tăng dần theo trường', () async {
      expect(await ids(orderBy: 'at'), ['u2', 'u1', 'u3']);
    });

    test('sắp xếp giảm dần theo trường', () async {
      expect(await ids(orderBy: 'at', descending: true), ['u3', 'u1', 'u2']);
    });
  });

  test('set ghi đối tượng kèm extraFields', () async {
    await repo.set('u1', const Avatar(userId: 'u1', data: 'abc'), extraFields: {'at': 1});
    expect(collection.docs['u1'], {'data': 'abc', 'at': 1});
  });

  test('set ghi đè document cũ', () async {
    collection.seed('u1', {'data': 'old', 'at': 1});
    await repo.set('u1', const Avatar(userId: 'u1', data: 'new'));
    expect(collection.docs['u1'], {'data': 'new'});
  });

  test('update chỉ sửa các trường được truyền', () async {
    collection.seed('u1', {'data': 'old', 'at': 1});
    await repo.update('u1', {'data': 'new'});
    expect(collection.docs['u1'], {'data': 'new', 'at': 1});
  });

  test('update báo lỗi khi document không tồn tại', () {
    expect(repo.update('u1', {'data': 'new'}), throwsA(anything));
  });

  test('delete xóa document', () async {
    collection.seed('u1', {'data': 'abc'});
    await repo.delete('u1');
    expect(collection.docs, isEmpty);
  });

  test('lỗi từ Firestore được truyền nguyên cho nơi gọi', () {
    final error = firestoreError();
    collection
      ..readError = error
      ..writeError = error;
    expect(repo.get('u1'), throwsA(error));
    expect(repo.set('u1', const Avatar(userId: 'u1', data: 'a')), throwsA(error));
    expect(repo.delete('u1'), throwsA(error));
  });
}
