import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/models/suspension_preview.dart';
import 'package:agenda_medica/features/turnos/models/suspension_result.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shift_suspension_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_candidates_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_clock_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_fake_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/suspend_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

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
  Completer<void>? suspendGate;

  int previewCalls = 0;
  int suspendCalls = 0;

  @override
  Future<SuspensionPreview> preview(List<int> ids) async {
    previewCalls++;
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

/// El repositorio de turnos falso con un guion para `listShifts`: la primera
/// entrada de [listScript] se tira como error (si no es `null`) y [listGate]
/// demora la respuesta.
class _ShiftRepo implements ShiftRepository {
  _ShiftRepo(this._inner);

  final ShiftRepository _inner;
  final List<Object?> listScript = [];
  Completer<void>? listGate;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    await listGate?.future;
    if (listScript.isNotEmpty) {
      final next = listScript.removeAt(0);
      if (next != null) throw next;
    }
    return _inner.listShifts(filters);
  }

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      _inner.listDoctors(specialtyId: specialtyId);

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _inner.createWeeklyShift(data);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _inner.getWeeklyShift(id);
}

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// Turnos de los tests, sin sembrar el resto (`seed: false`).
///
/// Configuracion 1: Mendez, Medicina General (especialidad 1), todos los
/// miercoles del 07/10/2026 al 30/12/2026, de 09:00 a 09:20. Ids por fecha:
/// 1 = 07/10, 2 = 14/10, 3 = 21/10, 4 = 28/10, 5 = 04/11 (hoy), 6 = 11/11,
/// 7 = 18/11, 8 = 25/11, 9 = 02/12, 10 = 09/12, 11 = 16/12, 12 = 23/12,
/// 13 = 30/12.
///
/// Configuracion 2: Silva, Cardiologia (especialidad 2), el jueves 05/11/2026:
/// el turno 14.
///
/// Consultas: {7: 2, 9: 1}; fuera del mapa, id % 3.
class _Setup {
  _Setup() {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
    mendez = _doctor('Méndez');
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: mendez.id,
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
        doctorId: _doctor('Silva').id,
        specialtyId: 2,
        clinicId: admin.clinics[1].id,
        weekday: 4,
        startDate: DateTime.utc(2026, 11, 5),
        endDate: DateTime.utc(2026, 11, 5),
        numbers: [_n(1, '15:00', '15:30')],
      ),
    );
    shifts = _ShiftRepo(FakeShiftRepository(db, latency: Duration.zero));
    suspension = _ScriptedRepository(
      FakeShiftSuspensionRepository(
        db,
        appointmentsByShift: appointments,
        today: () => _today,
        latency: Duration.zero,
      ),
    );
  }

  late final FakeAdminDatabase admin;
  late final FakeShiftDatabase db;
  late final DoctorRef mendez;
  late final _ShiftRepo shifts;
  late final _ScriptedRepository suspension;

  /// No es `const` para poder cambiar las consultas de un turno a mitad de un
  /// test.
  final Map<int, int> appointments = {7: 2, 9: 1};

  DoctorRef _doctor(String lastName) {
    final account = admin.accounts.firstWhere(
      (a) => a.role == UserRole.medico && a.lastName == lastName,
    );
    return DoctorRef(
      id: account.id,
      firstName: account.firstName,
      lastName: account.lastName,
    );
  }

  String get specialtyName =>
      admin.specialties.firstWhere((s) => s.id == 1).name;

  List<Override> get overrides => [
    shiftRepositoryProvider.overrideWith((ref) async => shifts),
    shiftSuspensionRepositoryProvider.overrideWith((ref) async => suspension),
    suspensionClockProvider.overrideWithValue(() => _today),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  _Setup s, {
  Size size = const Size(900, 1800),
  List<Override> extra = const [],
}) => pumpAdminScreens(
  tester,
  size: size,
  initialLocation: kSuspendShiftsPath,
  routes: [
    GoRoute(
      path: kSuspendShiftsPath,
      builder: (_, _) => const SuspendShiftsScreen(),
    ),
  ],
  overrides: [...s.overrides, ...extra],
);

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

