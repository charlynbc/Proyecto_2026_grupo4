import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

String _stateOf(WidgetTester tester, String date) {
  final table = tester.widget<DataTable>(find.byType(DataTable));
  final row = table.rows.singleWhere((row) {
    final cell = row.cells.first.child;
    return cell is Text && cell.data == date;
  });
  final state = row.cells.last.child;
  return (state as Text).data!;
}

Future<void> _choose(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('al volver a la consulta el turno rehabilitado queda activo', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    tester.view.physicalSize = const Size(1600, 1200);
    await tester.pumpAndSettle();

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

    final suspended = container
        .read(fakeShiftDatabaseProvider)
        .shifts
        .singleWhere((shift) => shift.state == ShiftState.suspended);
    final date = formatUiDate(suspended.date);
    expect(_stateOf(tester, date), 'Suspendida');

    await tester.tap(find.text('Rehabilitar fechas'));
    await tester.pumpAndSettle();

    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Desde'), date);
    await tester.enterText(find.widgetWithText(TextField, 'Hasta'), date);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rehabilitar turnos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a habilitar'));
    await tester.pumpAndSettle();

    await goTo(tester, container, kShiftsPath);
    // La consulta pide la lista al volver a quedar adelante. El repositorio
    // falso tarda 300 ms, y goTo vuelve antes de ese pedido.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_stateOf(tester, date), 'Activa');
    await unmountApp(tester);
  });

  testWidgets('durante el pedido el menú no cambia de sección', (tester) async {
    final container = await pumpApp(tester);
    tester.view.physicalSize = const Size(1600, 1200);
    await tester.pumpAndSettle();

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

    await goTo(tester, container, kReinstateShiftsPath);
    final suspended = container
        .read(fakeShiftDatabaseProvider)
        .shifts
        .singleWhere((shift) => shift.state == ShiftState.suspended);
    final date = formatUiDate(suspended.date);

    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Desde'), date);
    await tester.enterText(find.widgetWithText(TextField, 'Hasta'), date);
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rehabilitar turnos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a habilitar'));
    await tester.pump();

    // La barrera del diálogo tapa el menú: el toque cae ahí, no en Agendas.
    await tester.tap(find.text('Agendas'), warnIfMissed: false);
    await tester.pump();

    expect(locationOf(container), kReinstateShiftsPath);
    expect(
      find.text(
        'Las consultas que se cancelaron por la suspensión no se vuelven a '
        'agendar. Los socios tienen que pedir una nueva consulta.',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await unmountApp(tester);
  });
}
