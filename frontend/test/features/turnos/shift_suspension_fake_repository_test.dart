import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_fake_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Hoy" de todos los tests: miércoles 04/11/2026. Se inyecta, no se lee el
/// reloj.
final _today = DateTime.utc(2026, 11, 4);

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// Los turnos de estos tests, sin sembrar el resto (`seed: false`).
///
/// Configuración 1: Méndez, Medicina General (especialidad 1), todos los
/// miércoles del 07/10/2026 al 30/12/2026, de 09:00 a 10:00. Los ids van en
/// orden de fecha:
///
/// | id | fecha | | id | fecha |
/// |---|---|---|---|---|
/// | 1 | 07/10 | | 8 | 25/11 |
/// | 2 | 14/10 | | 9 | 02/12 |
/// | 3 | 21/10 | | 10 | 09/12 |
/// | 4 | 28/10 | | 11 | 16/12 |
/// | 5 | 04/11 (hoy) | | 12 | 23/12 |
/// | 6 | 11/11 | | 13 | 30/12 |
/// | 7 | 18/11 | | | |
///
/// Configuración 2: Silva, Cardiología (especialidad 2), el jueves 05/11/2026
/// de 15:00 a 16:00: es el turno 14.
class _Setup {
  _Setup() {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
    mendezId = _doctor('Méndez');
    otherDoctorId = _doctor('Silva');
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: mendezId,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 3,
        startDate: DateTime.utc(2026, 10, 7),
        endDate: DateTime.utc(2026, 12, 30),
        numbers: [
          _n(1, '09:00', '09:20'),
          _n(2, '09:20', '09:40'),
          _n(3, '09:40', '10:00'),
        ],
      ),
    );
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: otherDoctorId,
        specialtyId: 2,
        clinicId: admin.clinics[1].id,
        weekday: 4,
        startDate: DateTime.utc(2026, 11, 5),
        endDate: DateTime.utc(2026, 11, 5),
        numbers: [_n(1, '15:00', '15:30'), _n(2, '15:30', '16:00')],
      ),
    );
    repository = FakeShiftSuspensionRepository(
      db,
      appointmentsByShift: const {7: 2, 9: 1},
      today: () => _today,
      latency: Duration.zero,
    );
  }

  late final FakeAdminDatabase admin;
  late final FakeShiftDatabase db;
  late final int mendezId;
  late final int otherDoctorId;
  late final FakeShiftSuspensionRepository repository;

  int _doctor(String lastName) => admin.accounts
      .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
      .id;

  ShiftState stateOf(int shiftId) =>
      db.shifts.firstWhere((s) => s.id == shiftId).state;

  /// El filtro de Méndez y Medicina General del 04/11 al 30/12.
  SuspensionFilter filter({
    int? doctorId,
    int specialtyId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) => SuspensionFilter(
    doctorId: doctorId ?? mendezId,
    specialtyId: specialtyId,
    fromDate: fromDate ?? DateTime.utc(2026, 11, 4),
    toDate: toDate ?? DateTime.utc(2026, 12, 30),
  );

  Future<void> suspend(
    List<int> ids, {
    required int confirmedCount,
    String? observation,
    SuspensionFilter? filter,
  }) => repository.suspend(
    filter: filter ?? this.filter(),
    ids: ids,
    observation: observation,
    confirmedCount: confirmedCount,
  );
}