Future<void> _enterDate(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

/// Elige a Mendez y Medicina General, escribe el rango (01/10 al 30/12,
/// dentro del pasado) y toca "Buscar".
Future<void> _search(
  WidgetTester tester,
  _Setup s, {
  String from = '01/10/2026',
  String to = '30/12/2026',
}) async {
  await tester.tap(find.byKey(const Key('suspend-doctor')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(s.mendez.fullName).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('suspend-specialty')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(s.specialtyName).last);
  await tester.pumpAndSettle();
  await _enterDate(tester, 'Desde', from);
  await _enterDate(tester, 'Hasta', to);
  await tester.tap(find.byKey(const Key('suspend-search')));
  await tester.pumpAndSettle();
}

Future<void> _check(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('suspend-check-$id')));
  await tester.pump();
}

/// Busca, elige el 7 y el 9 y abre el dialogo: 2 fechas y 3 consultas.
Future<void> _openDialog(WidgetTester tester, _Setup s) async {
  await _search(tester, s);
  await _check(tester, 7);
  await _check(tester, 9);
  await tester.tap(find.byKey(const Key('preview-suspension')));
  await tester.pumpAndSettle();
}

Finder get _dialog => find.byType(AlertDialog);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog, matching: finder);

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirm-suspension')));
  await tester.pumpAndSettle();
}

String _totalShown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('suspension-total'))).data!;

