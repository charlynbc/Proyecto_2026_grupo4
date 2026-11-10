import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _date = DateTime.utc(2026, 10, 30);
final DateTime _now = DateTime.utc(2026, 10, 30, 13, 0);
const DoctorRef _doctor = DoctorRef(
  id: 4,
  firstName: 'Carla',
  lastName: 'Méndez',
);
const Clinic _clinic = Clinic(id: 1, name: 'Consultorio 3', location: 'Piso 1');
const ScheduleMember _member = ScheduleMember(
  ci: '90000046',
  firstName: 'Ana',
  lastName: 'Fernández',
);

ScheduleEntry _entry({
  required int id,
  required int startMinutes,
  required String status,
  bool requiresReferral = false,
}) => ScheduleEntry(
  appointmentId: id,
  member: _member,
  doctor: _doctor,
  specialty: Specialty(
    id: requiresReferral ? 2 : 1,
    name: requiresReferral ? 'Cardiología' : 'Medicina General',
    requiresReferral: requiresReferral,
  ),
  date: _date,
  startMinutes: startMinutes,
  endMinutes: startMinutes + 30,
  clinic: _clinic,
  status: status,
  arrivedAt: null,
);

(FakeScheduleRepository, FakeStaffCancellationRepository) _repositories(
  List<ScheduleEntry> entries,
) {
  final schedules = FakeScheduleRepository(
    latency: Duration.zero,
    entries: entries,
  );
  final cancellations = FakeStaffCancellationRepository(
    schedules,
    latency: Duration.zero,
    clock: () => _now,
  );
  return (schedules, cancellations);
}

Matcher _failure(StaffCancellationFailure failure) =>
    isA<StaffCancellationException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

void main() {
  test('consulta a las 13:00 se cancela y cambia la agenda', () async {
    final (schedules, cancellations) = _repositories([
      _entry(id: 9001, startMinutes: 780, status: 'AGENDADA'),
    ]);

    final result = await cancellations.cancel(9001);

    expect(result.appointmentId, 9001);
    expect(result.status, 'CANCELADA_SOCIO');
    final page = await schedules.search(ScheduleFilters(date: _date));
    expect(page.items.single.status, 'CANCELADA_SOCIO');
  });

  test('faltan 1 h 30 y la consulta sigue agendada', () async {
    final (schedules, cancellations) = _repositories([
      _entry(id: 9002, startMinutes: 690, status: 'AGENDADA'),
    ]);

    await expectLater(
      cancellations.cancel(9002),
      throwsA(_failure(StaffCancellationFailure.outsideWindow)),
    );
    final page = await schedules.search(ScheduleFilters(date: _date));
    expect(page.items.single.status, 'AGENDADA');
  });

  test('consulta que ya empezó falla fuera de plazo con su mensaje', () async {
    final (_, cancellations) = _repositories([
      _entry(id: 9007, startMinutes: 540, status: 'AGENDADA'),
    ]);

    await expectLater(
      cancellations.cancel(9007),
      throwsA(
        isA<StaffCancellationException>()
            .having(
              (error) => error.failure,
              'failure',
              StaffCancellationFailure.outsideWindow,
            )
            .having(
              (error) => error.message,
              'message',
              'La cancelación debe solicitarse con al menos dos horas de anticipación.',
            ),
      ),
    );
  });

  test('faltan exactamente 2 h y se cancela', () async {
    final (_, cancellations) = _repositories([
      _entry(id: 9003, startMinutes: 720, status: 'AGENDADA'),
    ]);

    final result = await cancellations.cancel(9003);

    expect(result.status, 'CANCELADA_SOCIO');
  });

  test('consulta atendida falla como no agendada', () async {
    final (_, cancellations) = _repositories([
      _entry(id: 9004, startMinutes: 780, status: 'ATENDIDA'),
    ]);

    await expectLater(
      cancellations.cancel(9004),
      throwsA(_failure(StaffCancellationFailure.notScheduled)),
    );
  });

  test('consulta inexistente falla como no encontrada', () async {
    final (_, cancellations) = _repositories([]);

    await expectLater(
      cancellations.cancel(777),
      throwsA(_failure(StaffCancellationFailure.notFound)),
    );
  });

  for (final id in [0, -3]) {
    test('id $id falla por validación', () async {
      final (_, cancellations) = _repositories([]);

      await expectLater(
        cancellations.cancel(id),
        throwsA(_failure(StaffCancellationFailure.validation)),
      );
    });
  }

  test('devuelve el pase cuando la especialidad lo requiere', () async {
    final (_, cancellations) = _repositories([
      _entry(
        id: 9005,
        startMinutes: 780,
        status: 'AGENDADA',
        requiresReferral: true,
      ),
    ]);

    final result = await cancellations.cancel(9005);

    expect(result.referralReturned, isTrue);
  });

  test('no devuelve el pase cuando la especialidad no lo requiere', () async {
    final (_, cancellations) = _repositories([
      _entry(
        id: 9006,
        startMinutes: 780,
        status: 'AGENDADA',
        requiresReferral: false,
      ),
    ]);

    final result = await cancellations.cancel(9006);

    expect(result.referralReturned, isFalse);
  });
}
