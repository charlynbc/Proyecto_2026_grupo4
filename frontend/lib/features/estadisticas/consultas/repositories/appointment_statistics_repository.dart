import '../../../../core/network/api_exception.dart';
import '../models/appointment_statistics.dart';

abstract class AppointmentStatisticsRepository {
  /// Las consultas por estado entre [from] y [to] (inclusivos). Sin alguna de
  /// las dos fechas, el servidor usa el límite del mes en curso.
  Future<AppointmentStatistics> statistics({DateTime? from, DateTime? to});
}

enum AppointmentStatisticsFailure {
  unauthenticated,
  forbidden,
  validation,
  other,
}

class AppointmentStatisticsException extends ApiException {
  const AppointmentStatisticsException(this.failure, [super.message]);

  final AppointmentStatisticsFailure failure;
}
