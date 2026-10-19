import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/screens/new_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

Future<GoRouter> _pump(WidgetTester tester, String initial) {
  final db = FakeAdminDatabase();
  return pumpAdminScreens(
    tester,
    initialLocation: initial,
    routes: [
      GoRoute(
        path: kSpecialtiesPath,
        builder: (_, _) => const SpecialtiesScreen(),
      ),
      GoRoute(
        path: kNewSpecialtyPath,
        builder: (_, _) => const NewSpecialtyScreen(),
      ),
    ],
    overrides: [
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(db, latency: Duration.zero),
      ),
    ],
  );
}

Finder get _name => find.byType(TextFormField);
Finder get _save => find.widgetWithText(FilledButton, 'Guardar especialidad');

void main() {
  testWidgets('el listado muestra cada especialidad con "Requiere pase" o '
      '"Libre"', (tester) async {
    await _pump(tester, kSpecialtiesPath);

    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Medicina General'), findsOneWidget);
    expect(find.text('Requiere pase'), findsNWidgets(2));
    expect(find.text('Libre'), findsOneWidget);
  });

  testWidgets('"Nueva especialidad" lleva al formulario', (tester) async {
    final router = await _pump(tester, kSpecialtiesPath);

    await tester.tap(find.text('Nueva especialidad'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), kNewSpecialtyPath);
  });

  testWidgets('sin nombre no se guarda y se pide completarlo', (tester) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(find.text('Ingresá el nombre de la especialidad.'), findsOneWidget);
    expect(currentLocation(router), kNewSpecialtyPath);
  });

  testWidgets('un nombre repetido muestra el aviso y conserva lo escrito', (
    tester,
  ) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.enterText(_name, 'CARDIOLOGÍA');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe una especialidad registrada con ese nombre.'),
      findsOneWidget,
    );
    expect(find.text('CARDIOLOGÍA'), findsOneWidget);
    expect(currentLocation(router), kNewSpecialtyPath);
  });

  testWidgets('el alta correcta vuelve al listado con la nueva especialidad', (
    tester,
  ) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.enterText(_name, 'Neurología');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(currentLocation(router), kSpecialtiesPath);
    expect(find.text('Especialidad registrada.'), findsOneWidget);
    expect(find.text('Neurología'), findsOneWidget);
    expect(find.text('Requiere pase'), findsNWidgets(3));
  });
}
