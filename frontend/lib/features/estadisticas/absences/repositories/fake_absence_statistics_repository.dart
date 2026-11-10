import '../../../../core/utils/uruguay_time.dart';
import '../models/absence_statistics.dart';
import 'absence_statistics_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. No depende de otro fake.
///
/// Devuelve siempre los mismos grupos, sin filtrar por fecha: solo repite el
/// período pedido (o el mes en curso del reloj si no se pidió ninguno). El
/// porcentaje es `(noAsistio + noSePresento) / total × 100`. Con total 0 no
/// divide y queda en 0 %. La respuesta se arma desde JSON, como llega del
/// servidor.
class FakeAbsenceStatisticsRepository implements AbsenceStatisticsRepository {
  FakeAbsenceStatisticsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static const _specialties = [
    _Group(
      id: 3,
      name: 'Cardiología',
      attended: 20,
      noShow: 2,
      missed: 1,
      notAttended: 2,
    ),
    _Group(
      id: 2,
      name: 'Pediatría',
      attended: 8,
      noShow: 0,
      missed: 0,
      notAttended: 2,
    ),
  ];

  static const _doctors = [
    _Group(
      id: 4,
      name: 'Carla',
      lastName: 'Méndez',
      attended: 6,
      noShow: 3,
      missed: 1,
      notAttended: 0,
    ),
    _Group(
      id: 8,
      name: 'Luis',
      lastName: 'Gómez',
      attended: 4,
      noShow: 0,
      missed: 0,
      notAttended: 1,
    ),
  ];

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Porcentaje entero cuando cae justo. Total 0 no divide.
  static ({int percentage, String text}) _rate(_Group group) {
    final total = group.total;
    if (total == 0) return (percentage: 0, text: '0 %');
    final numerator = group.noShow + group.missed;
    final percentage = numerator * 100 ~/ total;
    return (percentage: percentage, text: '$percentage %');
  }

  Map<String, dynamic> _item(_Group group) {
    final rate = _rate(group);
    return {
      'id': group.id,
      'nombre': group.name,
      'apellido': group.lastName,
      'atendidas': group.attended,
      'noAsistio': group.noShow,
      'noSePresento': group.missed,
      'noAtendidas': group.notAttended,
      'total': group.total,
      'porcentajeInasistencia': rate.percentage,
      'inasistencia': rate.text,
    };
  }

  @override
  Future<AbsenceStatistics> statistics({
    DateTime? from,
    DateTime? to,
    required AbsenceGrouping grouping,
  }) async {
    await Future<void>.delayed(latency);
    final now = UruguayTime.toUruguay(_clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    if (start.isAfter(end)) {
      throw const AbsenceStatisticsException(
        AbsenceStatisticsFailure.validation,
        'desde no puede ser posterior a hasta',
      );
    }
    final groups = switch (grouping) {
      AbsenceGrouping.specialty => _specialties,
      AbsenceGrouping.doctor => _doctors,
    };
    return AbsenceStatistics.fromJson({
      'desde': _day(start),
      'hasta': _day(end),
      'agruparPor': grouping.apiValue,
      'items': [for (final group in groups) _item(group)],
    });
  }
}

class _Group {
  const _Group({
    required this.id,
    required this.name,
    this.lastName,
    required this.attended,
    required this.noShow,
    required this.missed,
    required this.notAttended,
  });

  final int id;
  final String name;
  final String? lastName;
  final int attended;
  final int noShow;
  final int missed;
  final int notAttended;

  int get total => attended + noShow + missed + notAttended;
}