void main() {
  late _Setup s;

  setUp(() => s = _Setup());

  group('el formulario', () {
    testWidgets('al abrir, "Desde" ya trae hoy y no hay lista', (tester) async {
      await _pump(tester, s);

      final from = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Desde'),
      );
      expect(from.controller!.text, '04/11/2026');
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(_enabled(tester, 'suspend-search'), isFalse);
    });

    testWidgets('"Buscar" se habilita con medico, especialidad y fechas', (
      tester,
    ) async {
      await _pump(tester, s);
      await tester.tap(find.byKey(const Key('suspend-doctor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.mendez.fullName).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-specialty')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.specialtyName).last);
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'suspend-search'), isFalse); // falta "Hasta"

      await _enterDate(tester, 'Hasta', '30/12/2026');

      expect(_enabled(tester, 'suspend-search'), isTrue);
    });

    testWidgets('un "Desde" posterior a "Hasta" muestra el error y no busca', (
      tester,
    ) async {
      await _pump(tester, s);

      await _search(tester, s, from: '10/12/2026', to: '01/12/2026');

      expect(
        find.text(
          'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
        ),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('buscar con un "Desde" pasado lo ajusta a hoy', (tester) async {
      await _pump(tester, s);

      await _search(tester, s);

      final from = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Desde'),
      );
      expect(from.controller!.text, '04/11/2026');
    });
  });

  group('la lista', () {
    testWidgets('ofrece las fechas activas de hoy en adelante: del 5 al 13', (
      tester,
    ) async {
      await _pump(tester, s);

      await _search(tester, s);

      for (final id in [5, 6, 7, 8, 9, 10, 11, 12, 13]) {
        expect(
          find.byKey(Key('suspend-check-$id')),
          findsOneWidget,
          reason: '$id',
        );
      }
      // El 4 es del 28/10 (pasado) y el 14 es de otro medico.
      expect(find.byKey(const Key('suspend-check-4')), findsNothing);
      expect(find.byKey(const Key('suspend-check-14')), findsNothing);
      expect(find.text('Elegidas: 0'), findsOneWidget);
    });

    testWidgets('con 0 elegidas "Previsualizar" esta deshabilitado', (
      tester,
    ) async {
      await _pump(tester, s);
      await _search(tester, s);

      expect(_enabled(tester, 'preview-suspension'), isFalse);
    });

    testWidgets('elegir una habilita "Previsualizar" y suma al contador', (
      tester,
    ) async {
      await _pump(tester, s);
      await _search(tester, s);

      await _check(tester, 7);

      expect(_enabled(tester, 'preview-suspension'), isTrue);
      expect(find.text('Elegidas: 1'), findsOneWidget);
    });

    testWidgets('"Seleccionar todas" elige las 9 y volver a tocarlo las saca', (
      tester,
    ) async {
      await _pump(tester, s);
      await _search(tester, s);

      await tester.tap(find.byKey(const Key('suspend-select-all')));
      await tester.pump();
      expect(find.text('Elegidas: 9'), findsOneWidget);

      await tester.tap(find.byKey(const Key('suspend-select-all')));
      await tester.pump();
      expect(find.text('Elegidas: 0'), findsOneWidget);
    });

    testWidgets('sin fechas en el rango avisa que no hay nada', (tester) async {
      await _pump(tester, s);

      // Del 01/10 al 03/11: todo en el pasado.
      await _search(tester, s, to: '03/11/2026');

      expect(
        find.text(
          'No hay fechas activas para suspender con esos filtros. Cambiá el '
          'rango y buscá de nuevo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('mientras carga muestra el indicador de progreso', (
      tester,
    ) async {
      await _pump(tester, s);
      s.shifts.listGate = Completer<void>();

      await tester.tap(find.byKey(const Key('suspend-doctor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.mendez.fullName).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-specialty')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.specialtyName).last);
      await tester.pumpAndSettle();
      await _enterDate(tester, 'Hasta', '30/12/2026');
      await tester.tap(find.byKey(const Key('suspend-search')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      s.shifts.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('suspend-check-5')), findsOneWidget);
    });

    testWidgets('si falla la carga muestra el aviso y "Reintentar" la repite', (
      tester,
    ) async {
      await _pump(tester, s);
      s.shifts.listScript.add(const ApiException(kApiNoConnectionMessage));

      await _search(tester, s);

      expect(
        find.text('No pudimos cargar las fechas. Intentá de nuevo.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('suspend-check-5')), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('suspend-check-5')), findsOneWidget);
    });

    testWidgets('con mas de 500 fechas avisa que se achique el rango', (
      tester,
    ) async {
      await _pump(
        tester,
        s,
        extra: [
          suspensionCandidatesProvider.overrideWith(
            (ref, filter) async =>
                throw const TooManySuspensionCandidatesException(),
          ),
        ],
      );

      await _search(tester, s);

      expect(
        find.text(
          'Hay más de 500 fechas en ese rango. Elegí un rango más corto y '
          'buscá de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  group('el dialogo', () {
    testWidgets('con 2 elegidas muestra las 2 fechas y "3" consultas', (
      tester,
    ) async {
      await _pump(tester, s);

      await _openDialog(tester, s);

      expect(_dialog, findsOneWidget);
      expect(_inDialog(find.textContaining('18/11/2026')), findsOneWidget);
      expect(_inDialog(find.textContaining('02/12/2026')), findsOneWidget);
      expect(
        _inDialog(find.textContaining('Consultas a cancelar: 2')),
        findsOneWidget,
      );
      expect(
        _inDialog(find.textContaining('Consultas a cancelar: 1')),
        findsOneWidget,
      );
      expect(_totalShown(tester), '3');
      expect(s.suspension.previewCalls, 1);
    });

    testWidgets('"Volver" cierra el dialogo y deja la seleccion', (
      tester,
    ) async {
      await _pump(tester, s);
      await _openDialog(tester, s);

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(find.text('Elegidas: 2'), findsOneWidget);
      expect(s.suspension.suspendCalls, 0);
    });

    testWidgets('el contador de la observacion cuenta los caracteres', (
      tester,
    ) async {
      await _pump(tester, s);
      await _openDialog(tester, s);

      await tester.enterText(
        find.byKey(const Key('suspension-observation')),
        'aviso',
      );
      await tester.pump();

      expect(find.text('5/1000'), findsOneWidget);
    });

    testWidgets(
      'una observacion de 1001 caracteres muestra el error y no suspende',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);

        await tester.enterText(
          find.byKey(const Key('suspension-observation')),
          'a' * 1001,
        );
        await tester.pump();
        expect(find.text('1001/1000'), findsOneWidget);
        await _confirm(tester);

        expect(
          _inDialog(
            find.text(
              'La observación puede tener hasta 1000 caracteres. Acortala y '
              'confirmá de nuevo.',
            ),
          ),
          findsOneWidget,
        );
        expect(s.suspension.suspendCalls, 0);
        expect(_dialog, findsOneWidget);
      },
    );

    testWidgets('una observacion de 1000 caracteres pasa', (tester) async {
      await _pump(tester, s);
      await _openDialog(tester, s);

      await tester.enterText(
        find.byKey(const Key('suspension-observation')),
        'a' * 1000,
      );
      await tester.pump();
      await _confirm(tester);

      expect(s.suspension.suspendCalls, 1);
      expect(_dialog, findsNothing);
    });
  });

  group('confirmar', () {
    testWidgets(
      'dos toques seguidos en "Suspender fechas" hacen una sola llamada',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);
        s.suspension.suspendGate = Completer<void>();

        await tester.tap(find.byKey(const Key('confirm-suspension')));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('confirm-suspension')),
          warnIfMissed: false,
        );
        await tester.pump();
        s.suspension.suspendGate!.complete();
        await tester.pumpAndSettle();

        expect(s.suspension.suspendCalls, 1);
      },
    );

    testWidgets(
      'tras confirmar, la lista recargada ya no ofrece las suspendidas',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);

        await _confirm(tester);

        expect(_dialog, findsNothing);
        expect(find.byKey(const Key('suspend-check-7')), findsNothing);
        expect(find.byKey(const Key('suspend-check-9')), findsNothing);
        expect(find.byKey(const Key('suspend-check-8')), findsOneWidget);
        expect(find.text('Elegidas: 0'), findsOneWidget);
        expect(
          find.text('Fechas suspendidas: 2. Consultas canceladas: 3.'),
          findsOneWidget,
        );
      },
    );
  });

  group('cada error muestra su propio mensaje', () {
    testWidgets(
      'TURNO_NO_SUSPENDIBLE: cierra el dialogo y avisa en la pantalla',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);
        s.suspension.suspendScript.add(
          const ShiftNotSuspendableException('m-no-suspendible'),
        );

        await _confirm(tester);

        expect(_dialog, findsNothing);
        expect(find.text('m-no-suspendible'), findsOneWidget);
      },
    );

    testWidgets(
      'NO_ENCONTRADO: cierra el dialogo, avisa y limpia la seleccion',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);
        s.suspension.suspendScript.add(
          const ShiftNotFoundException('m-no-encontrado'),
        );

        await _confirm(tester);

        expect(_dialog, findsNothing);
        expect(find.text('m-no-encontrado'), findsOneWidget);
        expect(find.text('Elegidas: 0'), findsOneWidget);
      },
    );

    testWidgets('VALIDACION: el dialogo sigue abierto con el mensaje', (
      tester,
    ) async {
      await _pump(tester, s);
      await _openDialog(tester, s);
      s.suspension.suspendScript.add(
        const ShiftValidationException('m-validacion'),
      );

      await _confirm(tester);

      expect(_dialog, findsOneWidget);
      expect(_inDialog(find.text('m-validacion')), findsOneWidget);
    });

    testWidgets('red: el dialogo sigue abierto y volver a confirmar funciona', (
      tester,
    ) async {
      await _pump(tester, s);
      await _openDialog(tester, s);
      s.suspension.suspendScript.add(
        const ApiException(kApiNoConnectionMessage),
      );

      await _confirm(tester);

      expect(_dialog, findsOneWidget);
      expect(_inDialog(find.text(kApiNoConnectionMessage)), findsOneWidget);

      await _confirm(tester);

      expect(s.suspension.suspendCalls, 2);
      expect(_dialog, findsNothing);
    });

    testWidgets(
      'desactualizada: el dialogo sigue abierto con el total nuevo y el aviso',
      (tester) async {
        await _pump(tester, s);
        await _openDialog(tester, s);
        s.suspension.suspendScript.add(
          const StaleSuspensionConfirmationException('m-desactualizada'),
        );
        // Mientras tanto el turno 7 pasa de 2 a 3 consultas.
        s.appointments[7] = 3;

        await _confirm(tester);

        expect(_dialog, findsOneWidget);
        expect(_inDialog(find.text('m-desactualizada')), findsOneWidget);
        expect(_totalShown(tester), '4');
        expect(s.suspension.previewCalls, 2);
      },
    );

    testWidgets(
      'error al previsualizar: avisa en la pantalla y no abre el dialogo',
      (tester) async {
        await _pump(tester, s);
        await _search(tester, s);
        await _check(tester, 7);
        s.suspension.previewScript.add(
          const ApiException(kApiNoConnectionMessage),
        );

        await tester.tap(find.byKey(const Key('preview-suspension')));
        await tester.pumpAndSettle();

        expect(_dialog, findsNothing);
        expect(find.text(kApiNoConnectionMessage), findsOneWidget);
        expect(find.text('Elegidas: 1'), findsOneWidget);
      },
    );
  });

  group('sin desbordes', () {
    for (final width in [400.0, 900.0]) {
      testWidgets('con $width px de ancho: formulario, lista y dialogo', (
        tester,
      ) async {
        await _pump(tester, s, size: Size(width, 1800));
        expect(tester.takeException(), isNull);

        await _search(tester, s);
        expect(tester.takeException(), isNull);

        await _check(tester, 7);
        await _check(tester, 9);
        await tester.tap(find.byKey(const Key('preview-suspension')));
        await tester.pumpAndSettle();
        expect(_dialog, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byKey(const Key('suspension-observation')),
          'a' * 1001,
        );
        await _confirm(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
