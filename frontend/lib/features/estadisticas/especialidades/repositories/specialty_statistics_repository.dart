import '../../../../core/network/api_exception.dart';
import '../models/specialty_demand.dart';

abstract class SpecialtyStatisticsRepository {
  /// La demanda por especialidad entre [from] y [to] (inclusivos). Sin
  /// alguna de las dos fechas, el servidor usa el límite del mes en curso.
  Future<SpecialtyDemand> demand({DateTime? from, DateTime? to});
}

enum SpecialtyStatisticsFailure {
  unauthenticated,
  forbidden,
  validation,
  other,
}

class SpecialtyStatisticsException extends ApiException {
  const SpecialtyStatisticsException(this.failure, [super.message]);

  final SpecialtyStatisticsFailure failure;
}
