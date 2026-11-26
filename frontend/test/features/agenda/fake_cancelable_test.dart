import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_cancelable.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_history_repository.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 20/10/2026 10:00 en Uruguay (13:00 UTC).
final _now = DateTime.utc(2026, 10, 20, 13);
final _today = DateTime.utc(2026, 10, 20);

Appointment _appointment({
  int id = 9001,
  String status = 'AGENDADA',
  DateTime? date,
  required int startMinutes,
}) => Appointment(
  id: id,
  status: status,
  date: date ?? _today,
  number: 1,
  startMinutes: startMinutes,
  endMinutes: startMinutes + 30,
  doctor: DoctorRef(id: 4, firstName: 'Ana', lastName: 'Pérez'),
  specialty: Specialty(id: 2, name: 'Cardiología', requiresReferral: false),
  clinic: Clinic(id: 1, name: 'Consultorio 1', location: 'Planta baja'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 10, 1, 12),
  cancelledAt: null,
  cancellationReason: null,
);

int _minutes(int hour, int minute) => hour * 60 + minute;

void main() {
  group('la regla del servidor en los fakes (ahora 10:00 de Uruguay)', () {
    late FakeDatabase db;

    setUp(() => db = FakeDatabase(today: _today));

    test('AGENDADA a más de 2 horas y sin llegada ese día es cancelable', () {
      final a = _appointment(startMinutes: _minutes(15, 0));

      expect(fakeCancelable(db, a, _now), isTrue);
      expect(fakeCancelDenial(db, a, _now), isNull);
    });

    test('mañana sin llegada también es cancelable', () {
      final a = _appointment(
        date: _today.add(const Duration(days: 1)),
        startMinutes: _minutes(9, 0),
      );

      expect(fakeCancelable(db, a, _now), isTrue);
    });

    test('con llegada ese día no es cancelable aunque falte mucho', () {
      db.arrivedDays.add(_today);
      final a = _appointment(startMinutes: _minutes(18, 0));

      expect(fakeCancelable(db, a, _now), isFalse);
      expect(fakeCancelDenial(db, a, _now), FakeCancelDenial.alreadyArrived);
    });

    test('la llegada de otro día no afecta', () {
      db.arrivedDays.add(_today.add(const Duration(days: 1)));
      final a = _appointment(startMinutes: _minutes(15, 0));

      expect(fakeCancelable(db, a, _now), isTrue);
    });

    test('a menos de 2 horas no es cancelable', () {
      final a = _appointment(startMinutes: _minutes(11, 59));

      expect(fakeCancelable(db, a, _now), isFalse);
      expect(fakeCancelDenial(db, a, _now), FakeCancelDenial.outsideWindow);
    });

    test('justo a 2 horas sí es cancelable (el borde cuenta)', () {
      final a = _appointment(startMinutes: _minutes(12, 0));

      expect(fakeCancelable(db, a, _now), isTrue);
    });

    test('una consulta que ya empezó no es cancelable', () {
      final a = _appointment(startMinutes: _minutes(9, 30));

      expect(fakeCancelable(db, a, _now), isFalse);
    });

    for (final status in [
      'ATENDIDA',
      'CANCELADA_SOCIO',
      'CANCELADA_INSTITUCION',
      'NO_SE_PRESENTO',
      'NO_ASISTIO',
      'NO_ATENDIDA',
    ]) {
      test('$status nunca es cancelable', () {
        final a = _appointment(
          status: status,
          date: _today.add(const Duration(days: 5)),
          startMinutes: _minutes(15, 0),
        );

        expect(fakeCancelable(db, a, _now), isFalse);
        expect(fakeCancelDenial(db, a, _now), FakeCancelDenial.notScheduled);
      });
    }

    test('el orden de los motivos es estado, llegada y plazo', () {
      db.arrivedDays.add(_today);
      final cerca = _minutes(10, 30);

      expect(
        fakeCancelDenial(
          db,
          _appointment(status: 'ATENDIDA', startMinutes: cerca),
          _now,
        ),
        FakeCancelDenial.notScheduled,
      );
      expect(
        fakeCancelDenial(db, _appointment(startMinutes: cerca), _now),
        FakeCancelDenial.alreadyArrived,
      );
    });
  });

  group('el historial falso devuelve cancelable', () {
    late FakeDatabase db;
    late FakeAppointmentHistoryRepository history;

    setUp(() {
      db = FakeDatabase(today: _today, admin: FakeAdminDatabase());
      history = FakeAppointmentHistoryRepository(
        db,
        latency: Duration.zero,
        clock: () => _now,
      );
    });

    test(
      'la semilla da false: la agendada tiene llegada, el resto no es AGENDADA',
      () async {
        final page = await history.list(const AppointmentHistoryQuery());

        // El orden por defecto es por fecha, la más reciente primero: la 1
        // (dentro de 12 días), la 2 (hace 11) y la 3 (hace 31).
        expect([for (final a in page.items) a.id], [1, 2, 3]);
        expect(
          [for (final a in page.items) a.cancelable],
          [false, false, false],
        );
        expect((await history.get(1)).cancelable, isFalse);
        expect((await history.get(2)).cancelable, isFalse);
        expect((await history.get(3)).cancelable, isFalse);
      },
    );

    test(
      'una AGENDADA futura sin llegada da true en lista y detalle',
      () async {
        db.appointments.add(
          _appointment(
            id: 50,
            date: _today.add(const Duration(days: 3)),
            startMinutes: _minutes(9, 0),
          ),
        );

        final page = await history.list(const AppointmentHistoryQuery());

        expect(page.items.singleWhere((a) => a.id == 50).cancelable, isTrue);
        expect((await history.get(50)).cancelable, isTrue);
      },
    );

    test('una AGENDADA que empieza en 90 minutos da false', () async {
      db.appointments.add(_appointment(id: 51, startMinutes: _minutes(11, 30)));

      expect((await history.get(51)).cancelable, isFalse);
    });

    test('el resto de los datos de la consulta no cambia', () async {
      db.appointments.add(
        _appointment(
          id: 52,
          date: _today.add(const Duration(days: 3)),
          startMinutes: _minutes(9, 0),
        ),
      );

      final a = await history.get(52);

      expect(a.status, 'AGENDADA');
      expect(a.timeRange, '09:00 - 09:30');
      expect(a.specialty.name, 'Cardiología');
    });
  });

  group('la cancelación falsa', () {
    test(
      'la consulta cancelada que guarda queda con cancelable false',
      () async {
        final db = FakeDatabase(today: _today);
        db.appointments.add(_appointment(startMinutes: _minutes(15, 0)));
        final repo = FakeAppointmentCancellationRepository(
          db,
          latency: Duration.zero,
          clock: () => _now,
        );

        await repo.cancel(9001);

        expect(db.appointments.single.status, 'CANCELADA_SOCIO');
        expect(db.appointments.single.cancelable, isFalse);
      },
    );
  });

  group('las consultas de demostración (demoCancelable)', () {
    test('por defecto la semilla sigue siendo de tres consultas', () {
      final db = FakeDatabase(today: _today, admin: FakeAdminDatabase());

      expect([for (final a in db.appointments) a.id], [1, 2, 3]);
      expect(db.newAppointmentId(), 4);
    });

    test('con el parámetro se suman la 101 y la 102 y los ids siguen en 4', () {
      final db = FakeDatabase(
        today: _today,
        admin: FakeAdminDatabase(),
        demoCancelable: true,
        now: _now,
      );

      expect([for (final a in db.appointments) a.id], [1, 2, 3, 101, 102]);
      expect(db.newAppointmentId(), 4);
    });

    test('sin admin no se siembra nada aunque se pida', () {
      final db = FakeDatabase(today: _today, demoCancelable: true, now: _now);

      expect(db.appointments, isEmpty);
    });

    test(
      'la 101: dentro de 20 días, mismo médico y especialidad que la 2',
      () async {
        final db = FakeDatabase(
          today: _today,
          admin: FakeAdminDatabase(),
          demoCancelable: true,
          now: _now,
        );
        final a = db.appointments.singleWhere((x) => x.id == 101);
        final base = db.appointments.singleWhere((x) => x.id == 2);

        expect(a.status, 'AGENDADA');
        expect(a.date, DateTime.utc(2026, 11, 9));
        expect(a.timeRange, '11:00 - 11:30');
        expect(a.doctor.id, base.doctor.id);
        expect(a.specialty.id, base.specialty.id);
        expect(db.arrivedDays.contains(a.date), isFalse);
        final history = FakeAppointmentHistoryRepository(
          db,
          latency: Duration.zero,
          clock: () => _now,
        );
        expect((await history.get(101)).cancelable, isTrue);
      },
    );

    test(
      'la 102: empieza 90 minutos después del reloj y no es cancelable',
      () async {
        final db = FakeDatabase(
          today: _today,
          admin: FakeAdminDatabase(),
          demoCancelable: true,
          now: _now,
        );
        final a = db.appointments.singleWhere((x) => x.id == 102);

        expect(a.status, 'AGENDADA');
        // Ahora son las 10:00 de Uruguay: empieza a las 11:30 de hoy.
        expect(a.date, _today);
        expect(a.timeRange, '11:30 - 12:00');
        expect(db.arrivedDays.contains(a.date), isFalse);
        final history = FakeAppointmentHistoryRepository(
          db,
          latency: Duration.zero,
          clock: () => _now,
        );
        expect((await history.get(102)).cancelable, isFalse);
      },
    );

    test('la 102 pasa a mañana si los 90 minutos cruzan la medianoche', () {
      // 20/10/2026 22:45 en Uruguay (21/10 01:45 UTC): empieza 00:15 del 21.
      final late = DateTime.utc(2026, 10, 21, 1, 45);
      final db = FakeDatabase(
        today: UruguayTime.today(now: late),
        admin: FakeAdminDatabase(),
        demoCancelable: true,
        now: late,
      );
      final a = db.appointments.singleWhere((x) => x.id == 102);

      expect(a.date, DateTime.utc(2026, 10, 21));
      expect(a.timeRange, '00:15 - 00:45');
    });

    test('el provider de la app activa la demostración', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ids = [
        for (final a in container.read(fakeDatabaseProvider).appointments) a.id,
      ];

      expect(ids, [1, 2, 3, 101, 102]);
    });
  });
}
