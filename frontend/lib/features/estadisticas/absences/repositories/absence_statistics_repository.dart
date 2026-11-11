import '../../../../core/network/api_exception.dart';
import '../models/absence_statistics.dart';

/// Cómo se agrupan las inasistencias. El valor que viaja en `agruparPor`
/// va siempre en mayúsculas, como lo pide la fila 69.
enum AbsenceGrouping {
  specialty,
  doctor;

  String get apiValue => switch (this) {
    AbsenceGrouping.specialty => 'ESPECIALIDAD',
    AbsenceGrouping.doctor => 'MEDICO',
  };
}

abstract class AbsenceStatisticsRepository {
  /// Inasistencias entre [from] y [to] (inclusivos), agrupadas por
  /// [grouping]. Sin alguna de las dos fechas, el servidor usa el límite
  /// del mes en curso.
  Future<AbsenceStatistics> statistics({
    DateTime? from,
    DateTime? to,
    required AbsenceGrouping grouping,
  });
}

enum AbsenceStatisticsFailure { unauthenticated, forbidden, validation, other }

class AbsenceStatisticsException extends ApiException {
  const AbsenceStatisticsException(this.failure, [super.message]);

  final AbsenceStatisticsFailure failure;
}

/// El 403 no muestra el texto del servidor: la pantalla usa este mensaje.
const String kAbsenceStatisticsForbiddenMessage =
    'Tu cuenta no tiene permiso para ver las estadísticas.';
