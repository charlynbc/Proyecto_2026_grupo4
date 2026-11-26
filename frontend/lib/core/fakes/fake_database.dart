import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agenda/models/appointment.dart';
import '../../features/agenda/models/referral.dart';
import '../utils/uruguay_time.dart';
import 'datos_prueba.dart';
import 'fake_admin_database.dart';
import 'fake_appointment_seed.dart';

/// Estado en memoria del repository falso de agenda (`USE_FAKES=true`): qué
/// números ya se tomaron y qué consultas se agendaron. Se pierde al recargar
/// la app.
class FakeDatabase {
  /// Con [admin], arranca con las consultas de la socia de prueba (ver
  /// `seedMemberAppointments`); sin él, la lista de consultas empieza vacía.
  ///
  /// Con [demoCancelable] (y [admin]) se suman las consultas 101 y 102 para ver
  /// `cancelable` con `USE_FAKES` (ver `seedDemoCancelableAppointments`); [now]
  /// es el reloj con que se arma la 102 y por defecto es el instante actual.
  /// Solo lo activa `fakeDatabaseProvider`: sin él la semilla son tres
  /// consultas.
  FakeDatabase({
    required DateTime today,
    FakeAdminDatabase? admin,
    bool demoCancelable = false,
    DateTime? now,
  }) : shifts = TestData.shiftsFrom(today) {
    if (admin != null) {
      final seeded = seedMemberAppointments(
        today: today,
        admin: admin,
        newId: newAppointmentId,
      );
      appointments.addAll(seeded);
      referrals.addAll(seedMemberReferrals(today: today, admin: admin));
      // La agendada de la semilla (Dermatología, dentro de 12 días) tiene
      // llegada ese día, para ver el aviso al cancelar con USE_FAKES.
      for (final appointment in seeded) {
        if (appointment.status == 'AGENDADA') {
          arrivedDays.add(appointment.date);
        }
      }
      // Las de demostración se suman después, sin llegada ese día.
      if (demoCancelable) {
        appointments.addAll(
          seedDemoCancelableAppointments(
            today: today,
            now: now ?? DateTime.now(),
            admin: admin,
          ),
        );
      }
    }
  }

  final List<TestShift> shifts;
  final List<Appointment> appointments = [];

  /// Días (clave de Uruguay) en los que el socio ya registró la llegada.
  /// La regla mira el día, no una consulta.
  final Set<DateTime> arrivedDays = {};

  /// Los pases de la socia. Si un pase está usado o disponible no se guarda
  /// acá: se deriva de [appointments], como hace el servidor.
  final List<Referral> referrals = [];
  final Set<int> _takenNumberIds = {};
  int _nextAppointmentId = 1;

  Iterable<TestNumber> get numbers => shifts.expand((s) => s.numbers);

  TestNumber? numberById(int id) {
    for (final number in numbers) {
      if (number.id == id) return number;
    }
    return null;
  }

  bool isTaken(int numberId) => _takenNumberIds.contains(numberId);

  void markTaken(int numberId) => _takenNumberIds.add(numberId);

  int newAppointmentId() => _nextAppointmentId++;

  /// Un número "disputado": figura libre, pero otro socio lo toma justo antes
  /// de que se confirme la consulta (409 `NUMERO_NO_DISPONIBLE`).
  bool isContested(TestNumber number) =>
      number.index == 1 && number.shiftId % 5 == 0;

  /// Un número "iniciado": figura libre, pero para cuando se confirma ya
  /// quedó fuera de la anticipación mínima (409 `ANTICIPACION_INVALIDA`).
  bool isStarted(TestNumber number) =>
      number.index == 2 && number.shiftId % 7 == 0;
}

/// Un único estado en memoria por ejecución de la app.
final fakeDatabaseProvider = Provider<FakeDatabase>(
  (ref) => FakeDatabase(
    today: UruguayTime.today(),
    admin: ref.watch(fakeAdminDatabaseProvider),
    demoCancelable: true,
  ),
);
