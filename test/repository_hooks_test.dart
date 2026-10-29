// test/repository_hooks_test.dart
// Kiểm tra phần nối Firebase mà không cần mạng:
//  - Repository: onSaved / onRemoved / replaceAll / idGenerator
//  - InteractionService: chế độ dữ liệu thật (startRemoteMode, idGenerator, ghi qua onSaved)
// Chạy: flutter test test/repository_hooks_test.dart
import 'package:flutter_application_test/core/base/repository.dart';
import 'package:flutter_application_test/features/contact/models/contact_models.dart';
import 'package:flutter_application_test/features/contact/services/interaction_service.dart';
import 'package:flutter_application_test/features/home_catalog/models/room_item.dart';
import 'package:flutter_test/flutter_test.dart';

Review _review(String id) => Review(
  id: id,
  roomId: 'r1',
  userId: 'u1',
  appointmentId: 'a$id',
  rating: 5,
);

void main() {
  setUpAll(() {
    registerRoomModels();
    registerContactModels();
  });

  group('Repository: móc ghi lên server', () {
    test('onSaved được gọi khi add và update', () {
      final repo = Repository<Review>();
      final saved = <String>[];
      repo.onSaved = (r) => saved.add('${r.id}:${r.rating}');

      final review = repo.add(_review('1'));
      review.edit(rating: 3);
      repo.update(review);

      expect(saved, ['1:5', '1:3']);
    });

    test('onRemoved chỉ được gọi khi xóa được thật', () {
      final repo = Repository<Review>();
      final removed = <String>[];
      repo.onRemoved = removed.add;
      repo.add(_review('1'));

      expect(repo.remove('1'), isTrue);
      expect(repo.remove('1'), isFalse);
      expect(removed, ['1']);
    });

    test('replaceAll thay toàn bộ dữ liệu và không gọi onSaved / onRemoved', () {
      final repo = Repository<Review>();
      repo.add(_review('1'));
      var calls = 0;
      repo.onSaved = (_) => calls++;
      repo.onRemoved = (_) => calls++;

      repo.replaceAll([_review('2'), _review('3')]);

      expect(repo.count, 2);
      expect(repo.findById('1'), isNull);
      expect(repo.findById('2'), isNotNull);
      expect(calls, 0);
    });

    test('idGenerator thay cho bộ đếm 1, 2, 3...', () {
      final repo = Repository<Review>();
      expect(repo.nextId(), '1');

      var n = 0;
      repo.idGenerator = () => 'id_${++n}';
      expect(repo.nextId(), 'id_1');
      expect(repo.nextId(), 'id_2');
    });
  });

  group('InteractionService: chế độ dữ liệu thật', () {
    test('startRemoteMode xóa sạch dữ liệu giả', () {
      final s = InteractionService(clock: () => DateTime(2026, 10, 22, 8));
      expect(s.isDemo, isTrue);
      expect(s.appointments.count, greaterThan(0));

      s.startRemoteMode();

      expect(s.isDemo, isFalse);
      expect(s.appointments.count, 0);
      expect(s.contacts.count, 0);
      expect(s.reviews.count, 0);
      expect(s.reports.count, 0);
      expect(s.rooms, isEmpty);
      expect(s.users, isEmpty);
    });

    test('mọi thay đổi nghiệp vụ đi qua onSaved và id tin nhắn dùng idGenerator', () {
      final s = InteractionService(clock: () => DateTime(2026, 10, 22, 8));
      s.startRemoteMode();
      s.registerRoom(
        const RoomItem(
          id: 'r1',
          title: 'Phòng thử',
          address: 'Hà Đông',
          price: 2,
          area: 20,
          imageUrl: '',
        ),
        ownerId: 'o1',
      );
      s.switchUser(
        const DemoUser(
          id: 't1',
          name: 'Người thuê',
          phone: '0900000000',
          role: UserRole.tenant,
        ),
      );
      var n = 0;
      s.idGenerator = () => 'gen_${++n}';
      final saved = <String>[];
      s.contacts.onSaved = (c) => saved.add('contact:${c.id}');
      s.appointments.onSaved = (a) => saved.add('appointment:${a.id}');

      final contact = s.sendToOwner(roomId: 'r1', text: 'Xin chào');
      s.sendMessage(contact.id, 'Phòng còn không ạ?');
      final appointment = s.book(
        roomId: 'r1',
        time: DateTime(2026, 10, 23, 9),
        phone: '0900000000',
      );

      expect(contact.messages.first.id, 'gen_1');
      expect(contact.messages.last.id, 'gen_2');
      expect(saved, [
        'contact:${contact.id}',
        'contact:${contact.id}',
        'appointment:${appointment.id}',
      ]);
    });
  });
}