import '../../../../core/network/api_exception.dart';
import '../models/shift_utilization.dart';

abstract class ShiftStatisticsRepository {
  /// La utilización de cada turno semanal entre [from] y [to] (inclusivos).
  /// Sin alguna de las dos fechas, el servidor usa el límite del mes en curso.
  Future<ShiftUtilization> utilization({DateTime? from, DateTime? to});
}

enum ShiftStatisticsFailure { unauthenticated, forbidden, validation, other }

class ShiftStatisticsException extends ApiException {
  const ShiftStatisticsException(this.failure, [super.message]);

  final ShiftStatisticsFailure failure;
}
