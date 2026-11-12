import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/models/clinic_change_preview.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/weekly_shift_clinic_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_weekly_shift_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/weekly_shift_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/weekly_shift_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../../helpers/shift_listing_data.dart';

/// Falla la primera vez que se pide la configuración, como un corte de red.
class _FlakyShiftRepository extends FakeShiftRepository {
  _FlakyShiftRepository(super.db) : super(latency: Duration.zero);

  int calls = 0;

  @override
  Future<WeeklyShift> getWeeklyShift(int id) async {
    calls++;
    if (calls == 1) throw const ApiException();
    return super.getWeeklyShift(id);
  }
}

class _Harness {
  _Harness(this.admin, this.shiftDb, this.router, this.repository);

  final FakeAdminDatabase admin;
  final FakeShiftDatabase shiftDb;
  final GoRouter router;
  final FakeShiftRepository repository;
}

class _RecordingClinicChange implements WeeklyShiftClinicRepository {
  _RecordingClinicChange(this.db, {this.gate});

  final FakeShiftDatabase db;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  ) async => db.previewClinicChange(weeklyShiftId, clinicId);

  @override
  Future<WeeklyShift> changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    return db.changeClinic(
      weeklyShiftId,
      clinicId,
      turnoIds: turnoIds,
      confirmarConConsultas: confirmarConConsultas,
    );
  }
}

class _NotFoundClinic implements WeeklyShiftClinicRepository {
  @override
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  ) async {
    throw const ShiftNotFoundException('No existe el consultorio indicado');
  }

  @override
  Future<WeeklyShift> changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  }) async {
    throw const ShiftNotFoundException('No existe el consultorio indicado');
  }
}

class _BrokenClinics implements ClinicRepository {
  @override
  Future<List<Clinic>> list() async => throw const ApiException();

  @override
  Future<Clinic> create({required String name, required String location}) {
    throw UnimplementedError();
  }
}

const _currentClinic =
    'Consultorio actual: Consultorio 3 (Planta baja). Cambia las fechas de '
    'hoy en adelante; las fechas pasadas conservan su consultorio.';

