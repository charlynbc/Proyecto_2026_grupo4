import '../../../../core/utils/uruguay_time.dart';
import '../models/appointment_statistics.dart';
import 'appointment_statistics_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. Devuelve siempre el
/// ejemplo del contrato, salvo con un período de un solo día (Desde igual a
/// Hasta), que devuelve todo en cero. No filtra por otra cosa: repite el
/// período pedido (o el mes en curso del reloj si no se pidió ninguno). La
/// respuesta se arma desde JSON, como llega del servidor, así que el `10`
/// entero pasa por la misma lectura que la respuesta real.
class FakeAppointmentStatisticsRepository
    implements AppointmentStatisticsRepository {
  FakeAppointmentStatisticsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<AppointmentStatistics> statistics({
    DateTime? from,
    DateTime? to,
  }) async {
    await Future<void>.delayed(latency);
    final now = UruguayTime.toUruguay(_clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    if (start.isAfter(end)) {
      throw const AppointmentStatisticsException(
        AppointmentStatisticsFailure.validation,
        'desde no puede ser posterior a hasta',
      );
    }
    final oneDay = start == end;
    return AppointmentStatistics.fromJson({
      'desde': _day(start),
      'hasta': _day(end),
      'estados': <String, dynamic>{
        'AGENDADA': oneDay ? 0 : 40,
        'ATENDIDA': oneDay ? 0 : 110,
        'CANCELADA_SOCIO': oneDay ? 0 : 20,
        'CANCELADA_INSTITUCION': oneDay ? 0 : 8,
        'NO_ASISTIO': oneDay ? 0 : 14,
        'NO_ATENDIDA': oneDay ? 0 : 5,
        'NO_SE_PRESENTO': oneDay ? 0 : 3,
      },
      'totalConsultas': oneDay ? 0 : 200,
      'canceladasPorSocio': oneDay ? 0 : 20,
      // Entero, como puede mandarlo el servidor.
      'porcentajeCancelacion': oneDay ? null : 10,
      'porcentajeCancelacionTexto': oneDay ? 'Sin datos' : '10 %',
    });
  }
}
