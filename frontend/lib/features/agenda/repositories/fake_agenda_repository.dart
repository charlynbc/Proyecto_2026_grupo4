import '../../../core/fakes/datos_prueba.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import '../models/appointment.dart';
import '../models/availability_query.dart';
import '../models/available_number.dart';
import '../models/referral.dart';
import 'agenda_repository.dart';

/// Implementación en memoria de [AgendaRepository] para `USE_FAKES=true`
/// (nunca se usa con la API real). Los médicos de prueba aportan sus números;
/// la especialidad de cada uno se busca por nombre en el catálogo falso, para
/// que coincida con la que elige el socio.
///
/// Reproduce los rechazos del contrato: `NUMERO_NO_DISPONIBLE` (409),
/// `ANTICIPACION_INVALIDA` (409), `LIMITE_TOTAL`, `LIMITE_ESPECIALIDAD`,
/// `CONSULTA_SUPERPUESTA` y `PASE_NO_VALIDO` (409) y `VALIDACION` (400).
class FakeAgendaRepository implements AgendaRepository {
  FakeAgendaRepository(
    this._db,
    this._admin, {
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeDatabase _db;
  final FakeAdminDatabase _admin;
  final Duration latency;
  final DateTime Function() _clock;

  static const int _maxActive = 3;

  @override
  Future<List<AvailableNumber>> listAvailability(
    AvailabilityQuery query,
  ) async {
    await Future<void>.delayed(latency);
    final now = _clock().toUtc();
    final from = query.from;
    final to = query.to;
    final items =
        <AvailableNumber>[
          for (final number in _db.numbers)
            if (!_db.isTaken(number.id) &&
                number.start.isAfter(now) &&
                _specialtyOf(number)?.id == query.specialtyId &&
                (query.doctorId == null || number.doctorId == query.doctorId))
              _toAvailable(number),
        ].where((n) {
          if (from != null && n.date.isBefore(from)) return false;
          if (to != null && n.date.isAfter(to)) return false;
          return true;
        }).toList();

    int byDate(AvailableNumber a, AvailableNumber b) {
      final byDay = a.date.compareTo(b.date);
      return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
    }

    items.sort(
      query.order == AvailabilityOrder.date
          ? byDate
          : (a, b) {
              final byName = a.doctor.lastName.compareTo(b.doctor.lastName);
              return byName != 0 ? byName : byDate(a, b);
            },
    );
    return query.direction == SortDirection.asc
        ? items
        : items.reversed.toList();
  }

  /// Todavía sin pases: la semilla y las reglas del servidor (vigencia y uso)
  /// llegan en el commit de la semilla de pases.
  @override
  Future<List<Referral>> listReferrals() async => const [];

  @override
  Future<Appointment> book({required int numberId, int? referralId}) async {
    await Future<void>.delayed(latency);
    final number = _db.numberById(numberId);
    if (number == null) {
      throw const BookingException(
        BookingFailure.notFound,
        'No existe el número indicado',
      );
    }
    final specialty = _specialtyOf(number);
    if (_db.isTaken(number.id) || specialty == null) {
      throw const BookingException(
        BookingFailure.numberUnavailable,
        'El número no está disponible para agendar',
      );
    }
    if (_db.isContested(number)) {
      _db.markTaken(number.id);
      throw const BookingException(
        BookingFailure.numberUnavailable,
        'El número ya no está disponible para agendar',
      );
    }
    final now = _clock().toUtc();
    if (_db.isStarted(number) ||
        number.start.isBefore(now.add(const Duration(hours: 2))) ||
        number.start.isAfter(now.add(const Duration(days: 30)))) {
      throw const BookingException(
        BookingFailure.outsideWindow,
        'El número debe estar entre 2 horas y 30 días desde ahora',
      );
    }
    final active = _db.appointments.where((a) => a.status == 'AGENDADA');
    if (active.length >= _maxActive) {
      throw const BookingException(
        BookingFailure.totalLimit,
        'El socio ya tiene el máximo de tres consultas agendadas',
      );
    }
    if (active.any((a) => a.specialty.id == specialty.id)) {
      throw const BookingException(
        BookingFailure.specialtyLimit,
        'El socio ya tiene una consulta agendada en esta especialidad',
      );
    }
    final candidate = _toAvailable(number);
    if (active.any(
      (a) =>
          a.date == candidate.date &&
          a.startMinutes < candidate.endMinutes &&
          candidate.startMinutes < a.endMinutes,
    )) {
      throw const BookingException(
        BookingFailure.overlap,
        'El horario se superpone con otra consulta agendada del socio',
      );
    }
    if (!specialty.requiresReferral && referralId != null) {
      throw const BookingException(
        BookingFailure.validation,
        'No se debe enviar paseId para una especialidad que no lo requiere',
      );
    }
    if (specialty.requiresReferral && (referralId == null || referralId <= 0)) {
      throw const BookingException(
        BookingFailure.invalidReferral,
        'No existe un pase propio, vigente y sin utilizar para esta '
        'especialidad',
      );
    }

    _db.markTaken(number.id);
    final appointment = Appointment(
      id: _db.newAppointmentId(),
      status: 'AGENDADA',
      date: candidate.date,
      number: candidate.number,
      startMinutes: candidate.startMinutes,
      endMinutes: candidate.endMinutes,
      doctor: candidate.doctor,
      specialty: candidate.specialty,
      clinic: candidate.clinic,
      referralId: referralId,
      bookedAt: now,
      cancelledAt: null,
      cancellationReason: null,
    );
    _db.appointments.add(appointment);
    return appointment;
  }

  Specialty? _specialtyOf(TestNumber number) {
    final doctor = TestData.doctors.firstWhere((d) => d.id == number.doctorId);
    final testSpecialty = TestData.specialties.firstWhere(
      (s) => s.id == doctor.specialtyId,
    );
    final key = FakeAdminDatabase.normalize(testSpecialty.name);
    for (final specialty in _admin.specialties) {
      if (FakeAdminDatabase.normalize(specialty.name) == key) return specialty;
    }
    return null;
  }

  AvailableNumber _toAvailable(TestNumber number) {
    final doctor = TestData.doctors.firstWhere((d) => d.id == number.doctorId);
    final clinic = TestData.clinics.firstWhere((c) => c.id == doctor.clinicId);
    final start = UruguayTime.toUruguay(number.start);
    final end = UruguayTime.toUruguay(number.end);
    final names = doctor.name.replaceFirst(RegExp(r'^Dra?\. '), '').split(' ');
    return AvailableNumber(
      numberId: number.id,
      shiftId: number.shiftId,
      number: number.index + 1,
      date: DateTime.utc(start.year, start.month, start.day),
      startMinutes: start.hour * 60 + start.minute,
      endMinutes: end.hour * 60 + end.minute,
      doctor: DoctorRef(
        id: doctor.id,
        firstName: names.first,
        lastName: names.skip(1).join(' '),
      ),
      specialty: _specialtyOf(number)!,
      clinic: Clinic(id: clinic.id, name: clinic.name, location: 'Planta baja'),
    );
  }
}
