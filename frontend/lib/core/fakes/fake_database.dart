import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agenda/models/appointment.dart';
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
  FakeDatabase({required DateTime today, FakeAdminDatabase? admin})
    : shifts = TestData.shiftsFrom(today) {
    if (admin != null) {
      appointments.addAll(
        seedMemberAppointments(
          today: today,
          admin: admin,
          newId: newAppointmentId,
        ),
      );
    }
  }

  final List<TestShift> shifts;
  final List<Appointment> appointments = [];
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
  ),
);
