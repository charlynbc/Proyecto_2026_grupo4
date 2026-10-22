import '../../../core/network/api_exception.dart';
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';

abstract class AppointmentHistoryRepository {
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query);

  Future<Appointment> get(int id);
}

enum AppointmentHistoryFailure { unauthenticated, forbidden, notFound, other }

class AppointmentHistoryException extends ApiException {
  const AppointmentHistoryException(this.failure, [super.message]);

  final AppointmentHistoryFailure failure;
}
