import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/create_weekly_shift_controller.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shifts_page_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shift_listing_data.dart';

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftDatabase shiftDb;
  late ProviderContainer container;
  late int silvaId;

  NewWeeklyShift request({int weekday = 3}) => NewWeeklyShift(
    doctorId: silvaId,
    specialtyId: 2,
    clinicId: admin.clinics[2].id,
    weekday: weekday,
    startDate: DateTime.utc(2026, 10, 21),
    endDate: DateTime.utc(2026, 11, 11),
    numbers: [
      ShiftNumber(number: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 20),
    ],
  );

  setUp(() {
    admin = FakeAdminDatabase();
    shiftDb = buildListingDb(admin);
    silvaId = admin.accounts
        .firstWhere((a) => a.role == UserRole.medico && a.lastName == 'Silva')
        .id;
    container = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(shiftDb, latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('empieza en reposo', () {
    expect(
      container.read(createWeeklyShiftControllerProvider).status,
      SubmitStatus.idle,
    );
  });

  test(
    'un alta correcta devuelve el turno semanal y queda en "done"',
    () async {
      final created = await container
          .read(createWeeklyShiftControllerProvider.notifier)
          .submit(request());

      expect(created, isNotNull);
      expect(created!.shiftCount, 4);
      expect(created.doctor.id, silvaId);
      expect(
        container.read(createWeeklyShiftControllerProvider).status,
        SubmitStatus.done,
      );
      expect(shiftDb.weeklyShifts.length, 5);
    },
  );

  test('una falla del servidor devuelve null y deja su mensaje', () async {
    // El 20/10 hay un martes de Méndez, pero Silva no tiene turnos los
    // martes: se cruza con el consultorio 3 del turno de Méndez (a las 09:00).
    final clash = NewWeeklyShift(
      doctorId: silvaId,
      specialtyId: 2,
      clinicId: admin.clinics[0].id,
      weekday: 2,
      startDate: DateTime.utc(2026, 10, 20),
      endDate: DateTime.utc(2026, 10, 20),
      numbers: [
        ShiftNumber(number: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 20),
      ],
    );
    final created = await container
        .read(createWeeklyShiftControllerProvider.notifier)
        .submit(clash);

    expect(created, isNull);
    final state = container.read(createWeeklyShiftControllerProvider);
    expect(state.status, SubmitStatus.error);
    expect(state.errorMessage, contains('20/10/2026'));
    expect(state.errorMessage, contains('consultorio'));
    expect(shiftDb.weeklyShifts.length, 4, reason: 'no se creó nada');
  });

  test('un alta correcta invalida el listado de turnos', () async {
    // Con alguien mirando el listado (si no, autoDispose lo recalcula igual).
    container.listen(shiftsPageProvider, (_, _) {});
    final before = await container.read(shiftsPageProvider.future);
    expect(before.total, 32);

    await container
        .read(createWeeklyShiftControllerProvider.notifier)
        .submit(request());

    final after = await container.read(shiftsPageProvider.future);
    expect(after.total, 36);
  });
}