void main() {
  late _Setup s;

  setUp(() => s = _Setup());

  group('previsualizar', () {
    test('con el mapa {7: 2, 9: 1} da 2 fechas y un total de 3', () async {
      final preview = await s.repository.preview(const [7, 9]);

      expect(preview.totalAppointments, 3);
      expect(preview.affectedDates, hasLength(2));
      final first = preview.affectedDates[0];
      expect(first.shiftId, 7);
      expect(first.date, DateTime.utc(2026, 11, 18));
      expect(first.startMinutes, 540);
      expect(first.endMinutes, 600);
      expect(first.appointmentsToCancel, 2);
      final second = preview.affectedDates[1];
      expect(second.shiftId, 9);
      expect(second.date, DateTime.utc(2026, 12, 2));
      expect(second.startMinutes, 540);
      expect(second.endMinutes, 600);
      expect(second.appointmentsToCancel, 1);
    });

    test('no cambia el estado de ningun turno', () async {
      await s.repository.preview(const [7, 9]);

      for (final shift in s.db.shifts) {
        expect(shift.state, ShiftState.active, reason: 'turno ${shift.id}');
      }
    });

    test(
      'fuera del mapa son id % 3 consultas: 10 da 1, 11 da 2, 12 da 0',
      () async {
        final preview = await s.repository.preview(const [10, 11, 12]);

        expect(preview.affectedDates.map((d) => d.appointmentsToCancel), [
          1,
          2,
          0,
        ]);
        expect(preview.totalAppointments, 3);
      },
    );

    test(
      'el turno de hoy se puede previsualizar: el 5 da 2 consultas',
      () async {
        final preview = await s.repository.preview(const [5]);

        expect(preview.affectedDates.single.date, DateTime.utc(2026, 11, 4));
        expect(preview.totalAppointments, 2);
      },
    );

    test('una fecha anterior a hoy es TURNO_NO_SUSPENDIBLE', () async {
      await expectLater(
        s.repository.preview(const [4]),
        throwsA(isA<ShiftNotSuspendableException>()),
      );
    });

    test('un turno ya suspendido es TURNO_NO_SUSPENDIBLE', () async {
      s.db.suspendShift(8);

      await expectLater(
        s.repository.preview(const [8]),
        throwsA(isA<ShiftNotSuspendableException>()),
      );
    });

    test(
      'un id que no existe es ShiftNotFoundException, no StateError',
      () async {
        await expectLater(
          s.repository.preview(const [999]),
          throwsA(isA<ShiftNotFoundException>()),
        );
      },
    );

    test('lista vacia, repetidos y no positivos son VALIDACION', () async {
      for (final ids in const [
        <int>[],
        [7, 7],
        [0],
        [-1],
      ]) {
        await expectLater(
          s.repository.preview(ids),
          throwsA(isA<ShiftValidationException>()),
          reason: '$ids',
        );
      }
    });
  });

  group('suspender', () {
    test('con la cantidad correcta suspende y devuelve el resultado', () async {
      final result = await s.repository.suspend(
        filter: s.filter(),
        ids: const [7, 9],
        confirmedCount: 3,
      );

      expect(result.shifts.map((x) => x.shiftId), [7, 9]);
      expect(result.shifts.map((x) => x.date), [
        DateTime.utc(2026, 11, 18),
        DateTime.utc(2026, 12, 2),
      ]);
      expect(result.cancelledAppointments, 3);
      expect(s.stateOf(7), ShiftState.suspended);
      expect(s.stateOf(9), ShiftState.suspended);
      expect(s.stateOf(8), ShiftState.active);
    });

    test(
      'con otra cantidad es CONFIRMACION_DESACTUALIZADA y no cambia nada',
      () async {
        await expectLater(
          s.suspend(const [7, 9], confirmedCount: 2),
          throwsA(isA<StaleSuspensionConfirmationException>()),
        );

        expect(s.stateOf(7), ShiftState.active);
        expect(s.stateOf(9), ShiftState.active);
      },
    );

    test('un turno ya suspendido es TURNO_NO_SUSPENDIBLE', () async {
      s.db.suspendShift(8);

      await expectLater(
        s.suspend(const [8], confirmedCount: 2),
        throwsA(isA<ShiftNotSuspendableException>()),
      );
    });

    test('una fecha anterior a hoy es TURNO_NO_SUSPENDIBLE', () async {
      await expectLater(
        s.suspend(
          const [4],
          confirmedCount: 1,
          filter: s.filter(fromDate: DateTime.utc(2026, 10, 1)),
        ),
        throwsA(isA<ShiftNotSuspendableException>()),
      );
      expect(s.stateOf(4), ShiftState.active);
    });

    test('todo o nada: con uno suspendido, el valido sigue activo', () async {
      s.db.suspendShift(8);

      await expectLater(
        s.suspend(const [7, 8], confirmedCount: 4),
        throwsA(isA<ShiftNotSuspendableException>()),
      );

      expect(s.stateOf(7), ShiftState.active);
    });

    test('todo o nada: con uno pasado, el valido sigue activo', () async {
      await expectLater(
        s.suspend(
          const [7, 4],
          confirmedCount: 3,
          filter: s.filter(fromDate: DateTime.utc(2026, 10, 1)),
        ),
        throwsA(isA<ShiftNotSuspendableException>()),
      );

      expect(s.stateOf(7), ShiftState.active);
    });

    test('un id que no existe es 404 y no suspende los demas', () async {
      await expectLater(
        s.suspend(const [7, 999], confirmedCount: 2),
        throwsA(isA<ShiftNotFoundException>()),
      );

      expect(s.stateOf(7), ShiftState.active);
    });

    test('lista vacia, repetidos y no positivos son VALIDACION', () async {
      for (final ids in const [
        <int>[],
        [7, 7],
        [0],
        [-1],
      ]) {
        await expectLater(
          s.suspend(ids, confirmedCount: 0),
          throwsA(isA<ShiftValidationException>()),
          reason: '$ids',
        );
      }
    });

    test(
      'una observacion de 1001 caracteres es VALIDACION y no suspende',
      () async {
        await expectLater(
          s.suspend(const [7], confirmedCount: 2, observation: 'a' * 1001),
          throwsA(isA<ShiftValidationException>()),
        );

        expect(s.stateOf(7), ShiftState.active);
      },
    );

    test('una observacion de exactamente 1000 caracteres pasa', () async {
      await s.suspend(const [7], confirmedCount: 2, observation: 'a' * 1000);

      expect(s.stateOf(7), ShiftState.suspended);
    });

    test(
      'la observacion se recorta antes de medirla: 1001 con un espacio pasa',
      () async {
        await s.suspend(
          const [7],
          confirmedCount: 2,
          observation: ' ${'a' * 1000}',
        );

        expect(s.stateOf(7), ShiftState.suspended);
      },
    );

    test(
      'un turno de otro medico no coincide con el filtro: VALIDACION',
      () async {
        await expectLater(
          s.suspend(
            const [7],
            confirmedCount: 2,
            filter: s.filter(doctorId: s.otherDoctorId),
          ),
          throwsA(isA<ShiftValidationException>()),
        );

        expect(s.stateOf(7), ShiftState.active);
      },
    );

    test(
      'un turno de otra especialidad no coincide con el filtro: VALIDACION',
      () async {
        await expectLater(
          s.suspend(
            const [7],
            confirmedCount: 2,
            filter: s.filter(specialtyId: 2),
          ),
          throwsA(isA<ShiftValidationException>()),
        );

        expect(s.stateOf(7), ShiftState.active);
      },
    );

    test('un turno fuera del rango del filtro es VALIDACION', () async {
      // El turno 7 es del 18/11: el rango termina el 17/11.
      await expectLater(
        s.suspend(
          const [7],
          confirmedCount: 2,
          filter: s.filter(toDate: DateTime.utc(2026, 11, 17)),
        ),
        throwsA(isA<ShiftValidationException>()),
      );
      // El turno 7 es del 18/11: el rango empieza el 19/11.
      await expectLater(
        s.suspend(
          const [7],
          confirmedCount: 2,
          filter: s.filter(fromDate: DateTime.utc(2026, 11, 19)),
        ),
        throwsA(isA<ShiftValidationException>()),
      );

      expect(s.stateOf(7), ShiftState.active);
    });

    test(
      'los extremos del rango entran: el turno 7 con el rango 18/11 a 18/11',
      () async {
        await s.suspend(
          const [7],
          confirmedCount: 2,
          filter: s.filter(
            fromDate: DateTime.utc(2026, 11, 18),
            toDate: DateTime.utc(2026, 11, 18),
          ),
        );

        expect(s.stateOf(7), ShiftState.suspended);
      },
    );

    test('un rango con desde posterior a hasta es VALIDACION', () async {
      await expectLater(
        s.suspend(
          const [7],
          confirmedCount: 2,
          filter: s.filter(
            fromDate: DateTime.utc(2026, 12, 1),
            toDate: DateTime.utc(2026, 11, 1),
          ),
        ),
        throwsA(isA<ShiftValidationException>()),
      );
    });
  });
}
