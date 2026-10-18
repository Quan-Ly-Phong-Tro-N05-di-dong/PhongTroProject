// tool/demo_generics.dart
// Chạy thử (không cần emulator):  dart run tool/demo_generics.dart
// Dùng để chụp ảnh màn hình kết quả cho bài tập Generics.
// ignore_for_file: avoid_print
import 'package:flutter_application_test/core/base/base_entity.dart';
import 'package:flutter_application_test/core/base/entity_registry.dart';
import 'package:flutter_application_test/core/base/repository.dart';
import 'package:flutter_application_test/features/contact/models/contact_models.dart';
import 'package:flutter_application_test/features/home_catalog/models/room_item.dart';

void main() {
  registerRoomModels();
  registerContactModels();

  // Cùng 1 lớp Repository<T> dùng cho 5 loại đối tượng khác nhau.
  final rooms = Repository<RoomItem>();
  final contacts = Repository<Contact>();
  final appointments = Repository<Appointment>();
  final reviews = Repository<Review>();
  final reports = Repository<Report>();

  _title('1. Repository<T> dùng chung cho mọi đối tượng');
  final room = rooms.add(const RoomItem(
    id: '1',
    title: 'Phòng trọ khép kín gần ĐH Phenikaa',
    address: 'Yên Nghĩa, Hà Đông, Hà Nội',
    price: 2.8,
    area: 25,
    imageUrl: 'https://example.com/room1.jpg',
  ));

  final contact = contacts.add(Contact(
    id: contacts.nextId(),
    roomId: room.id,
    senderId: 'u2',
    ownerId: 'u5',
    message: 'Phòng còn trống không ạ?',
  ));
  contact.replyWith('Còn nhé, bạn qua xem được.');
  contacts.update(contact);

  final appt = appointments.add(Appointment.book(
    id: appointments.nextId(),
    roomId: room.id,
    tenantId: 'u2',
    ownerId: 'u5',
    time: DateTime.now().add(const Duration(days: 1)),
    note: 'Xem phòng sau giờ học',
  ));
  appt.confirm();
  appt.complete();
  appointments.update(appt);

  final review = reviews.add(Review.forAppointment(
    appt,
    id: reviews.nextId(),
    rating: 5,
    comment: 'Phòng sạch, chủ trọ nhiệt tình',
  ));

  final report = reports.add(Report(
    id: reports.nextId(),
    reporterId: 'u2',
    targetType: ReportTarget.review,
    targetId: review.id,
    reason: 'Nội dung spam',
  ));
  report.resolve(adminId: 'admin1', note: 'Đã kiểm tra, không vi phạm');
  reports.update(report);

  _printRepo(rooms);
  _printRepo(contacts);
  _printRepo(appointments);
  _printRepo(reviews);
  _printRepo(reports);

  _title('2. Object.runtimeType (Type) + EntityRegistry');
  final all = <BaseEntity<String>>[room, contact, appt, review, report];
  for (final e in all) {
    print('${e.runtimeType.toString().padRight(12)} id=${e.id}  '
        '-> bảng "${EntityRegistry.nameOfType(e.runtimeType)}"');
  }

  _title('3. Object.==, hashCode, toString đã ghi đè ở BaseEntity');
  final copy = Contact.fromJson(contact.toJson());
  print('copy == contact          : ${copy == contact}   (cùng kiểu + cùng id)');
  print('identical(copy, contact) : ${identical(copy, contact)}  (2 object khác nhau trong bộ nhớ)');
  print('contact == appt          : ${contact == appt}  (cùng id "${contact.id}" nhưng khác kiểu)');
  print('Set<BaseEntity> chứa {contact, copy} -> ${<BaseEntity<String>>{contact, copy}.length} phần tử');
  print('toString: $contact');

  _title('4. Hàm generic dùng EntityRegistry theo kiểu T');
  final reviewCopy = _clone(review);
  print('_clone(review) -> ${reviewCopy.runtimeType}, bằng review gốc: ${reviewCopy == review}');
  final apptCopy = _clone(appt);
  print('_clone(appt)   -> ${apptCopy.runtimeType}, status: ${apptCopy.status.name}');

  _title('5. Số liệu tổng hợp đánh giá (cho trang chủ / gợi ý)');
  print(Review.summarize(reviews.findAll()));

  _title('6. Quy tắc nghiệp vụ được chặn đúng');
  _expectError('Tự liên hệ phòng của mình', () {
    Contact(id: 'x', roomId: '1', senderId: 'u5', ownerId: 'u5', message: 'hi');
  });
  _expectError('Đặt lịch trong quá khứ', () {
    Appointment.book(
      id: 'x',
      roomId: '1',
      tenantId: 'u2',
      ownerId: 'u5',
      time: DateTime.now().subtract(const Duration(hours: 1)),
    );
  });
  final pending = appointments.add(Appointment.book(
    id: appointments.nextId(),
    roomId: room.id,
    tenantId: 'u3',
    ownerId: 'u5',
    time: DateTime.now().add(const Duration(days: 2)),
  ));
  _expectError('Đánh giá khi lịch chưa hoàn thành', () {
    Review.forAppointment(pending, id: 'x', rating: 4);
  });
  _expectError('Số sao ngoài 1-5', () {
    review.edit(rating: 9);
  });
  _expectError('Hoàn thành lịch chưa được xác nhận', pending.complete);
}

/// Hàm generic: sao chép đối tượng bất kỳ qua JSON, kiểu T suy ra lúc chạy.
T _clone<T extends BaseEntity>(T entity) =>
    EntityRegistry.fromJson<T>(entity.toJson());

void _printRepo<T extends BaseEntity<String>>(Repository<T> repo) {
  print('• Repository<$T> "${repo.name}" có ${repo.count} phần tử');
  for (final item in repo.findAll()) {
    print('    ${item.runtimeType}#${item.id}');
  }
}

void _title(String text) {
  print('');
  print('=== $text ===');
}

void _expectError(String label, void Function() action) {
  try {
    action();
    print('✗ $label: KHÔNG báo lỗi (sai!)');
  } catch (e) {
    print('✓ $label -> $e');
  }
}
