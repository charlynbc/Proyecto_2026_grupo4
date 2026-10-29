import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/models/suspension_preview.dart';
import 'package:agenda_medica/features/turnos/models/suspension_result.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shift_suspension_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shifts_page_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspend_shifts_controller.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_candidates_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_clock_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_fake_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Hoy" de todos los tests: miercoles 04/11/2026. Se inyecta, no se lee el
/// reloj.
final _today = DateTime.utc(2026, 11, 4);

/// El repositorio de suspension falso, con las llamadas contadas y fallas
/// programadas. En cada llamada se saca la primera entrada del guion: `null`
/// delega en el falso y cualquier otra cosa se tira como error.
class _ScriptedRepository implements ShiftSuspensionRepository {
  _ScriptedRepository(this._inner);

  final ShiftSuspensionRepository _inner;

  final List<Object?> previewScript = [];
  final List<Object?> suspendScript = [];
  Completer<void>? previewGate;
  Completer<void>? suspendGate;

  int previewCalls = 0;
  int suspendCalls = 0;
  List<int>? lastPreviewIds;
  SuspensionFilter? lastFilter;
  List<int>? lastSuspendIds;
  String? lastObservation;
  int? lastConfirmedCount;

  @override
  Future<SuspensionPreview> preview(List<int> ids) async {
    previewCalls++;
    lastPreviewIds = ids;
    await previewGate?.future;
    if (previewScript.isNotEmpty) {
      final next = previewScript.removeAt(0);
      if (next != null) throw next;
    }
    return _inner.preview(ids);
  }

  @override
  Future<SuspensionResult> suspend({
    required SuspensionFilter filter,
    required List<int> ids,
    String? observation,
    required int confirmedCount,
  }) async {
    suspendCalls++;
    lastFilter = filter;
    lastSuspendIds = ids;
    lastObservation = observation;
    lastConfirmedCount = confirmedCount;
    await suspendGate?.future;
    if (suspendScript.isNotEmpty) {
      final next = suspendScript.removeAt(0);
      if (next != null) throw next;
    }
    return _inner.suspend(
      filter: filter,
      ids: ids,
      observation: observation,
      confirmedCount: confirmedCount,
    );
  }
}

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// Turnos de los tests, sin sembrar el resto (`seed: false`).
///
/// Configuracion 1: Mendez, Medicina General (especialidad 1), todos los
/// miercoles del 07/10/2026 al 30/12/2026. Ids por fecha: 1 = 07/10, 2 = 14/10,
/// 3 = 21/10, 4 = 28/10, 5 = 04/11 (hoy), 6 = 11/11, 7 = 18/11, 8 = 25/11,
/// 9 = 02/12, 10 = 09/12, 11 = 16/12, 12 = 23/12, 13 = 30/12.
///
/// Configuracion 2: Silva, Cardiologia (especialidad 2), el jueves 05/11/2026:
/// el turno 14.
///
/// Consultas: {7: 2, 9: 1}; fuera del mapa, id % 3 (el 8 da 2, el 5 da 2).
class _Setup {
  _Setup() {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
    mendezId = _doctor('Méndez');
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: mendezId,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 3,
        startDate: DateTime.utc(2026, 10, 7),
        endDate: DateTime.utc(2026, 12, 30),
        numbers: [_n(1, '09:00', '09:20')],
      ),
    );
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: _doctor('Silva'),
        specialtyId: 2,
        clinicId: admin.clinics[1].id,
        weekday: 4,
        startDate: DateTime.utc(2026, 11, 5),
        endDate: DateTime.utc(2026, 11, 5),
        numbers: [_n(1, '15:00', '15:30')],
      ),
    );
    repository = _ScriptedRepository(
      FakeShiftSuspensionRepository(
        db,
        appointmentsByShift: appointments,
        today: () => _today,
        latency: Duration.zero,
      ),
    );
    container = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(db, latency: Duration.zero),
        ),
        shiftSuspensionRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        suspensionClockProvider.overrideWithValue(() => _today),
      ],
    );
    // Los providers autoDispose se mantienen vivos mientras alguien escucha.
    container.listen(suspendShiftsControllerProvider, (_, _) {});
  }

  late final FakeAdminDatabase admin;
  late final FakeShiftDatabase db;
  late final int mendezId;
  late final _ScriptedRepository repository;
  late final ProviderContainer container;

  /// No es `const` para poder cambiar las consultas de un turno a mitad de un
  /// test.
  final Map<int, int> appointments = {7: 2, 9: 1};

  int _doctor(String lastName) => admin.accounts
      .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
      .id;

  SuspendShiftsController get notifier =>
      container.read(suspendShiftsControllerProvider.notifier);

  SuspendShiftsState get state =>
      container.read(suspendShiftsControllerProvider);

  /// Mendez, Medicina General, del 01/10 al 30/12: ajustado a hoy, del 04/11.
  SuspensionFilter filter({DateTime? toDate}) => SuspensionFilter(
    doctorId: mendezId,
    specialtyId: 1,
    fromDate: DateTime.utc(2026, 10, 1),
    toDate: toDate ?? DateTime.utc(2026, 12, 30),
  );

  /// Espera a que los candidatos del filtro actual se carguen y a que el
  /// controller procese la carga.
  Future<List<int>> settle() async {
    final shifts = await container.read(
      suspensionCandidatesProvider(state.filter!).future,
    );
    await Future<void>.delayed(Duration.zero);
    return [for (final shift in shifts) shift.id];
  }

  ShiftState stateOf(int shiftId) =>
      db.shifts.firstWhere((s) => s.id == shiftId).state;

  /// Con el filtro puesto, los candidatos cargados, 9 y 7 elegidos (en ese
  /// orden) y la vista previa pedida: 2 fechas y 3 consultas.
  Future<void> readyToConfirm({String observation = ''}) async {
    notifier.setFilter(filter());
    await settle();
    notifier.toggleSelection(9);
    notifier.toggleSelection(7);
    notifier.setObservation(observation);
    await notifier.requestPreview();
  }
}

