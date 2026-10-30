import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/providers/shift_suspension_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_clock_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_api_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_fake_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los miercoles 04/11, 11/11 y 18/11 de 2026 de Mendez (ids 1, 2 y 3).
FakeShiftDatabase _buildDb(FakeAdminDatabase admin) {
  final db = FakeShiftDatabase(admin, seed: false);
  final mendez = admin.accounts
      .firstWhere((a) => a.role == UserRole.medico && a.lastName == 'Méndez')
      .id;
  db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: mendez,
      specialtyId: 1,
      clinicId: admin.clinics[0].id,
      weekday: 3,
      startDate: DateTime.utc(2026, 11, 4),
      endDate: DateTime.utc(2026, 11, 18),
      numbers: [
        ShiftNumber(number: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 20),
      ],
    ),
  );
  return db;
}

void main() {
  group('suspensionClockProvider', () {
    test('por defecto da una clave de dia en UTC, sin hora', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final today = container.read(suspensionClockProvider)();

      expect(today.isUtc, isTrue);
      expect(today.hour, 0);
      expect(today.minute, 0);
    });
  });

  group('shiftSuspensionRepositoryProvider', () {
    test('con datos falsos da el repositorio falso', () async {
      final container = ProviderContainer(
        overrides: [useFakesProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);

      final repository = await container.read(
        shiftSuspensionRepositoryProvider.future,
      );

      expect(repository, isA<FakeShiftSuspensionRepository>());
    });

    test('sin datos falsos da el repositorio contra la API', () async {
      final container = ProviderContainer(
        overrides: [
          useFakesProvider.overrideWithValue(false),
          dioProvider.overrideWith((ref) async => Dio()),
        ],
      );
      addTearDown(container.dispose);

      final repository = await container.read(
        shiftSuspensionRepositoryProvider.future,
      );

      expect(repository, isA<ApiShiftSuspensionRepository>());
    });

    test('el falso comparte la base de turnos: suspender la cambia', () async {
      final admin = FakeAdminDatabase();
      final db = _buildDb(admin);
      final container = ProviderContainer(
        overrides: [
          useFakesProvider.overrideWithValue(true),
          fakeShiftDatabaseProvider.overrideWithValue(db),
          suspensionClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 4),
          ),
        ],
      );
      addTearDown(container.dispose);
      final repository = await container.read(
        shiftSuspensionRepositoryProvider.future,
      );

      final mendez = admin.accounts
          .firstWhere(
            (a) => a.role == UserRole.medico && a.lastName == 'Méndez',
          )
          .id;

      // El turno 2 es del 11/11 y 2 % 3 = 2 consultas.
      final result = await repository.suspend(
        filter: SuspensionFilter(
          doctorId: mendez,
          specialtyId: 1,
          fromDate: DateTime.utc(2026, 11, 4),
          toDate: DateTime.utc(2026, 11, 18),
        ),
        ids: const [2],
        confirmedCount: 2,
      );

      expect(result.cancelledAppointments, 2);
      expect(
        db.shifts.firstWhere((s) => s.id == 2).state,
        ShiftState.suspended,
      );
      expect(db.shifts.firstWhere((s) => s.id == 1).state, ShiftState.active);
      expect(db.shifts.firstWhere((s) => s.id == 3).state, ShiftState.active);
    });

    test(
      'el falso usa el reloj del provider: con hoy el 12/11, el 2 ya paso',
      () async {
        final admin = FakeAdminDatabase();
        final db = _buildDb(admin);
        final container = ProviderContainer(
          overrides: [
            useFakesProvider.overrideWithValue(true),
            fakeShiftDatabaseProvider.overrideWithValue(db),
            suspensionClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 11, 12),
            ),
          ],
        );
        addTearDown(container.dispose);
        final repository = await container.read(
          shiftSuspensionRepositoryProvider.future,
        );

        await expectLater(
          repository.preview(const [2]),
          throwsA(isA<ShiftNotSuspendableException>()),
        );
      },
    );
  });
}
