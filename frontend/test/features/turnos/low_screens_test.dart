import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/turnos/screens/new_weekly_shift_screen.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:agenda_medica/features/turnos/screens/weekly_shift_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Una ventana baja y angosta: un celular chico, con el menú de la app y el
/// teclado ocupando lugar.
const Size _lowScreen = Size(400, 600);

Future<ProviderContainer> _pumpLowFuncionario(WidgetTester tester) async {
  final container = await pumpApp(tester);
  final person = TestData.people.firstWhere(
    (p) => p.role == UserRole.funcionario.apiValue,
  );
  final repo = await container.read(authRepositoryProvider.future);
  final done = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(UserRole.funcionario),
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
  tester.view.physicalSize = _lowScreen;
  await tester.pumpAndSettle();
  return container;
}

/// El `Scrollable` vertical más externo de [screen].
ScrollableState _outerScroll(WidgetTester tester, Type screen) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(screen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> _expectReachable(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  final rect = tester.getRect(button);
  expect(rect.bottom, lessThanOrEqualTo(_lowScreen.height));
  expect(rect.right, lessThanOrEqualTo(_lowScreen.width));
  expect(tester.takeException(), isNull);
}

void main() {
  group('en una pantalla de 400 × 600', () {
    testWidgets('el alta scrollea y se llega a "Guardar turno"', (
      tester,
    ) async {
      final container = await _pumpLowFuncionario(tester);
      await goTo(tester, container, kNewWeeklyShiftPath);

      expect(find.byType(NewWeeklyShiftScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        _outerScroll(tester, NewWeeklyShiftScreen).position.maxScrollExtent,
        greaterThan(0),
      );
      await _expectReachable(
        tester,
        find.widgetWithText(FilledButton, 'Guardar turno'),
      );
      await unmountApp(tester);
    });

    testWidgets('el alta con todos los avisos a la vista también scrollea', (
      tester,
    ) async {
      final container = await _pumpLowFuncionario(tester);
      await goTo(tester, container, kNewWeeklyShiftPath);

      final save = find.widgetWithText(FilledButton, 'Guardar turno');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Elegí la especialidad.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, save);
      await unmountApp(tester);
    });

    testWidgets('el detalle con tres números se lee y se llega a "Volver al '
        'listado"', (tester) async {
      final container = await _pumpLowFuncionario(tester);
      await goTo(tester, container, weeklyShiftDetailLocation(3));

      expect(find.byType(WeeklyShiftDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _expectReachable(tester, find.text('Volver al listado'));
      // El seed de `FakeShiftDatabase`: tres números de 20 minutos desde las 09:00.
      expect(find.text('Número 3: 09:40 – 10:00 (20 min)'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets('la consulta con tarjetas scrollea hasta el paginador', (
      tester,
    ) async {
      await _pumpLowFuncionario(tester);

      expect(find.byType(ShiftsScreen), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        _outerScroll(tester, ShiftsScreen).position.maxScrollExtent,
        greaterThan(0),
      );
      await _expectReachable(tester, find.text('Siguiente'));
      await unmountApp(tester);
    });

    testWidgets('"Limpiar filtros" se alcanza y funciona, sin desbordes', (
      tester,
    ) async {
      await _pumpLowFuncionario(tester);

      final clear = find.text('Limpiar filtros');
      await _expectReachable(tester, clear);

      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Card), findsWidgets);
      await unmountApp(tester);
    });
  });
}
