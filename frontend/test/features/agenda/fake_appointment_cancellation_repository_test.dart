import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_history_repository.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime.utc(2026, 10, 20);
final _clock = DateTime.utc(2026, 10, 20, 13);

Appointment _appointment({
  required int id,
  required String status,
  required int startMinutes,
  int? referralId,
}) {
  return Appointment(
    id: id,
    status: status,
    date: _day,
    number: 1,
    startMinutes: startMinutes,
    endMinutes: startMinutes + 30,
    doctor: DoctorRef(id: 4, firstName: 'Ana', lastName: 'Pérez'),
    specialty: Specialty(id: 2, name: 'Cardiología', requiresReferral: true),
    clinic: Clinic(id: 1, name: 'Consultorio 1', location: 'Planta baja'),
    referralId: referralId,
    bookedAt: DateTime.utc(2026, 10, 1, 12),
    cancelledAt: null,
    cancellationReason: null,
  );
}

(FakeDatabase, FakeAppointmentCancellationRepository) _repo({
  required String status,
  required int startMinutes,
  int? referralId,
}) {
  final db = FakeDatabase(today: _day);
  db.appointments.add(
    _appointment(
      id: 9001,
      status: status,
      startMinutes: startMinutes,
      referralId: referralId,
    ),
  );
  final repo = FakeAppointmentCancellationRepository(
    db,
    latency: Duration.zero,
    clock: () => _clock,
  );
  return (db, repo);
}

Matcher _failsWith(CancellationFailure failure) => throwsA(
  isA<CancellationException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  test(
    'consulta a las 13:00 se cancela y queda cancelada en el historial',
    () async {
      final (db, repo) = _repo(status: 'AGENDADA', startMinutes: 780);

      final result = await repo.cancel(9001);

      expect(result.cancelledAt, _clock);
      final history = FakeAppointmentHistoryRepository(
        db,
        latency: Duration.zero,
      );
      expect((await history.get(9001)).status, 'CANCELADA_SOCIO');
    },
  );

  test('a las 11:30 faltan 1 hora 30 y queda fuera de plazo', () async {
    final (_, repo) = _repo(status: 'AGENDADA', startMinutes: 690);

    await expectLater(
      repo.cancel(9001),
      _failsWith(CancellationFailure.outsideWindow),
    );
  });

  test('a las 12:00 faltan exactamente 2 horas y se cancela', () async {
    final (_, repo) = _repo(status: 'AGENDADA', startMinutes: 720);

    final result = await repo.cancel(9001);

    expect(result.appointmentId, 9001);
  });

  test('una consulta atendida no estaba agendada', () async {
    final (_, repo) = _repo(status: 'ATENDIDA', startMinutes: 780);

    await expectLater(
      repo.cancel(9001),
      _failsWith(CancellationFailure.notScheduled),
    );
  });

  test('una consulta inexistente no se encuentra', () async {
    final (_, repo) = _repo(status: 'AGENDADA', startMinutes: 780);

    await expectLater(
      repo.cancel(777),
      _failsWith(CancellationFailure.notFound),
    );
  });

  test('devuelve el pase que vence hoy', () async {
    final (db, repo) = _repo(
      status: 'AGENDADA',
      startMinutes: 780,
      referralId: 5,
    );
    db.referrals.add(
      Referral(
        id: 5,
        specialty: Specialty(
          id: 2,
          name: 'Cardiología',
          requiresReferral: true,
        ),
        issuedAt: DateTime.utc(2026, 10, 1, 12),
        expiresOn: _day,
      ),
    );

    final result = await repo.cancel(9001);

    expect(result.referralReturned, isTrue);
  });

  test('no devuelve el pase vencido ayer', () async {
    final (db, repo) = _repo(
      status: 'AGENDADA',
      startMinutes: 780,
      referralId: 5,
    );
    db.referrals.add(
      Referral(
        id: 5,
        specialty: Specialty(
          id: 2,
          name: 'Cardiología',
          requiresReferral: true,
        ),
        issuedAt: DateTime.utc(2026, 10, 1, 12),
        expiresOn: DateTime.utc(2026, 10, 19),
      ),
    );

    final result = await repo.cancel(9001);

    expect(result.referralReturned, isFalse);
  });

  test('sin pase no devuelve ningún pase', () async {
    final (_, repo) = _repo(status: 'AGENDADA', startMinutes: 780);

    final result = await repo.cancel(9001);

    expect(result.referralReturned, isFalse);
  });
}
