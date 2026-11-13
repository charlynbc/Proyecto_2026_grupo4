import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/new_clinic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/error_text_fit.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  String initial, {
  Size size = const Size(900, 1800),
}) {
  final db = FakeAdminDatabase();
  return pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initial,
    routes: [
      GoRoute(path: kClinicsPath, builder: (_, _) => const ClinicsScreen()),
      GoRoute(path: kNewClinicPath, builder: (_, _) => const NewClinicScreen()),
    ],
    overrides: [
      clinicRepositoryProvider.overrideWith(
        (ref) async => FakeClinicRepository(db, latency: Duration.zero),
      ),
      clinicSearchRepositoryProvider.overrideWith(
        (ref) async => FakeClinicSearchRepository(db, latency: Duration.zero),
      ),
    ],
  );
}

Finder get _fields => find.byType(TextFormField);
Finder get _save => find.widgetWithText(FilledButton, 'Guardar consultorio');

void main() {
  setUpAll(loadRoboto);

  testWidgets('el listado muestra nombre y ubicación', (tester) async {
    await _pump(tester, kClinicsPath);

    expect(find.text('Consultorio 7'), findsOneWidget);
    expect(find.text('Piso 1'), findsOneWidget);
    expect(find.text('Planta baja'), findsOneWidget);
  });

  testWidgets('"Nuevo consultorio" lleva al formulario', (tester) async {
    final router = await _pump(tester, kClinicsPath);

    await tester.tap(find.text('Nuevo consultorio'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), kNewClinicPath);
  });

  testWidgets('sin nombre ni ubicación no se guarda', (tester) async {
    final router = await _pump(tester, kNewClinicPath);

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(
      find.text('Ingresá el nombre o número del consultorio.'),
      findsOneWidget,
    );
    expect(find.text('Ingresá la ubicación.'), findsOneWidget);
    expect(currentLocation(router), kNewClinicPath);
  });

  testWidgets('a 320 px los mensajes de nombre y ubicación vacíos se leen '
      'enteros', (tester) async {
    await _pump(tester, kNewClinicPath, size: const Size(320, 900));

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expectErrorFits(tester, 'Ingresá el nombre o número del consultorio.');
    expectErrorFits(tester, 'Ingresá la ubicación.');
  });

  testWidgets('los campos limitan el largo a 120 y 200 caracteres', (
    tester,
  ) async {
    await _pump(tester, kNewClinicPath);

    await tester.enterText(_fields.at(0), 'a' * 150);
    await tester.enterText(_fields.at(1), 'b' * 250);

    final name = tester.widget<TextField>(find.byType(TextField).at(0));
    final location = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(name.controller!.text.length, 120);
    expect(location.controller!.text.length, 200);
  });

  testWidgets('un nombre repetido muestra el aviso y conserva lo escrito', (
    tester,
  ) async {
    final router = await _pump(tester, kNewClinicPath);

    await tester.enterText(_fields.at(0), 'consultorio 3');
    await tester.enterText(_fields.at(1), 'Piso 5');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe un consultorio con ese nombre o número.'),
      findsOneWidget,
    );
    expect(find.text('Piso 5'), findsOneWidget);
    expect(currentLocation(router), kNewClinicPath);
  });

  testWidgets('el alta correcta vuelve al listado con el nuevo consultorio', (
    tester,
  ) async {
    final router = await _pump(tester, kNewClinicPath);

    await tester.enterText(_fields.at(0), 'Consultorio 20');
    await tester.enterText(_fields.at(1), 'Piso 4');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(currentLocation(router), kClinicsPath);
    expect(find.text('Consultorio registrado.'), findsOneWidget);
    expect(find.text('Consultorio 20'), findsOneWidget);
    expect(find.text('Piso 4'), findsOneWidget);
  });
}
