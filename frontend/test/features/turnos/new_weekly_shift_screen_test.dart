import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/new_weekly_shift_screen.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/weekly_shift_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import '../../helpers/shift_listing_data.dart';

const String _missingSpecialty = 'Elegí la especialidad.';
const String _missingDoctor = 'Elegí el médico.';
const String _missingClinic = 'Elegí el consultorio.';
const String _missingWeekday = 'Elegí el día de la semana.';
const String _missingFrom = 'Ingresá la fecha de inicio.';
const String _missingTo = 'Ingresá la fecha de fin.';
const String _badDateFormat =
    'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';
const String _nonexistentDate =
    'Esa fecha no existe en el calendario. Revisá el día y el mes.';
const String _fromAfterTo =
    'La fecha de inicio no puede ser posterior a la de fin.';
const String _noNumbers = 'Cargá al menos un número.';

/// Un repository que cuenta las altas, puede frenarlas hasta que se libere
/// [gate], rechazarlas con [createError] y fallar la primera carga de médicos.
class _RecordingShiftRepository extends FakeShiftRepository {
  _RecordingShiftRepository(
    super.db, {
    this.createError,
    this.gate,
    this.failFirstDoctorsLoad = false,
  }) : super(latency: Duration.zero);

  final Object? createError;
  final Completer<void>? gate;
  final bool failFirstDoctorsLoad;
  int createCalls = 0;
  int doctorsCalls = 0;

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) async {
    doctorsCalls++;
    if (failFirstDoctorsLoad && doctorsCalls == 1) throw const ApiException();
    return super.listDoctors(specialtyId: specialtyId);
  }

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) async {
    createCalls++;
    await gate?.future;
    if (createError != null) throw createError!;
    return super.createWeeklyShift(data);
  }
}

class _Harness {
  _Harness(this.admin, this.shiftDb, this.repository, this.router);

  final FakeAdminDatabase admin;
  final FakeShiftDatabase shiftDb;
  final _RecordingShiftRepository repository;
  final GoRouter router;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 3000),
  Object? createError,
  Completer<void>? gate,
  bool failFirstDoctorsLoad = false,
}) async {
  final admin = FakeAdminDatabase();
  final shiftDb = buildListingDb(admin);
  final repository = _RecordingShiftRepository(
    shiftDb,
    createError: createError,
    gate: gate,
    failFirstDoctorsLoad: failFirstDoctorsLoad,
  );
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: kNewWeeklyShiftPath,
    routes: [
      GoRoute(
        path: kShiftsPath,
        builder: (_, _) => const Scaffold(body: Text('Listado de turnos')),
      ),
      GoRoute(
        path: kNewWeeklyShiftPath,
        builder: (_, _) => const NewWeeklyShiftScreen(),
      ),
      GoRoute(
        path: kWeeklyShiftDetailPath,
        builder: (_, state) =>
            WeeklyShiftDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
    overrides: [
      shiftRepositoryProvider.overrideWith((ref) async => repository),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
      ),
      clinicRepositoryProvider.overrideWith(
        (ref) async => FakeClinicRepository(admin, latency: Duration.zero),
      ),
    ],
  );
  return _Harness(admin, shiftDb, repository, router);
}

Future<void> _choose(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Guardar turno');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Cardiología, Esteban Silva, Consultorio 12 y los miércoles del 21/10 al
/// 11/11/2026 (cuatro fechas), sin números.
Future<void> _fillFields(WidgetTester tester) async {
  await _choose(tester, 'field-specialty', 'Cardiología');
  await _choose(tester, 'field-doctor', 'Esteban Silva');
  await _choose(tester, 'field-clinic', 'Consultorio 12');
  await _choose(tester, 'field-weekday', 'Miércoles');
  await _type(tester, 'field-from', '21/10/2026');
  await _type(tester, 'field-to', '11/11/2026');
}

/// Lo de [_fillFields] y tres números de 20 minutos de 09:00 a 10:00.
Future<void> _fillValid(WidgetTester tester) async {
  await _fillFields(tester);
  await _tapText(tester, 'Generar números');
}

List<int?> _options(WidgetTester tester, String key) => tester
    .widget<DropdownButton<int>>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(DropdownButton<int>),
      ),
    )
    .items!
    .map((item) => item.value)
    .toList();

