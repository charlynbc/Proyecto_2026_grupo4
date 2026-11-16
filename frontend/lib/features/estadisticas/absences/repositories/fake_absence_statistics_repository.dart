import '../../../../core/utils/uruguay_time.dart';
import '../models/absence_statistics.dart';
import 'absence_statistics_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. No depende de otro fake.
///
/// Devuelve siempre los mismos grupos, sin filtrar por fecha: solo repite el
/// período pedido (o el mes en curso del reloj si no se pidió ninguno). Un
/// grupo sin consultas no aparece. El porcentaje es
/// `(noAsistio + noSePresento) / total × 100`. La respuesta se arma desde
/// JSON, como llega del servidor.
class FakeAbsenceStatisticsRepository implements AbsenceStatisticsRepository {
  FakeAbsenceStatisticsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  /// De mayor a menor porcentaje, como los manda el servidor: 40, 25, 12, 8,
  /// 3 y 0 %.
  static const _specialties = [
    _Group(
      id: 6,
      name: 'Traumatología',
      attended: 10,
      noShow: 6,
      missed: 2,
      notAttended: 2,
    ),
    _Group(
      id: 5,
      name: 'Oftalmología',
      attended: 9,
      noShow: 3,
      missed: 1,
      notAttended: 3,
    ),
    _Group(
      id: 3,
      name: 'Cardiología',
      attended: 20,
      noShow: 2,
      missed: 1,
      notAttended: 2,
    ),
    _Group(
      id: 4,
      name: 'Dermatología',
      attended: 20,
      noShow: 1,
      missed: 1,
      notAttended: 3,
    ),
    _Group(
      id: 1,
      name: 'Medicina General',
      attended: 28,
      noShow: 1,
      missed: 0,
      notAttended: 4,
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

  /// Doce médicos, con nombres largos y de mayor a menor porcentaje: 45, 40,
  /// 36, 33, 25, 18, 14, 10, 6, 2, 0 y 0 %.
  static const _doctors = [
    _Group(
      id: 9,
      name: 'María Fernanda',
      lastName: 'Rodríguez Altamirano',
      attended: 9,
      noShow: 7,
      missed: 2,
      notAttended: 2,
    ),
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
      id: 10,
      name: 'Juan Sebastián',
      lastName: 'Fernández Etcheverry',
      attended: 12,
      noShow: 7,
      missed: 2,
      notAttended: 4,
    ),
    _Group(
      id: 11,
      name: 'Ana Paula',
      lastName: 'Villalba Cuadrado',
      attended: 6,
      noShow: 3,
      missed: 1,
      notAttended: 2,
    ),
    _Group(
      id: 12,
      name: 'Gonzalo',
      lastName: 'Pereira',
      attended: 11,
      noShow: 4,
      missed: 1,
      notAttended: 4,
    ),
    _Group(
      id: 13,
      name: 'Valentina',
      lastName: 'Techera Hernández',
      attended: 10,
      noShow: 2,
      missed: 1,
      notAttended: 3,
    ),
    _Group(
      id: 14,
      name: 'Rodrigo',
      lastName: 'Ferreira',
      attended: 14,
      noShow: 2,
      missed: 1,
      notAttended: 4,
    ),
    _Group(
      id: 15,
      name: 'Federico',
      lastName: 'Olivera',
      attended: 7,
      noShow: 1,
      missed: 0,
      notAttended: 2,
    ),
    _Group(
      id: 16,
      name: 'Mariana',
      lastName: 'Sánchez Larrañaga',
      attended: 24,
      noShow: 1,
      missed: 1,
      notAttended: 4,
    ),
    _Group(
      id: 17,
      name: 'Santiago',
      lastName: 'Díaz',
      attended: 35,
      noShow: 1,
      missed: 0,
      notAttended: 4,
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
    _Group(
      id: 18,
      name: 'Lucía Fernanda',
      lastName: 'Bermúdez Castellanos',
      attended: 12,
      noShow: 0,
      missed: 0,
      notAttended: 1,
    ),
  ];

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Porcentaje entero cuando cae justo.
  static ({int percentage, String text}) _rate(_Group group) {
    final numerator = group.noShow + group.missed;
    final percentage = numerator * 100 ~/ group.total;
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
