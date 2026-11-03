import '../../../../core/utils/uruguay_time.dart';
import '../models/shift_utilization.dart';
import 'shift_statistics_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. Devuelve siempre las
/// mismas cuatro filas, sin filtrar por fecha: solo repite el período pedido
/// (o el mes en curso del reloj si no se pidió ninguno). Las filas se arman
/// desde JSON, como llegan del servidor, así que el `100` entero del último
/// turno pasa por la misma lectura que la respuesta real.
class FakeShiftStatisticsRepository implements ShiftStatisticsRepository {
  FakeShiftStatisticsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static Map<String, dynamic> _row({
    required int id,
    required int doctorId,
    required String firstName,
    required String lastName,
    required int specialtyId,
    required String specialty,
    required bool referral,
    required int clinicId,
    required String clinic,
    required String location,
    required int weekday,
    required int activeDates,
    required int offered,
    required int occupied,
    required num? percentage,
    required String text,
  }) => {
    'turnoSemanalId': id,
    'medico': {'id': doctorId, 'nombre': firstName, 'apellido': lastName},
    'especialidad': {
      'id': specialtyId,
      'nombre': specialty,
      'requierePase': referral,
    },
    'consultorio': {'id': clinicId, 'nombre': clinic, 'ubicacion': location},
    'diaSemana': weekday,
    'fechasActivas': activeDates,
    'numerosOfrecidos': offered,
    'numerosOcupados': occupied,
    'porcentajeUtilizacion': percentage,
    'utilizacion': text,
  };

  static final List<Map<String, dynamic>> _rows = [
    _row(
      id: 120,
      doctorId: 17,
      firstName: 'Marta',
      lastName: 'Rodríguez',
      specialtyId: 3,
      specialty: 'Cardiología',
      referral: true,
      clinicId: 5,
      clinic: 'Consultorio 5',
      location: 'Piso 2, ala norte',
      weekday: 2,
      activeDates: 4,
      offered: 12,
      occupied: 9,
      percentage: 75.0,
      text: '75 %',
    ),
    _row(
      id: 121,
      doctorId: 21,
      firstName: 'Jorge',
      lastName: 'Pereira',
      specialtyId: 1,
      specialty: 'Medicina General',
      referral: false,
      clinicId: 6,
      clinic: 'Consultorio 6',
      location: 'Piso 2, ala sur',
      weekday: 4,
      activeDates: 0,
      offered: 0,
      occupied: 0,
      percentage: null,
      text: 'Sin datos',
    ),
    _row(
      id: 122,
      doctorId: 25,
      firstName: 'Laura',
      lastName: 'Gómez',
      specialtyId: 2,
      specialty: 'Pediatría',
      referral: false,
      clinicId: 2,
      clinic: 'Consultorio 2',
      location: 'Planta baja',
      weekday: 1,
      activeDates: 4,
      offered: 8,
      occupied: 3,
      percentage: 37.5,
      text: '37,5 %',
    ),
    _row(
      id: 123,
      doctorId: 17,
      firstName: 'Marta',
      lastName: 'Rodríguez',
      specialtyId: 3,
      specialty: 'Cardiología',
      referral: true,
      clinicId: 5,
      clinic: 'Consultorio 5',
      location: 'Piso 2, ala norte',
      weekday: 5,
      activeDates: 4,
      offered: 10,
      occupied: 10,
      // Entero, como puede mandarlo el servidor.
      percentage: 100,
      text: '100 %',
    ),
  ];

  @override
  Future<ShiftUtilization> utilization({DateTime? from, DateTime? to}) async {
    await Future<void>.delayed(latency);
    final now = UruguayTime.toUruguay(_clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    if (start.isAfter(end)) {
      throw const ShiftStatisticsException(
        ShiftStatisticsFailure.validation,
        'desde no puede ser posterior a hasta',
      );
    }
    return ShiftUtilization(
      from: start,
      to: end,
      items: [for (final row in _rows) ShiftUtilizationItem.fromJson(row)],
    );
  }
}