int _doctorId(FakeAdminDatabase admin, String lastName) => admin.accounts
    .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
    .id;

void main() {
  group('la pantalla', () {
    testWidgets('muestra los campos, el editor y los botones', (tester) async {
      await _pump(tester);

      for (final key in [
        'field-specialty',
        'field-doctor',
        'field-clinic',
        'field-weekday',
        'field-from',
        'field-to',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(find.text('Números del turno'), findsOneWidget);
      expect(find.text('Guardar turno'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('"Cancelar" vuelve al listado', (tester) async {
      final harness = await _pump(tester);

      await _tapText(tester, 'Cancelar');

      expect(currentLocation(harness.router), kShiftsPath);
      expect(find.text('Listado de turnos'), findsOneWidget);
    });
  });

  group('especialidad y médico', () {
    testWidgets('el médico está deshabilitado hasta elegir especialidad', (
      tester,
    ) async {
      await _pump(tester);

      final doctor = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('field-doctor')),
      );
      expect(doctor.onChanged, isNull);

      await _choose(tester, 'field-specialty', 'Cardiología');

      final enabled = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('field-doctor')),
      );
      expect(enabled.onChanged, isNotNull);
    });

    testWidgets('solo ofrece los médicos activos de esa especialidad', (
      tester,
    ) async {
      final harness = await _pump(tester);

      await _choose(tester, 'field-specialty', 'Cardiología');
      expect(_options(tester, 'field-doctor'), [
        _doctorId(harness.admin, 'Silva'),
      ]);

      await _choose(tester, 'field-specialty', 'Medicina General');
      // Acosta y Méndez, por apellido. Pereira está inactivo y no aparece.
      expect(_options(tester, 'field-doctor'), [
        _doctorId(harness.admin, 'Acosta'),
        _doctorId(harness.admin, 'Méndez'),
      ]);
    });

    testWidgets('al cambiar la especialidad se limpia el médico elegido', (
      tester,
    ) async {
      DropdownButton<int> doctorField() => tester.widget<DropdownButton<int>>(
        find.descendant(
          of: find.byKey(const Key('field-doctor')),
          matching: find.byType(DropdownButton<int>),
        ),
      );

      await _pump(tester);
      // Florencia Acosta ejerce Medicina General (1) y Dermatología (3): al
      // pasar de una a otra sigue estando entre los médicos ofrecidos, así que
      // solo un borrado explícito del médico elegido la saca del selector.
      await _choose(tester, 'field-specialty', 'Medicina General');
      await _choose(tester, 'field-doctor', 'Florencia Acosta');
      expect(doctorField().value, isNotNull);
      expect(find.text('Florencia Acosta'), findsOneWidget);

      await _choose(tester, 'field-specialty', 'Dermatología');

      expect(_options(tester, 'field-doctor'), isNotEmpty);
      expect(doctorField().value, isNull);
      expect(find.text('Florencia Acosta'), findsNothing);

      // Y con una especialidad cuya lista no incluye al médico elegido.
      await _choose(tester, 'field-specialty', 'Medicina General');
      await _choose(tester, 'field-doctor', 'Carla Méndez');
      await _choose(tester, 'field-specialty', 'Cardiología');
      expect(doctorField().value, isNull);
      expect(find.text('Carla Méndez'), findsNothing);
    });

    testWidgets(
      'si no cargan los médicos avisa y "Reintentar" vuelve a pedir',
      (tester) async {
        final harness = await _pump(tester, failFirstDoctorsLoad: true);

        await _choose(tester, 'field-specialty', 'Cardiología');

        expect(
          find.text('No pudimos cargar los médicos. Intentá de nuevo.'),
          findsOneWidget,
        );
        await _tapText(tester, 'Reintentar');

        expect(harness.repository.doctorsCalls, 2);
        expect(
          find.text('No pudimos cargar los médicos. Intentá de nuevo.'),
          findsNothing,
        );
        expect(_options(tester, 'field-doctor'), [
          _doctorId(harness.admin, 'Silva'),
        ]);
      },
    );
  });

  group('validación en el cliente', () {
    testWidgets('sin datos, cada causa se avisa una sola vez y no se envía', (
      tester,
    ) async {
      final harness = await _pump(tester);

      await _save(tester);

      for (final message in [
        _missingSpecialty,
        _missingDoctor,
        _missingClinic,
        _missingWeekday,
        _missingFrom,
        _missingTo,
        _noNumbers,
      ]) {
        expect(find.text(message), findsOneWidget, reason: message);
      }
      expect(harness.repository.createCalls, 0);
    });

    testWidgets('una fecha mal escrita se avisa en su campo', (tester) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      await _type(tester, 'field-from', '2026-10-21');
      await _save(tester);

      expect(find.text(_badDateFormat), findsOneWidget);
      expect(harness.repository.createCalls, 0);
    });

    testWidgets(
      'una fecha de fin a medias también se avisa en su campo y no se '
      'envía',
      (tester) async {
        final harness = await _pump(tester);
        await _fillValid(tester);

        // El filtro de caracteres deja "20261111": 8 caracteres, sin barras.
        await _type(tester, 'field-to', '2026-11-11');
        await _save(tester);

        expect(find.text(_badDateFormat), findsOneWidget);
        expect(harness.repository.createCalls, 0);
      },
    );

    testWidgets('una fecha que no existe se avisa distinto', (tester) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      await _type(tester, 'field-to', '31/02/2026');
      await _save(tester);

      expect(find.text(_nonexistentDate), findsOneWidget);
      expect(find.text(_badDateFormat), findsNothing);
      expect(harness.repository.createCalls, 0);
    });

    testWidgets('"desde" posterior a "hasta" avisa una vez y nada más', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      await _type(tester, 'field-from', '12/11/2026');
      await _save(tester);

      expect(find.text(_fromAfterTo), findsOneWidget);
      // No se suma el aviso del día: sin un rango válido no se puede decir.
      expect(find.textContaining('no hay ningún'), findsNothing);
      expect(harness.repository.createCalls, 0);
    });

    testWidgets('una vigencia sin el día elegido avisa en línea y no envía', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      // Del miércoles 21/10 al viernes 23/10 no hay ningún martes.
      await _choose(tester, 'field-weekday', 'Martes');
      await _type(tester, 'field-to', '23/10/2026');
      await _save(tester);

      expect(
        find.text(
          'Entre el 21/10/2026 y el 23/10/2026 no hay ningún martes. Elegí '
          'otro día o ampliá las fechas.',
        ),
        findsOneWidget,
      );
      expect(harness.repository.createCalls, 0);
    });

    testWidgets('sin las dos fechas no se avisa del día', (tester) async {
      await _pump(tester);
      await _choose(tester, 'field-weekday', 'Martes');
      await _type(tester, 'field-from', '21/10/2026');

      await _save(tester);

      expect(find.text(_missingTo), findsOneWidget);
      expect(find.textContaining('no hay ningún'), findsNothing);
    });

    testWidgets('los números inválidos se avisan en el editor y no se envía', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      // Se quitan los tres generados y se deja uno de 5 minutos (09:00-09:05).
      for (var i = 0; i < 3; i++) {
        await _tapText(tester, 'Quitar');
      }
      await _tapText(tester, 'Agregar número');
      await _choose(tester, 'number-0-end-minute', '05');
      await _save(tester);

      expect(find.textContaining('entre 10 y 60 minutos'), findsOneWidget);
      expect(harness.repository.createCalls, 0);
    });

    testWidgets(
      'con números solapados no se envía y se avisa del solapamiento',
      (tester) async {
        final harness = await _pump(tester);
        final before = harness.shiftDb.weeklyShifts.length;
        await _fillFields(tester);

        // 09:00-09:20 y 09:20-09:40; el segundo pasa a empezar a las 09:10 y
        // pisa los últimos 10 minutos del primero.
        await _tapText(tester, 'Agregar número');
        await _tapText(tester, 'Agregar número');
        await _choose(tester, 'number-1-start-minute', '10');
        await _save(tester);

        // El mensaje está una sola vez: el del editor, no uno del servidor.
        expect(
          find.text(
            'Los números 1 y 2 se solapan (09:00–09:20 y 09:10–09:40).',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('server-error')), findsNothing);
        expect(harness.repository.createCalls, 0);
        expect(currentLocation(harness.router), kNewWeeklyShiftPath);
        expect(harness.shiftDb.weeklyShifts.length, before);
      },
    );
  });

  group('el calendario de la vigencia', () {
    const pickFrom = 'Elegir la fecha de inicio de la vigencia';
    const pickTo = 'Elegir la fecha de fin de la vigencia';

    String fieldText(WidgetTester tester, String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    Future<void> openAndAccept(WidgetTester tester, String tooltip) async {
      final button = find.byTooltip(tooltip);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
    }

    testWidgets('el de "Hasta" abre en la fecha de "Desde"', (tester) async {
      await _pump(tester);
      await _type(tester, 'field-from', '10/11/2026');

      await openAndAccept(tester, pickTo);

      expect(fieldText(tester, 'field-to'), '10/11/2026');
    });

    testWidgets('el de "Desde" abre en lo que ya está escrito', (tester) async {
      await _pump(tester);
      await _type(tester, 'field-from', '10/11/2026');

      await openAndAccept(tester, pickFrom);

      expect(fieldText(tester, 'field-from'), '10/11/2026');
    });

    testWidgets('elegir un día escribe la fecha en dd/mm/aaaa', (tester) async {
      await _pump(tester);
      await _type(tester, 'field-from', '10/11/2026');

      final button = find.byTooltip(pickFrom);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'field-from'), '15/11/2026');
    });

    testWidgets('la cruz borra la fecha y no deja un reclamo mientras tanto', (
      tester,
    ) async {
      await _pump(tester);
      await _type(tester, 'field-from', '10/11/2026');

      final cross = find.byTooltip('Borrar la fecha');
      await tester.ensureVisible(cross);
      await tester.tap(cross);
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'field-from'), isEmpty);
      expect(find.text(_missingFrom), findsNothing);
    });
  });

  group('envío', () {
    testWidgets('un alta correcta va al detalle y avisa el resultado', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _fillValid(tester);

      await _save(tester);

      final created = harness.shiftDb.weeklyShifts.last;
      expect(created.shiftCount, 4);
      expect(created.numbers.length, 3);
      expect(created.weekday, 3);
      expect(
        currentLocation(harness.router),
        weeklyShiftDetailLocation(created.id),
      );
      expect(find.text('Esteban Silva'), findsWidgets);
      expect(
        find.text('Se creó el turno semanal con 4 fechas.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'un cruce con otro turno se muestra arriba, sin marcar campos',
      (tester) async {
        final harness = await _pump(tester);
        await _choose(tester, 'field-specialty', 'Medicina General');
        await _choose(tester, 'field-doctor', 'Carla Méndez');
        await _choose(tester, 'field-clinic', 'Consultorio 3');
        await _choose(tester, 'field-weekday', 'Martes');
        await _type(tester, 'field-from', '20/10/2026');
        await _type(tester, 'field-to', '10/11/2026');
        await _tapText(tester, 'Agregar número');
        await _tapText(tester, 'Agregar número');

        await _save(tester);

        final banner = find.byKey(const Key('server-error'));
        expect(banner, findsOneWidget);
        final message = tester.widget<Text>(
          find.descendant(of: banner, matching: find.byType(Text)),
        );
        // El 27/10 de ese turno está suspendido: no cuenta como cruce.
        expect(message.data, contains('20/10/2026'));
        expect(message.data, contains('03/11/2026'));
        expect(message.data, contains('10/11/2026'));
        expect(message.data, isNot(contains('27/10/2026')));
        expect(message.data, contains('números 1 y 2'));
        expect(message.data, contains('del médico y del consultorio'));
        // Sigue en el formulario y no marca ningún campo.
        expect(currentLocation(harness.router), kNewWeeklyShiftPath);
        expect(find.text(_missingSpecialty), findsNothing);
        expect(harness.shiftDb.weeklyShifts.length, 4);
      },
    );

    for (final error in <ApiException>[
      const SpecialtyNotOfDoctorException(),
      const InactiveDoctorException(),
      const ShiftNotFoundException(),
    ]) {
      testWidgets('${error.runtimeType} muestra su mensaje arriba', (
        tester,
      ) async {
        final harness = await _pump(tester, createError: error);
        await _fillValid(tester);

        await _save(tester);

        expect(find.text(error.message), findsOneWidget);
        expect(find.byKey(const Key('server-error')), findsOneWidget);
        expect(currentLocation(harness.router), kNewWeeklyShiftPath);
      });
    }

    testWidgets('un intento nuevo con datos inválidos limpia el aviso viejo', (
      tester,
    ) async {
      final harness = await _pump(tester, createError: const ApiException());
      await _fillValid(tester);
      await _save(tester);
      expect(find.byKey(const Key('server-error')), findsOneWidget);

      // Se vacía una fecha: el nuevo intento falla en el cliente, no se envía
      // y el aviso del servidor del intento anterior ya no corresponde.
      await _type(tester, 'field-from', '');
      await _save(tester);

      expect(find.byKey(const Key('server-error')), findsNothing);
      expect(harness.repository.createCalls, 1);
    });

    testWidgets('mientras envía el botón se deshabilita: no hay doble envío', (
      tester,
    ) async {
      final gate = Completer<void>();
      final harness = await _pump(tester, gate: gate);
      await _fillValid(tester);

      final button = find.widgetWithText(FilledButton, 'Guardar turno');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(harness.repository.createCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(harness.repository.createCalls, 1);
      expect(harness.shiftDb.weeklyShifts.length, 5);
    });
  });

  group('según el ancho de la pantalla', () {
    for (final width in [400.0, 700.0, 1100.0]) {
      testWidgets('con $width px no hay desbordes, ni vacío ni con errores', (
        tester,
      ) async {
        await _pump(
          tester,
          size: Size(width, 3200),
          createError: const OverlappingShiftException(
            'No se pudo guardar: los horarios se cruzan con turnos activos '
            'del médico y del consultorio el 20/10/2026, 27/10/2026 y '
            '03/11/2026 (números 1 y 2). Cambiá los horarios o las fechas y '
            'volvé a guardar.',
          ),
        );
        expect(tester.takeException(), isNull);

        // Todos los avisos de validación a la vez.
        await _save(tester);
        expect(find.text(_missingSpecialty), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Lleno, con el aviso largo del servidor arriba.
        await _fillValid(tester);
        await _save(tester);
        expect(find.byKey(const Key('server-error')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('con 400 px el botón de guardar se alcanza', (tester) async {
      await _pump(tester, size: const Size(400, 900));
      final button = find.widgetWithText(FilledButton, 'Guardar turno');

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      expect(tester.getRect(button).right, lessThanOrEqualTo(400));
      expect(tester.takeException(), isNull);
    });
  });
}
