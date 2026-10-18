// lib/features/contact/models/contact_models.dart
// Gom các model của module Contact + hàm đăng ký với EntityRegistry.
import '../../../core/base/entity_registry.dart';
import 'appointment.dart';
import 'contact.dart';
import 'report.dart';
import 'review.dart';

export 'appointment.dart';
export 'contact.dart';
export 'report.dart';
export 'review.dart';

/// Đăng ký 4 model của module Contact (gọi 1 lần lúc khởi động app).
void registerContactModels() {
  EntityRegistry.register<Contact>(Contact.fromJson, name: 'contacts');
  EntityRegistry.register<Appointment>(Appointment.fromJson, name: 'appointments');
  EntityRegistry.register<Review>(Review.fromJson, name: 'reviews');
  EntityRegistry.register<Report>(Report.fromJson, name: 'reports');
}
