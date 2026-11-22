import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/clinic_change_preview.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/change_weekly_shift_clinic_controller.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shifts_page_provider.dart';
import 'package:agenda_medica/features/turnos/providers/weekly_shift_clinic_repository_provider.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/weekly_shift_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_weekly_shift_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/weekly_shift_clinic_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _twoAppointments =
    'Hay consultas agendadas en las fechas elegidas. Revisá la vista previa y '
    'confirmá el cambio para continuar.';

/// Cuenta los pedidos de cambio y los deja esperando hasta abrir [gate].
class _CountingClinicRepository implements WeeklyShiftClinicRepository {
  _CountingClinicRepository(this._db, this._gate);

  final FakeShiftDatabase _db;
  final Completer<void> _gate;
  int calls = 0;
  bool? lastConfirmation;
  int? lastViewedTotal;

  @override
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  ) => throw UnimplementedError();

  @override
  Future<WeeklyShift> changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
    int? consultasAgendadasVistas,
  }) async {
    calls++;
    lastConfirmation = confirmarConConsultas;
    lastViewedTotal = consultasAgendadasVistas;
    await _gate.future;
    return _db.changeClinic(weeklyShiftId, clinicId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('dos envíos seguidos mandan un solo pedido', () async {
    final gate = Completer<void>();
    final counting = _CountingClinicRepository(db, gate);
    final local = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(db, latency: Duration.zero),
        ),
        weeklyShiftClinicRepositoryProvider.overrideWith(
          (ref) async => counting,
        ),
      ],
    );
    addTearDown(local.dispose);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    // Un oyente mantiene vivo el controlador entre un envío y otro.
    local.listen(changeWeeklyShiftClinicControllerProvider, (_, _) {});
    final controller = local.read(
      changeWeeklyShiftClinicControllerProvider.notifier,
    );

    final first = controller.submit(1, room7Id);
    final second = controller.submit(1, room7Id);
    await Future<void>.delayed(Duration.zero);

    expect(counting.calls, 1);
    expect(
      local.read(changeWeeklyShiftClinicControllerProvider).status,
      SubmitStatus.loading,
    );

    gate.complete();
    expect(await first, isNotNull);
    expect(await second, isNull);
    expect(counting.calls, 1);

    // Ya terminó: un envío nuevo sí hace otro pedido.
    await controller.submit(1, room7Id);
    expect(counting.calls, 2);
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

  test('pasa al repositorio la confirmación y el total visto', () async {
    final gate = Completer<void>()..complete();
    final counting = _CountingClinicRepository(db, gate);
    final local = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(db, latency: Duration.zero),
        ),
        weeklyShiftClinicRepositoryProvider.overrideWith(
          (ref) async => counting,
        ),
      ],
    );
    addTearDown(local.dispose);
    local.listen(changeWeeklyShiftClinicControllerProvider, (_, _) {});
    final controller = local.read(
      changeWeeklyShiftClinicControllerProvider.notifier,
    );

    await controller.submit(
      1,
      room7Id,
      confirmarConConsultas: true,
      consultasAgendadasVistas: 2,
    );
    expect(counting.lastConfirmation, isTrue);
    expect(counting.lastViewedTotal, 2);

    await controller.submit(1, room7Id);
    expect(counting.lastConfirmation, isFalse);
    expect(counting.lastViewedTotal, isNull);
  });

  test(
    'una consulta nueva tras la vista previa se rechaza y no cambia',
    () async {
      // La vista previa mostró 2 consultas; al guardar ya hay 3.
      db.agendadasPorTurnoSemanal[1] = 3;
      final controller = container.read(
        changeWeeklyShiftClinicControllerProvider.notifier,
      );

      final rejected = await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 2,
      );

      expect(rejected, isNull);
      final state = container.read(changeWeeklyShiftClinicControllerProvider);
      expect(state.status, SubmitStatus.error);
      expect(state.errorMessage, _twoAppointments);
      expect(db.weeklyShiftById(1)!.clinic.name, 'Consultorio 3');
      expect(db.shifts.single.clinicId, isNot(room7Id));

      // Con el total que ahora sí vio, el cambio se aplica.
      final accepted = await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 3,
      );

      expect(accepted, isNotNull);
      expect(db.shifts.single.clinicId, room7Id);
    },
  );

  group('la confirmación quedó vieja', () {
    late ChangeWeeklyShiftClinicController controller;

    setUp(() {
      // Un oyente mantiene vivo el controlador entre un envío y otro.
      container.listen(changeWeeklyShiftClinicControllerProvider, (_, _) {});
      controller = container.read(
        changeWeeklyShiftClinicControllerProvider.notifier,
      );
    });

    test('empieza en falso', () {
      expect(controller.lastFailureWasStaleConfirmation, isFalse);
    });

    test('un 409 al guardar con confirmación y total visto la marca', () async {
      // La vista previa mostró 2; al guardar ya hay 3.
      db.agendadasPorTurnoSemanal[1] = 3;

      final result = await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 2,
      );

      expect(result, isNull);
      expect(controller.lastFailureWasStaleConfirmation, isTrue);
    });

    test('un 409 sin confirmación no la marca', () async {
      db.agendadasPorTurnoSemanal[1] = 2;

      final result = await controller.submit(
        1,
        room7Id,
        consultasAgendadasVistas: 2,
      );

      expect(result, isNull);
      expect(controller.lastFailureWasStaleConfirmation, isFalse);
    });

    test('un 409 con confirmación pero sin total visto no la marca', () async {
      // Sin total visto el servidor no compara; este 409 es otro.
      db.agendadasPorTurnoSemanal[1] = 2;
      db.shifts.clear();

      final result = await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
      );

      expect(result, isNull);
      expect(controller.lastFailureWasStaleConfirmation, isFalse);
    });

    test('otro error con confirmación y total visto no la marca', () async {
      // La configuración 99 no existe: es un 404, no un 409.
      final result = await controller.submit(
        99,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 0,
      );

      expect(result, isNull);
      expect(controller.lastFailureWasStaleConfirmation, isFalse);
    });

    test('un guardado correcto después la limpia', () async {
      db.agendadasPorTurnoSemanal[1] = 3;
      await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 2,
      );
      expect(controller.lastFailureWasStaleConfirmation, isTrue);

      final result = await controller.submit(
        1,
        room7Id,
        confirmarConConsultas: true,
        consultasAgendadasVistas: 3,
      );

      expect(result, isNotNull);
      expect(controller.lastFailureWasStaleConfirmation, isFalse);
    });
  });
}
