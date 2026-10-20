import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/weekly_shift_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  _Harness(this.shiftDb, this.router, this.repository);

  final FakeShiftDatabase shiftDb;
  final GoRouter router;
  final FakeShiftRepository repository;
}

/// Monta el detalle de la configuración [index] de `buildListingDb` (0 es la
/// de Méndez; 2, la de Acosta), o del id indicado en [id].
Future<_Harness> _pump(
  WidgetTester tester, {
  int index = 0,
  int? id,
  Size size = const Size(900, 1800),
  bool flaky = false,
}) async {
  final admin = FakeAdminDatabase();
  final shiftDb = buildListingDb(admin);
  final repository = flaky
      ? _FlakyShiftRepository(shiftDb)
      : FakeShiftRepository(shiftDb, latency: Duration.zero);
  final weeklyShiftId = id ?? shiftDb.weeklyShifts[index].id;
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
    ],
  );
  return _Harness(shiftDb, router, repository);
}

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
}