/// Monta el detalle de la configuración [index] de `buildListingDb` (0 es la
/// de Méndez; 2, la de Acosta), o del id indicado en [id].
Future<_Harness> _pump(
  WidgetTester tester, {
  int index = 0,
  int? id,
  Size size = const Size(900, 1800),
  bool flaky = false,
  bool clinicsFail = false,
  WeeklyShiftClinicRepository Function(FakeShiftDatabase db)? clinicChange,
}) async {
  final admin = FakeAdminDatabase(clock: () => DateTime.utc(2026, 10, 20, 15));
  final shiftDb = buildListingDb(admin);
  final repository = flaky
      ? _FlakyShiftRepository(shiftDb)
      : FakeShiftRepository(shiftDb, latency: Duration.zero);
  final weeklyShiftId = id ?? shiftDb.weeklyShifts[index].id;
  final clinicRepository =
      clinicChange?.call(shiftDb) ??
      FakeWeeklyShiftClinicRepository(shiftDb, latency: Duration.zero);
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: weeklyShiftDetailLocation(weeklyShiftId),
    routes: [
      GoRoute(
        path: kShiftsPath,
        builder: (_, _) => const Scaffold(body: Text('Listado de turnos')),
      ),
      GoRoute(
        path: kWeeklyShiftDetailPath,
        builder: (_, state) =>
            WeeklyShiftDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
    overrides: [
      shiftRepositoryProvider.overrideWith((ref) async => repository),
      clinicRepositoryProvider.overrideWith(
        (ref) async => clinicsFail
            ? _BrokenClinics()
            : FakeClinicRepository(admin, latency: Duration.zero),
      ),
      weeklyShiftClinicRepositoryProvider.overrideWith(
        (ref) async => clinicRepository,
      ),
    ],
  );
  return _Harness(admin, shiftDb, router, repository);
}

Future<void> _openDialog(WidgetTester tester) async {
  final button = find.byKey(const Key('weekly-shift-change-clinic'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pickClinic(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('weekly-shift-clinic-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Abre el detalle de un turno de Acosta con 5 fechas: miércoles del 21/10 al
/// 18/11/2026 (hoy es el 20/10), todas en el Consultorio 3. La primera está
/// suspendida. Devuelve las fechas ordenadas y el id del turno semanal.
Future<(_Harness, List<FakeShift>)> _pumpFiveDates(
  WidgetTester tester, {
  void Function(FakeShiftDatabase db, int weeklyShiftId, List<FakeShift> dates)?
  prepare,
}) async {
  final harness = await _pump(tester);
  final acosta = harness.admin.accounts.firstWhere(
    (account) =>
        account.role == UserRole.medico && account.lastName == 'Acosta',
  );
  final weekly = harness.shiftDb.createWeeklyShift(
    NewWeeklyShift(
      doctorId: acosta.id,
      specialtyId: 3,
      clinicId: harness.admin.clinics.first.id,
      weekday: 3,
      startDate: DateTime.utc(2026, 10, 21),
      endDate: DateTime.utc(2026, 11, 18),
      numbers: [
        ShiftNumber(number: 1, startMinutes: 10 * 60, endMinutes: 10 * 60 + 20),
      ],
    ),
  );
  final dates =
      harness.shiftDb.shifts
          .where((shift) => shift.weeklyShiftId == weekly.id)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  expect(dates, hasLength(5));
  harness.shiftDb.suspendShift(dates.first.id);
  prepare?.call(harness.shiftDb, weekly.id, dates);
  harness.router.go(weeklyShiftDetailLocation(weekly.id));
  await tester.pumpAndSettle();
  return (harness, dates);
}

Future<void> _uncheck(WidgetTester tester, FakeShift date) async {
  final row = find.byKey(Key('weekly-shift-date-${date.id}'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

ButtonStyleButton _saveButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(
      find.byKey(const Key('weekly-shift-clinic-save')),
    );

void main() {
  group('las rutas', () {
    test('la del detalle lleva el id como parámetro', () {
      expect(kWeeklyShiftDetailPath, '/funcionario/turnos/configuracion/:id');
    });

    test('weeklyShiftDetailLocation arma la ruta con el id', () {
      expect(
        weeklyShiftDetailLocation(7),
        '/funcionario/turnos/configuracion/7',
      );
    });

    test('la ruta armada coincide con el patrón de la constante', () {
      final pattern = RegExp(
        '^${kWeeklyShiftDetailPath.replaceFirst(':id', r'(\d+)')}\$',
      );
      expect(pattern.hasMatch(weeklyShiftDetailLocation(123)), isTrue);
    });

    test('el alta y el listado cuelgan de la misma sección', () {
      expect(kShiftsPath, '/funcionario/turnos');
      expect(kNewWeeklyShiftPath, '/funcionario/turnos/nuevo');
    });
  });

  group('la configuración', () {
    testWidgets('muestra médico, especialidad, consultorio, día y vigencia', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Carla Méndez'), findsOneWidget);
      expect(find.text('Medicina General'), findsOneWidget);
      expect(find.text('Consultorio 3 (Planta baja)'), findsOneWidget);
      expect(find.text('Martes'), findsOneWidget);
      expect(find.text('Del 20/10/2026 al 10/11/2026'), findsOneWidget);
    });

    testWidgets('muestra los números con su horario y duración', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Número 1: 09:00 – 09:20 (20 min)'), findsOneWidget);
      expect(find.text('Número 2: 09:20 – 09:40 (20 min)'), findsOneWidget);
    });

    testWidgets('muestra cuántas fechas se generaron', (tester) async {
      await _pump(tester);

      expect(find.text('4 fechas'), findsOneWidget);
    });

    testWidgets('otra configuración: 23 fechas y 3 números', (tester) async {
      await _pump(tester, index: 2);

      expect(find.text('Florencia Acosta'), findsOneWidget);
      expect(find.text('Lunes'), findsOneWidget);
      expect(find.text('23 fechas'), findsOneWidget);
      expect(find.text('Número 3: 10:40 – 11:00 (20 min)'), findsOneWidget);
    });

    testWidgets('con una sola fecha dice "1 fecha"', (tester) async {
      // La cuarta configuración (Silva, lunes 19/10) tiene una fecha.
      await _pump(tester, index: 3);

      expect(find.text('1 fecha'), findsOneWidget);
      expect(find.text('Del 19/10/2026 al 19/10/2026'), findsOneWidget);
    });

    testWidgets('"Volver al listado" lleva a la consulta de turnos', (
      tester,
    ) async {
      final harness = await _pump(tester);

      await tester.tap(find.text('Volver al listado'));
      await tester.pumpAndSettle();

      expect(currentLocation(harness.router), kShiftsPath);
      expect(find.text('Listado de turnos'), findsOneWidget);
    });
  });

  group('errores de carga', () {
    testWidgets('si falla, avisa y "Reintentar" vuelve a pedir', (
      tester,
    ) async {
      final harness = await _pump(tester, flaky: true);

      expect(
        find.text('No pudimos cargar el turno semanal. Intentá de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Carla Méndez'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect((harness.repository as _FlakyShiftRepository).calls, 2);
      expect(
        find.text('No pudimos cargar el turno semanal. Intentá de nuevo.'),
        findsNothing,
      );
      expect(find.text('Carla Méndez'), findsOneWidget);
    });

    testWidgets('un id que no existe avisa y no ofrece reintentar', (
      tester,
    ) async {
      await _pump(tester, id: 9999);

      expect(
        find.text(
          'Ese turno semanal no existe o ya no está disponible. Volvé al '
          'listado y buscalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Volver al listado'), findsOneWidget);
    });
  });

  group('según el ancho de la pantalla', () {
    for (final width in [400.0, 700.0, 1100.0]) {
      testWidgets('con $width px no hay desbordes', (tester) async {
        await _pump(tester, index: 2, size: Size(width, 1800));

        expect(find.text('Florencia Acosta'), findsOneWidget);
        expect(find.text('Del 19/10/2026 al 22/03/2027'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('con 400 px el error de carga tampoco desborda', (
      tester,
    ) async {
      await _pump(tester, flaky: true, size: const Size(400, 900));

      expect(tester.takeException(), isNull);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('cambiar consultorio', () {
    testWidgets('abre con el actual elegido y Guardar deshabilitado', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final room3Id = harness.admin.clinics
          .firstWhere((clinic) => clinic.name == 'Consultorio 3')
          .id;

      await _openDialog(tester);

      expect(find.text('Cambiar consultorio'), findsWidgets);
      expect(find.text(_currentClinic), findsOneWidget);
      expect(
        tester
            .state<FormFieldState<int>>(
              find.byKey(const Key('weekly-shift-clinic-select')),
            )
            .value,
        room3Id,
      );
      expect(_saveButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const Key('weekly-shift-clinic-select')));
      await tester.pumpAndSettle();
      const names = ['Consultorio 3', 'Consultorio 7', 'Consultorio 12'];
      for (var i = 1; i < names.length; i++) {
        expect(
          tester.getTopLeft(find.text(names[i - 1]).last).dy,
          lessThan(tester.getTopLeft(find.text(names[i]).last).dy),
        );
      }
    });

    testWidgets('elegir otro consultorio habilita Guardar', (tester) async {
      await _pump(tester);
      await _openDialog(tester);

      await _pickClinic(tester, 'Consultorio 7');

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('guardar cierra, avisa y muestra el consultorio nuevo', (
      tester,
    ) async {
      await _pump(tester);
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Consultorio actualizado.'), findsOneWidget);
      expect(find.text('Consultorio 7 (Piso 1)'), findsOneWidget);
      expect(find.text('Consultorio 3 (Planta baja)'), findsNothing);
    });

    testWidgets('elegir solo algunas fechas conserva las demás', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final patternId = harness.shiftDb.weeklyShifts.first.id;
      final first = harness.shiftDb.shifts.firstWhere(
        (shift) => shift.weeklyShiftId == patternId,
      );
      final originalClinic = first.clinicId;
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      final checkbox = find.byKey(Key('weekly-shift-date-${first.id}'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);

      await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
      await tester.pumpAndSettle();

      expect(first.clinicId, originalClinic);
      expect(
        harness.shiftDb.weeklyShiftById(patternId)!.clinicVariesByDate,
        isTrue,
      );
      expect(
        find.textContaining('El consultorio varía según la fecha'),
        findsOneWidget,
      );
    });

    testWidgets('cambiar de consultorio vuelve a marcar todas las fechas', (
      tester,
    ) async {
      // La configuración de Méndez tiene 4 fechas desde hoy (20/10/2026):
      // 20/10, 27/10 (suspendida), 03/11 y 10/11. Se agrega un turno de
      // Acosta en el Consultorio 7 el 20/10 que se solapa con el número 1:
      // en el 7 esa fecha no se puede elegir; en el 12 las 4 sí.
      final harness = await _pump(tester);
      final acosta = harness.admin.accounts.firstWhere(
        (account) =>
            account.role == UserRole.medico && account.lastName == 'Acosta',
      );
      harness.shiftDb.createWeeklyShift(
        NewWeeklyShift(
          doctorId: acosta.id,
          specialtyId: 3,
          clinicId: harness.admin.clinics
              .firstWhere((clinic) => clinic.name == 'Consultorio 7')
              .id,
          weekday: 2,
          startDate: DateTime.utc(2026, 10, 20),
          endDate: DateTime.utc(2026, 10, 20),
          numbers: [
            ShiftNumber(
              number: 1,
              startMinutes: 9 * 60 + 10,
              endMinutes: 9 * 60 + 30,
            ),
          ],
        ),
      );
      final patternId = harness.shiftDb.weeklyShifts.first.id;
      final dates = harness.shiftDb.shifts
          .where((shift) => shift.weeklyShiftId == patternId)
          .toList();
      final third = find.byKey(Key('weekly-shift-date-${dates[2].id}'));
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 12');
      expect(find.textContaining('Seleccionadas: 4 de 4.'), findsOneWidget);

      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(find.textContaining('Seleccionadas: 3 de 4.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(third).value, isFalse);

      await _pickClinic(tester, 'Consultorio 7');

      // Vuelven a marcarse las 3 elegibles (27/10, 03/11 y 10/11); la del
      // 20/10 queda bloqueada y sin marcar.
      expect(find.textContaining('Seleccionadas: 3 de 4.'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(third).value, isTrue);
      final blocked = find.byKey(Key('weekly-shift-date-${dates[0].id}'));
      expect(tester.widget<CheckboxListTile>(blocked).value, isFalse);
    });

    testWidgets('consultas agendadas requieren confirmación expresa', (
      tester,
    ) async {
      final harness = await _pump(tester);
      harness.shiftDb.agendadasPorTurnoSemanal[harness
              .shiftDb
              .weeklyShifts
              .first
              .id] =
          2;
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      expect(_saveButton(tester).onPressed, isNull);
      expect(
        find.textContaining('no notificará automáticamente'),
        findsOneWidget,
      );

      final confirm = find.byKey(const Key('weekly-shift-confirm-booked'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(_saveButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('un solapamiento bloquea esa fecha, no las demás', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final acosta = harness.admin.accounts.firstWhere(
        (account) =>
            account.role == UserRole.medico && account.lastName == 'Acosta',
      );
      harness.shiftDb.createWeeklyShift(
        NewWeeklyShift(
          doctorId: acosta.id,
          specialtyId: 3,
          clinicId: harness.admin.clinics
              .firstWhere((clinic) => clinic.name == 'Consultorio 7')
              .id,
          weekday: 2,
          startDate: DateTime.utc(2026, 10, 20),
          endDate: DateTime.utc(2026, 10, 20),
          numbers: [
            ShiftNumber(
              number: 1,
              startMinutes: 9 * 60 + 10,
              endMinutes: 9 * 60 + 30,
            ),
          ],
        ),
      );
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      expect(find.textContaining('Solapamiento:'), findsWidgets);
      final firstShiftId = harness.shiftDb.shifts
          .firstWhere(
            (shift) =>
                shift.weeklyShiftId == harness.shiftDb.weeklyShifts.first.id,
          )
          .id;
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(Key('weekly-shift-date-$firstShiftId')),
      );
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);

      await _pickClinic(tester, 'Consultorio 12');
      expect(find.textContaining('Solapamiento:'), findsNothing);
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('un 404 muestra el texto del servidor y sigue abierto', (
      tester,
    ) async {
      await _pump(tester, clinicChange: (_) => _NotFoundClinic());
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      expect(_saveButton(tester).onPressed, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('No existe el consultorio indicado'), findsOneWidget);
    });

    testWidgets('Cancelar cierra y no llama al repositorio', (tester) async {
      late _RecordingClinicChange recording;
      await _pump(
        tester,
        clinicChange: (db) => recording = _RecordingClinicChange(db),
      );
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      await tester.tap(find.byKey(const Key('weekly-shift-clinic-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(recording.calls, 0);
      expect(find.text('Consultorio 3 (Planta baja)'), findsOneWidget);
    });

    testWidgets(
      'mientras envía Guardar queda deshabilitado y hay un solo envío',
      (tester) async {
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        late _RecordingClinicChange recording;
        await _pump(
          tester,
          clinicChange: (db) =>
              recording = _RecordingClinicChange(db, gate: gate),
        );
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');

        await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
        await tester.pump();

        expect(recording.calls, 1);
        expect(_saveButton(tester).onPressed, isNull);
        await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
        await tester.pump();
        expect(recording.calls, 1);
      },
    );

    testWidgets('dos toques seguidos en Guardar mandan un solo pedido', (
      tester,
    ) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      late _RecordingClinicChange recording;
      await _pump(
        tester,
        clinicChange: (db) =>
            recording = _RecordingClinicChange(db, gate: gate),
      );
      await _openDialog(tester);
      await _pickClinic(tester, 'Consultorio 7');

      // Sin pump entre los toques: el botón todavía no se reconstruyó.
      final save = find.byKey(const Key('weekly-shift-clinic-save'));
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();

      expect(recording.calls, 1);
    });

    testWidgets(
      'con el mismo consultorio las 5 fechas están y hay un solo scroll',
      (tester) async {
        // Patrón de Acosta, miércoles del 21/10 al 18/11/2026 (hoy es el 20/10):
        // 21/10 (suspendida), 28/10, 04/11, 11/11 y 18/11. Todas usan ya el
        // Consultorio 3, el mismo que se elige en el diálogo.
        final harness = await _pump(tester);
        final acosta = harness.admin.accounts.firstWhere(
          (account) =>
              account.role == UserRole.medico && account.lastName == 'Acosta',
        );
        final weekly = harness.shiftDb.createWeeklyShift(
          NewWeeklyShift(
            doctorId: acosta.id,
            specialtyId: 3,
            clinicId: harness.admin.clinics.first.id,
            weekday: 3,
            startDate: DateTime.utc(2026, 10, 21),
            endDate: DateTime.utc(2026, 11, 18),
            numbers: [
              ShiftNumber(
                number: 1,
                startMinutes: 10 * 60,
                endMinutes: 10 * 60 + 20,
              ),
            ],
          ),
        );
        final dates =
            harness.shiftDb.shifts
                .where((shift) => shift.weeklyShiftId == weekly.id)
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        expect(dates, hasLength(5));
        harness.shiftDb.suspendShift(dates.first.id);
        harness.router.go(weeklyShiftDetailLocation(weekly.id));
        await tester.pumpAndSettle();

        await _openDialog(tester);
        // Es el mismo consultorio: el desplegable no consulta solo.
        await tester.tap(find.text('Consultar fechas'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Seleccionadas: 0 de 5.'), findsOneWidget);

        // Un solo scroll vertical: el del diálogo (SingleChildScrollView de
        // `scrollable: true`). Una lista interna sumaría un segundo Scrollable.
        final verticalScrolls = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) => widget is Scrollable && widget.axis == Axis.vertical,
          ),
        );
        expect(verticalScrolls, findsOneWidget);

        expect(find.text('Ya usa el consultorio elegido.'), findsNWidgets(5));

        final dialog = tester.getRect(find.byType(AlertDialog));
        for (final date in dates) {
          final row = find.byKey(Key('weekly-shift-date-${date.id}'));
          expect(row, findsOneWidget);
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          final rect = tester.getRect(row);
          expect(rect.top, greaterThanOrEqualTo(dialog.top));
          expect(rect.bottom, lessThanOrEqualTo(dialog.bottom));
        }
      },
    );

    group('el aviso al guardar dice cuántas fechas cambiaron', () {
      Future<void> save(WidgetTester tester) async {
        await tester.tap(find.byKey(const Key('weekly-shift-clinic-save')));
        await tester.pumpAndSettle();
      }

      testWidgets('4 de 5 fechas: dice cuántas', (tester) async {
        final (_, dates) = await _pumpFiveDates(tester);
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');
        await _uncheck(tester, dates[2]);

        await save(tester);

        expect(
          find.text('Consultorio actualizado en 4 de 5 fechas.'),
          findsOneWidget,
        );
        expect(find.text('Consultorio actualizado.'), findsNothing);
      });

      testWidgets('las 5 fechas: aviso simple, sin "de 5"', (tester) async {
        await _pumpFiveDates(tester);
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');

        await save(tester);

        expect(find.text('Consultorio actualizado.'), findsOneWidget);
        expect(find.textContaining('de 5'), findsNothing);
      });

      testWidgets('2 fechas ya en el consultorio y 3 elegidas: aviso simple', (
        tester,
      ) async {
        // Dos fechas (21/10 y 28/10) ya usan el Consultorio 7: no se pueden
        // elegir. Las otras tres (04/11, 11/11 y 18/11) se eligen y completan
        // las 5.
        final (_, _) = await _pumpFiveDates(
          tester,
          prepare: (db, weeklyShiftId, dates) {
            final room7 = db.admin.clinics.firstWhere(
              (clinic) => clinic.name == 'Consultorio 7',
            );
            db.changeClinic(
              weeklyShiftId,
              room7.id,
              turnoIds: [dates[0].id, dates[1].id],
            );
          },
        );
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');
        expect(find.textContaining('Seleccionadas: 3 de 5.'), findsOneWidget);
        expect(find.text('Ya usa el consultorio elegido.'), findsNWidgets(2));

        await save(tester);

        expect(find.text('Consultorio actualizado.'), findsOneWidget);
        expect(find.textContaining('de 5'), findsNothing);
      });

      testWidgets('una fecha bloqueada por solapamiento: 4 de 5', (
        tester,
      ) async {
        // En el Consultorio 7, Silva tiene turno el 04/11 de 10:10 a 10:30:
        // se solapa con el de Acosta (10:00 a 10:20). Esa fecha no se puede
        // elegir y tampoco usa el Consultorio 7. Las otras 4 se eligen todas.
        await _pumpFiveDates(
          tester,
          prepare: (db, weeklyShiftId, dates) {
            final silva = db.admin.accounts.firstWhere(
              (account) =>
                  account.role == UserRole.medico &&
                  account.lastName == 'Silva',
            );
            final room7 = db.admin.clinics.firstWhere(
              (clinic) => clinic.name == 'Consultorio 7',
            );
            db.createWeeklyShift(
              NewWeeklyShift(
                doctorId: silva.id,
                specialtyId: 2,
                clinicId: room7.id,
                weekday: 3,
                startDate: DateTime.utc(2026, 11, 4),
                endDate: DateTime.utc(2026, 11, 4),
                numbers: [
                  ShiftNumber(
                    number: 1,
                    startMinutes: 10 * 60 + 10,
                    endMinutes: 10 * 60 + 30,
                  ),
                ],
              ),
            );
          },
        );
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');
        expect(find.textContaining('Seleccionadas: 4 de 5.'), findsOneWidget);

        await save(tester);

        expect(
          find.text('Consultorio actualizado en 4 de 5 fechas.'),
          findsOneWidget,
        );
      });

      testWidgets('3 de 5 fechas: desmarcando dos', (tester) async {
        final (_, dates) = await _pumpFiveDates(tester);
        await _openDialog(tester);
        await _pickClinic(tester, 'Consultorio 7');
        await _uncheck(tester, dates[1]);
        await _uncheck(tester, dates[3]);

        await save(tester);

        expect(
          find.text('Consultorio actualizado en 3 de 5 fechas.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('si no cargan los consultorios muestra Reintentar', (
      tester,
    ) async {
      await _pump(tester, clinicsFail: true);
      await _openDialog(tester);

      expect(
        find.text('No pudimos cargar los consultorios. Intentá de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
    });
  });

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('el detalle no desborda', (tester) async {
      await _pump(tester, size: const Size(320, 640));

      expect(find.text('Carla Méndez'), findsOneWidget);
      expect(
        find.byKey(const Key('weekly-shift-change-clinic')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el diálogo abierto no desborda', (tester) async {
      await _pump(tester, size: const Size(320, 640));
      await _openDialog(tester);

      expect(find.text(_currentClinic), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
