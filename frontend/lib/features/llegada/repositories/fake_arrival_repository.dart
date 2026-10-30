import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/appointment.dart';
import '../../agenda/models/available_number.dart';
import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import '../models/arrival.dart';
import 'arrival_repository.dart';

const _generalMedicine = Specialty(
  id: 1,
  name: 'Medicina general',
  requiresReferral: false,
);

const _clinic1 = Clinic(
  id: 1,
  name: 'Consultorio 1',
  location: 'Planta baja, sector 1',
);

/// Socio de los datos falsos, con sus consultas de hoy.
class _Member {
  const _Member(this.firstName, this.lastName, this.appointments);

  final String firstName;
  final String lastName;
  final List<Appointment> Function() appointments;
}

Appointment _today({
  required int id,
  required DoctorRef doctor,
  required int startMinutes,
}) => Appointment(
  id: id,
  status: 'AGENDADA',
  date: UruguayTime.today(),
  number: 1,
  startMinutes: startMinutes,
  endMinutes: startMinutes + 20,
  doctor: doctor,
  specialty: _generalMedicine,
  clinic: _clinic1,
  referralId: null,
  bookedAt: DateTime.parse('2026-10-15T10:00:00-03:00'),
  cancelledAt: null,
  cancellationReason: null,
);

/// Tres socios escritos a mano para la pantalla de llegada: Ana con una
/// consulta hoy, Luis con una consulta hoy con Beatriz Cabrera y Laura sin
/// consultas. Lo que se registra acá no aparece en otras pantallas falsas.
final Map<String, _Member> _members = {
  '90000046': _Member(
    'Ana',
    'Fernández',
    () => [
      _today(
        id: 184,
        doctor: const DoctorRef(
          id: 41,
          firstName: 'Alejandro',
          lastName: 'Rivas',
        ),
        startMinutes: 9 * 60,
      ),
    ],
  ),
  '90000052': _Member(
    'Luis',
    'Martínez',
    () => [
      _today(
        id: 185,
        doctor: const DoctorRef(
          id: 42,
          firstName: 'Beatriz',
          lastName: 'Cabrera',
        ),
        startMinutes: 14 * 60,
      ),
    ],
  ),
  '90000068': _Member('Laura', 'López', () => []),
};

/// Implementación en memoria de [ArrivalRepository] para `USE_FAKES=true` y
/// los tests. La primera vez registra el aviso; las siguientes devuelven el
/// original, como el servidor.
class FakeArrivalRepository implements ArrivalRepository {
  FakeArrivalRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;
  final Map<String, Arrival> _arrivals = {};

  @override
  Future<List<Appointment>> listTodayAppointments(String ci) async {
    await Future<void>.delayed(latency);
    final member = _members[normalizeCi(ci)];
    if (member == null) throw const MemberNotFoundException();
    return member.appointments();
  }

  @override
  Future<ArrivalResult> registerArrival(String ci) async {
    await Future<void>.delayed(latency);
    final normalized = normalizeCi(ci);
    final member = _members[normalized];
    if (member == null) throw const MemberNotFoundException();
    if (member.appointments().isEmpty) {
      throw const NoAppointmentsTodayException();
    }
    final existing = _arrivals[normalized];
    if (existing != null) {
      return ArrivalResult(arrival: existing, created: false);
    }
    final arrival = Arrival(
      id: _arrivals.length + 1,
      memberCi: normalized,
      memberFirstName: member.firstName,
      memberLastName: member.lastName,
      registeredAt: DateTime.now(),
      registeredByFirstName: 'Mariana',
      registeredByLastName: 'Ferreira',
    );
    _arrivals[normalized] = arrival;
    return ArrivalResult(arrival: arrival, created: true);
  }
}
