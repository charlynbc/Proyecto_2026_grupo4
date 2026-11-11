import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/change_weekly_shift_clinic_controller.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shifts_page_provider.dart';
import 'package:agenda_medica/features/turnos/providers/weekly_shift_clinic_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/weekly_shift_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_weekly_shift_clinic_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _twoAppointments =
    'Hay consultas agendadas en las fechas 2026-10-20. '
    'Confirmá el cambio para continuar.';

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftDatabase db;
  late ProviderContainer container;
  late int room7Id;

  setUp(() {
    admin = FakeAdminDatabase(clock: () => DateTime.utc(2026, 10, 20, 15));
    db = FakeShiftDatabase(admin, seed: false);
    final mendez = admin.accounts.firstWhere(
      (account) =>
          account.role == UserRole.medico && account.lastName == 'Méndez',
    );
    final room3 = admin.clinics.firstWhere((c) => c.name == 'Consultorio 3');
    room7Id = admin.clinics.firstWhere((c) => c.name == 'Consultorio 7').id;
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: mendez.id,
        specialtyId: 1,
        clinicId: room3.id,
        weekday: 2,
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 20),
        numbers: [
          ShiftNumber(number: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 20),
        ],
      ),
    );
    container = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(db, latency: Duration.zero),
        ),
        weeklyShiftClinicRepositoryProvider.overrideWith(
          (ref) async =>
              FakeWeeklyShiftClinicRepository(db, latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('empieza en reposo', () {
    expect(
      container.read(changeWeeklyShiftClinicControllerProvider).status,
      SubmitStatus.idle,
    );
  });

  test('un cambio correcto invalida el detalle y el listado', () async {
    container.listen(weeklyShiftProvider(1), (_, _) {});
    container.listen(shiftsPageProvider, (_, _) {});
    final before = await container.read(weeklyShiftProvider(1).future);
    expect(before.clinic.name, 'Consultorio 3');
    final listBefore = await container.read(shiftsPageProvider.future);

    final updated = await container
        .read(changeWeeklyShiftClinicControllerProvider.notifier)
        .submit(1, room7Id);

    expect(updated, isNotNull);
    expect(updated!.clinic.name, 'Consultorio 7');
    expect(updated.clinic.location, 'Piso 1');
    expect(
      container.read(changeWeeklyShiftClinicControllerProvider).status,
      SubmitStatus.done,
    );
    final after = await container.read(weeklyShiftProvider(1).future);
    expect(after.clinic.name, 'Consultorio 7');
    final listAfter = await container.read(shiftsPageProvider.future);
    expect(listAfter, isNot(same(listBefore)));
    expect(listAfter.items.single.clinic.name, 'Consultorio 7');
  });

  test('un error deja el mensaje del servidor', () async {
    db.agendadasPorTurnoSemanal[1] = 2;

    final updated = await container
        .read(changeWeeklyShiftClinicControllerProvider.notifier)
        .submit(1, room7Id);

    expect(updated, isNull);
    final state = container.read(changeWeeklyShiftClinicControllerProvider);
    expect(state.status, SubmitStatus.error);
    expect(state.errorMessage, _twoAppointments);
    expect(db.weeklyShiftById(1)!.clinic.name, 'Consultorio 3');
    expect(db.shifts.single.clinicId, isNot(room7Id));
  });
}
