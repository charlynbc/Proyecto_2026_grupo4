import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _validCi = '12345672';

Finder get _ciField => find.byType(TextFormField).at(0);
Finder get _passwordField => find.byType(TextFormField).at(1);
Finder get _submit => find.widgetWithText(FilledButton, 'Ingresar');

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  String ci = _validCi,
  String password = 'cualquiera1',
}) async {
  await tester.enterText(_ciField, ci);
  await tester.enterText(_passwordField, password);
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca en el acceso de socios y envía acceso SOCIO', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    await pumpApp(tester, auth: auth);

    expect(find.text('Acceso para socios'), findsOneWidget);
    expect(find.text('Es mi primera vez'), findsOneWidget);

    await _fillAndSubmit(tester);

    expect(auth.logins, hasLength(1));
    expect(auth.logins.single.ci, _validCi);
    expect(auth.logins.single.access, AccessType.socio);
  });

  testWidgets('cambia al acceso de empleados y envía acceso EMPLEADO', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Ingresar por el acceso de empleados'));
    await tester.pumpAndSettle();
    expect(find.text('Acceso para empleados'), findsOneWidget);
    expect(find.text('Ingresar por el acceso de socios'), findsOneWidget);

    await _fillAndSubmit(tester);
    expect(auth.logins.single.access, AccessType.empleado);

    await tester.tap(find.text('Ingresar por el acceso de socios'));
    await tester.pumpAndSettle();
    expect(find.text('Acceso para socios'), findsOneWidget);
  });

  testWidgets('credenciales inválidas: un único mensaje genérico', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    await pumpApp(tester, auth: auth);

    // Mismo mensaje con una cédula que existe y con una que no.
    await _fillAndSubmit(tester, ci: _validCi, password: 'mala1234');
    expect(find.text(kInvalidCredentialsMessage), findsOneWidget);

    await _fillAndSubmit(tester, ci: '23456783', password: 'otra12345');
    expect(find.text(kInvalidCredentialsMessage), findsOneWidget);
    expect(auth.logins, hasLength(2));
  });

  testWidgets('no envía una cédula inválida ni una contraseña vacía', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    await pumpApp(tester, auth: auth);

    await _fillAndSubmit(tester, ci: '12345678', password: '');

    expect(auth.logins, isEmpty);
    expect(find.textContaining('La cédula no es válida'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
  });

  testWidgets('en Android solo hay acceso de socios, sin selector', (
    tester,
  ) async {
    final auth = RecordingAuthRepository();
    final container = await pumpApp(tester, employeeAccess: false, auth: auth);

    expect(find.text('Acceso para socios'), findsOneWidget);
    expect(find.text('Ingresar por el acceso de empleados'), findsNothing);
    expect(find.text('Acceso para empleados'), findsNothing);

    // Aunque la ruta pida empleados, se queda en socios.
    await goTo(tester, container, '/login?acceso=empleado');
    expect(find.text('Acceso para socios'), findsOneWidget);
    expect(find.text('Acceso para empleados'), findsNothing);

    await _fillAndSubmit(tester);
    expect(auth.logins.single.access, AccessType.socio);
  });

  testWidgets('"Es mi primera vez" lleva a pedir el enlace con el acceso', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text('Ingresar por el acceso de empleados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Es mi primera vez'));
    await tester.pumpAndSettle();

    expect(locationOf(container), '/primer-ingreso/solicitar?acceso=empleado');
  });
}