void main() {
  late _Setup s;

  setUp(() => s = _Setup());
  tearDown(() => s.container.dispose());

  group('estado inicial y filtro', () {
    test('empieza sin filtro, sin seleccion y en reposo', () {
      expect(s.state.filter, isNull);
      expect(s.state.selectedIds, isEmpty);
      expect(s.state.observation, '');
      expect(s.state.phase, SuspendPhase.idle);
      expect(s.state.preview, isNull);
      expect(s.state.error, isNull);
      expect(s.state.result, isNull);
    });

    test('setFilter guarda el filtro con "desde" ajustado a hoy', () {
      s.notifier.setFilter(s.filter());

      expect(
        s.state.filter,
        SuspensionFilter(
          doctorId: s.mendezId,
          specialtyId: 1,
          fromDate: DateTime.utc(2026, 11, 4),
          toDate: DateTime.utc(2026, 12, 30),
        ),
      );
    });

    test(
      'cambiar el filtro limpia la seleccion, la vista previa y el error',
      () async {
        await s.readyToConfirm();
        expect(s.state.selectedIds, {7, 9});
        expect(s.state.preview, isNotNull);

        s.notifier.setFilter(s.filter(toDate: DateTime.utc(2026, 12, 16)));

        expect(s.state.selectedIds, isEmpty);
        expect(s.state.preview, isNull);
        expect(s.state.error, isNull);
      },
    );

    test('cambiar el filtro conserva la observacion', () async {
      s.notifier.setFilter(s.filter());
      s.notifier.setObservation('aviso');

      s.notifier.setFilter(s.filter(toDate: DateTime.utc(2026, 12, 16)));

      expect(s.state.observation, 'aviso');
    });
  });

  group('seleccion', () {
    test('toggleSelection elige y deselige', () {
      s.notifier.toggleSelection(7);
      expect(s.state.selectedIds, {7});

      s.notifier.toggleSelection(9);
      expect(s.state.selectedIds, {7, 9});

      s.notifier.toggleSelection(7);
      expect(s.state.selectedIds, {9});
    });

    test('selectAll elige todos y clearSelection los saca', () {
      s.notifier.selectAll(const [5, 6, 7]);
      expect(s.state.selectedIds, {5, 6, 7});

      s.notifier.clearSelection();
      expect(s.state.selectedIds, isEmpty);
    });

    test(
      'al recargar los candidatos se sacan los ids que ya no estan',
      () async {
        s.notifier.setFilter(s.filter());
        await s.settle();
        s.notifier.selectAll(const [7, 8]);

        // El turno 8 se suspende por otro lado y la lista se recarga.
        s.db.suspendShift(8);
        s.container.invalidate(suspensionCandidatesProvider(s.state.filter!));
        await s.settle();

        expect(s.state.selectedIds, {7});
      },
    );
  });

  group('previsualizar', () {
    test('con la seleccion vacia no llama al repositorio', () async {
      s.notifier.setFilter(s.filter());

      await s.notifier.requestPreview();

      expect(s.repository.previewCalls, 0);
      expect(s.state.preview, isNull);
    });

    test(
      'pide los ids ordenados y deja la vista previa en el estado',
      () async {
        await s.readyToConfirm();

        expect(s.repository.previewCalls, 1);
        expect(s.repository.lastPreviewIds, [7, 9]);
        expect(s.state.preview!.affectedDates, hasLength(2));
        expect(s.state.preview!.totalAppointments, 3);
        expect(s.state.phase, SuspendPhase.idle);
        expect(s.state.error, isNull);
      },
    );

    test('mientras espera la fase es "previewing"', () async {
      s.notifier.setFilter(s.filter());
      s.notifier.toggleSelection(7);
      s.repository.previewGate = Completer<void>();

      final pending = s.notifier.requestPreview();
      expect(s.state.phase, SuspendPhase.previewing);

      s.repository.previewGate!.complete();
      await pending;
      expect(s.state.phase, SuspendPhase.idle);
    });

    test('un segundo toque mientras espera no vuelve a llamar', () async {
      s.notifier.setFilter(s.filter());
      s.notifier.toggleSelection(7);
      s.repository.previewGate = Completer<void>();

      final first = s.notifier.requestPreview();
      final second = s.notifier.requestPreview();
      s.repository.previewGate!.complete();
      await Future.wait([first, second]);

      expect(s.repository.previewCalls, 1);
    });

    test(
      '"Volver" borra la vista previa y conserva seleccion y observacion',
      () async {
        await s.readyToConfirm(observation: 'aviso');

        s.notifier.dismissPreview();

        expect(s.state.preview, isNull);
        expect(s.state.selectedIds, {7, 9});
        expect(s.state.observation, 'aviso');
      },
    );

    test('"Volver" tambien borra el error que venia del dialogo', () async {
      await s.readyToConfirm(observation: 'aviso');
      s.repository.suspendScript.add(
        const StaleSuspensionConfirmationException('Cambio la cantidad.'),
      );
      await s.notifier.confirm();
      // La desactualizada deja la vista previa nueva y el aviso a la vista.
      expect(s.state.error, 'Cambio la cantidad.');
      expect(s.state.preview, isNotNull);

      s.notifier.dismissPreview();

      expect(s.state.error, isNull);
      expect(s.state.preview, isNull);
      expect(s.state.selectedIds, {7, 9});
      expect(s.state.observation, 'aviso');
    });

    test(
      'TURNO_NO_SUSPENDIBLE: muestra el error y mantiene la seleccion',
      () async {
        s.notifier.setFilter(s.filter());
        await s.settle();
        s.notifier.selectAll(const [7, 9]);
        s.repository.previewScript.add(
          const ShiftNotSuspendableException('Una fecha ya paso.'),
        );

        await s.notifier.requestPreview();

        expect(s.state.error, 'Una fecha ya paso.');
        expect(s.state.preview, isNull);
        expect(s.state.selectedIds, {7, 9});
        expect(s.state.phase, SuspendPhase.idle);
      },
    );

    test('NO_ENCONTRADO: muestra el error y limpia la seleccion', () async {
      s.notifier.setFilter(s.filter());
      await s.settle();
      s.notifier.selectAll(const [7, 9]);
      s.repository.previewScript.add(
        const ShiftNotFoundException('Una fecha ya no existe.'),
      );

      await s.notifier.requestPreview();

      expect(s.state.error, 'Una fecha ya no existe.');
      expect(s.state.selectedIds, isEmpty);
      expect(s.state.preview, isNull);
    });
  });

  group('confirmar', () {
    test('sin vista previa no llama al repositorio', () async {
      s.notifier.setFilter(s.filter());
      s.notifier.toggleSelection(7);

      await s.notifier.confirm();

      expect(s.repository.suspendCalls, 0);
    });

    test(
      'manda el filtro efectivo, los ids, la observacion recortada y el total',
      () async {
        await s.readyToConfirm(observation: '  aviso  ');

        await s.notifier.confirm();

        expect(
          s.repository.lastFilter,
          SuspensionFilter(
            doctorId: s.mendezId,
            specialtyId: 1,
            fromDate: DateTime.utc(2026, 11, 4),
            toDate: DateTime.utc(2026, 12, 30),
          ),
        );
        expect(s.repository.lastSuspendIds, [7, 9]);
        expect(s.repository.lastObservation, 'aviso');
        expect(s.repository.lastConfirmedCount, 3);
      },
    );

    test('una observacion de solo espacios se manda como ausente', () async {
      await s.readyToConfirm(observation: '   ');

      await s.notifier.confirm();

      expect(s.repository.suspendCalls, 1);
      expect(s.repository.lastObservation, isNull);
    });

    test(
      'exito: deja el resultado y limpia seleccion, vista previa y observacion',
      () async {
        await s.readyToConfirm(observation: 'aviso');

        await s.notifier.confirm();

        expect(s.state.result!.cancelledAppointments, 3);
        expect(s.state.result!.shifts.map((x) => x.shiftId), [7, 9]);
        expect(s.state.selectedIds, isEmpty);
        expect(s.state.preview, isNull);
        expect(s.state.observation, '');
        expect(s.state.error, isNull);
        expect(s.state.phase, SuspendPhase.idle);
        expect(s.stateOf(7), ShiftState.suspended);
        expect(s.stateOf(9), ShiftState.suspended);
        expect(s.stateOf(8), ShiftState.active);
      },
    );

    test(
      'exito: recarga los candidatos, que ya no traen los suspendidos',
      () async {
        await s.readyToConfirm();
        expect(await s.settle(), [5, 6, 7, 8, 9, 10, 11, 12, 13]);

        await s.notifier.confirm();

        expect(await s.settle(), [5, 6, 8, 10, 11, 12, 13]);
      },
    );

    test('exito: recarga el listado de turnos', () async {
      s.container.listen(shiftsPageProvider, (_, _) {});
      final before = await s.container.read(shiftsPageProvider.future);
      expect(
        before.items.firstWhere((x) => x.id == 7).state,
        ShiftState.active,
      );
      await s.readyToConfirm();

      await s.notifier.confirm();

      final after = await s.container.read(shiftsPageProvider.future);
      expect(
        after.items.firstWhere((x) => x.id == 7).state,
        ShiftState.suspended,
      );
    });

    test('mientras espera la fase es "confirming"', () async {
      await s.readyToConfirm();
      s.repository.suspendGate = Completer<void>();

      final pending = s.notifier.confirm();
      expect(s.state.phase, SuspendPhase.confirming);

      s.repository.suspendGate!.complete();
      await pending;
      expect(s.state.phase, SuspendPhase.idle);
    });

    test('dos toques seguidos hacen una sola llamada', () async {
      await s.readyToConfirm();
      s.repository.suspendGate = Completer<void>();

      final first = s.notifier.confirm();
      final second = s.notifier.confirm();
      s.repository.suspendGate!.complete();
      await Future.wait([first, second]);

      expect(s.repository.suspendCalls, 1);
    });
  });

  group('observacion', () {
    test(
      'de 1001 caracteres: error visible y no llama al repositorio',
      () async {
        await s.readyToConfirm(observation: 'a' * 1001);

        await s.notifier.confirm();

        expect(s.state.error, isNotNull);
        expect(s.state.error, isNotEmpty);
        expect(s.repository.suspendCalls, 0);
        expect(s.state.preview, isNotNull);
        expect(s.state.phase, SuspendPhase.idle);
      },
    );

    test('de exactamente 1000 caracteres pasa', () async {
      await s.readyToConfirm(observation: 'a' * 1000);

      await s.notifier.confirm();

      expect(s.repository.suspendCalls, 1);
      expect(s.state.result, isNotNull);
    });

    test('se mide despues de recortar: un espacio mas 1000 pasa', () async {
      await s.readyToConfirm(observation: ' ${'a' * 1000}');

      await s.notifier.confirm();

      expect(s.repository.suspendCalls, 1);
      expect(s.repository.lastObservation, 'a' * 1000);
    });

    test('al editarla se borra el error', () async {
      await s.readyToConfirm(observation: 'a' * 1001);
      await s.notifier.confirm();
      expect(s.state.error, isNotNull);

      s.notifier.setObservation('a' * 1000);

      expect(s.state.error, isNull);
    });
  });

  group('CONFIRMACION_DESACTUALIZADA', () {
    test('vuelve a previsualizar, conserva la observacion y avisa', () async {
      await s.readyToConfirm(observation: 'x');
      s.repository.suspendScript.add(
        const StaleSuspensionConfirmationException('Cambio la cantidad.'),
      );
      // Mientras tanto el turno 7 pasa de 2 a 3 consultas.
      s.appointments[7] = 3;

      await s.notifier.confirm();

      expect(s.repository.suspendCalls, 1);
      expect(s.repository.previewCalls, 2);
      expect(s.state.preview!.totalAppointments, 4);
      expect(s.state.observation, 'x');
      expect(s.state.error, 'Cambio la cantidad.');
      expect(s.state.selectedIds, {7, 9});
      expect(s.state.phase, SuspendPhase.idle);
    });

    test('despues se puede confirmar con el total nuevo', () async {
      await s.readyToConfirm(observation: 'x');
      s.repository.suspendScript.add(
        const StaleSuspensionConfirmationException('Cambio la cantidad.'),
      );
      s.appointments[7] = 3;
      await s.notifier.confirm();

      await s.notifier.confirm();

      expect(s.repository.lastConfirmedCount, 4);
      expect(s.state.result!.cancelledAppointments, 4);
      expect(s.state.error, isNull);
    });

    test(
      'si la nueva previsualizacion falla, deja ese error y borra la vieja',
      () async {
        await s.readyToConfirm(observation: 'x');
        s.repository.suspendScript.add(
          const StaleSuspensionConfirmationException('Cambio la cantidad.'),
        );
        s.repository.previewScript.add(
          const ShiftNotSuspendableException('Una fecha ya paso.'),
        );

        await s.notifier.confirm();

        expect(s.state.error, 'Una fecha ya paso.');
        expect(s.state.preview, isNull);
        expect(s.state.observation, 'x');
        expect(s.state.selectedIds, {7, 9});
      },
    );
  });

  group('otros errores al confirmar', () {
    test(
      'TURNO_NO_SUSPENDIBLE: error, vista previa fuera, seleccion vigente',
      () async {
        await s.readyToConfirm();
        // El turno 8 no estaba elegido: se elige y se suspende por otro lado.
        s.notifier.toggleSelection(8);
        await s.notifier.requestPreview();
        s.db.suspendShift(8);

        await s.notifier.confirm();
        await s.settle();

        expect(s.state.error, isNotNull);
        expect(s.state.error, isNotEmpty);
        expect(s.state.preview, isNull);
        // La lista se recarga y el 8 ya no esta; los demas siguen elegidos.
        expect(s.state.selectedIds, {7, 9});
        expect(s.stateOf(7), ShiftState.active);
      },
    );

    test(
      'NO_ENCONTRADO: error, limpia la seleccion y recarga los candidatos',
      () async {
        await s.readyToConfirm();
        s.db.shifts.removeWhere((x) => x.id == 7);

        await s.notifier.confirm();

        expect(s.state.error, isNotNull);
        expect(s.state.error, isNotEmpty);
        expect(s.state.selectedIds, isEmpty);
        expect(s.state.preview, isNull);
        expect(await s.settle(), [5, 6, 8, 9, 10, 11, 12, 13]);
      },
    );

    test(
      'VALIDACION: muestra el mensaje y deja la vista previa abierta',
      () async {
        await s.readyToConfirm(observation: 'x');
        s.repository.suspendScript.add(
          const ShiftValidationException('Dato invalido.'),
        );

        await s.notifier.confirm();

        expect(s.state.error, 'Dato invalido.');
        expect(s.state.preview, isNotNull);
        expect(s.state.selectedIds, {7, 9});
        expect(s.state.observation, 'x');
      },
    );

    test(
      'error de red: conserva todo y "retry" repite la confirmacion',
      () async {
        await s.readyToConfirm(observation: 'x');
        s.repository.suspendScript.add(
          const ApiException(kApiNoConnectionMessage),
        );

        await s.notifier.confirm();

        expect(s.state.error, kApiNoConnectionMessage);
        expect(s.state.preview, isNotNull);
        expect(s.state.selectedIds, {7, 9});
        expect(s.state.observation, 'x');
        expect(s.state.phase, SuspendPhase.idle);

        await s.notifier.retry();

        expect(s.repository.suspendCalls, 2);
        expect(s.state.result!.cancelledAppointments, 3);
        expect(s.state.error, isNull);
      },
    );

    test(
      'error de red al previsualizar: "retry" repite la previsualizacion',
      () async {
        s.notifier.setFilter(s.filter());
        await s.settle();
        s.notifier.selectAll(const [7, 9]);
        s.repository.previewScript.add(
          const ApiException(kApiNoConnectionMessage),
        );

        await s.notifier.requestPreview();

        expect(s.state.error, kApiNoConnectionMessage);
        expect(s.state.preview, isNull);
        expect(s.state.selectedIds, {7, 9});

        await s.notifier.retry();

        expect(s.repository.previewCalls, 2);
        expect(s.state.preview!.totalAppointments, 3);
        expect(s.state.error, isNull);
      },
    );

    test('"retry" sin una accion anterior no hace nada', () async {
      await s.notifier.retry();

      expect(s.repository.previewCalls, 0);
      expect(s.repository.suspendCalls, 0);
    });

    test('un error que no es de la API muestra el mensaje generico', () async {
      await s.readyToConfirm();
      s.repository.suspendScript.add(StateError('algo salio mal'));

      await s.notifier.confirm();

      expect(s.state.error, kApiGenericMessage);
      expect(s.state.preview, isNotNull);
      expect(s.state.phase, SuspendPhase.idle);
    });

    test(
      'cada error conserva su propio mensaje, distinto de los otros',
      () async {
        final failures = <Object>[
          const StaleSuspensionConfirmationException('m-desactualizada'),
          const ShiftNotSuspendableException('m-no-suspendible'),
          const ShiftNotFoundException('m-no-encontrado'),
          const ShiftValidationException('m-validacion'),
          const ApiException('m-servidor'),
        ];
        final seen = <String>{};

        for (final failure in failures) {
          final run = _Setup();
          addTearDown(run.container.dispose);
          await run.readyToConfirm();
          // Para la desactualizada, la nueva previsualizacion tiene que andar.
          run.repository.suspendScript.add(failure);

          await run.notifier.confirm();

          final message = run.state.error;
          expect(message, isNotNull, reason: '$failure');
          expect(message, isNotEmpty, reason: '$failure');
          seen.add(message!);
        }

        expect(seen, {
          'm-desactualizada',
          'm-no-suspendible',
          'm-no-encontrado',
          'm-validacion',
          'm-servidor',
        });
      },
    );
  });
}
