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

  group('validación anticipada', () {
    const ciError =
        'La cédula no es válida. Escribila completa, con el dígito '
        'verificador, sin puntos ni guiones.';
    const passwordError = 'Ingresá tu contraseña.';

    Future<void> focusAndType(
      WidgetTester tester,
      Finder field,
      String text,
    ) async {
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, text);
      await tester.pump();
    }

    Future<void> moveFocusTo(WidgetTester tester, Finder field) async {
      await tester.tap(field);
      await tester.pumpAndSettle();
    }

    testWidgets('con foco y menos de 8 dígitos la cédula no marca error', (
      tester,
    ) async {
      await pumpApp(tester);

      await focusAndType(tester, _ciField, '1234567');

      expect(find.text(ciError), findsNothing);
    });

    testWidgets('con 8 dígitos de verificador inválido marca error aunque '
        'tenga foco', (tester) async {
      await pumpApp(tester);

      await focusAndType(tester, _ciField, '12345678');

      expect(find.text(ciError), findsOneWidget);
    });

    testWidgets('al salir del campo con pocos dígitos marca error', (
      tester,
    ) async {
      await pumpApp(tester);
      await focusAndType(tester, _ciField, '123');
      expect(find.text(ciError), findsNothing);

      await moveFocusTo(tester, _passwordField);

      expect(find.text(ciError), findsOneWidget);
    });

    testWidgets('una cédula válida no marca error, con o sin foco', (
      tester,
    ) async {
      await pumpApp(tester);

      await focusAndType(tester, _ciField, _validCi);
      expect(find.text(ciError), findsNothing);

      await moveFocusTo(tester, _passwordField);
      expect(find.text(ciError), findsNothing);
    });

    testWidgets('la contraseña vacía marca error recién al perder el foco', (
      tester,
    ) async {
      await pumpApp(tester);
      await focusAndType(tester, _passwordField, 'abc');
      await focusAndType(tester, _passwordField, '');
      expect(find.text(passwordError), findsNothing);

      await moveFocusTo(tester, _ciField);

      expect(find.text(passwordError), findsOneWidget);
    });

    testWidgets('el mensaje largo de cédula inválida no se corta en una '
        'sola línea', (tester) async {
      await pumpApp(tester);

      await focusAndType(tester, _ciField, '12345678');

      final message = tester.widget<Text>(find.text(ciError));
      expect(message.maxLines, greaterThanOrEqualTo(2));
    });

    testWidgets('al enviar se valida todo aunque un campo tenga foco', (
      tester,
    ) async {
      final auth = RecordingAuthRepository();
      await pumpApp(tester, auth: auth);
      await focusAndType(tester, _ciField, '123');

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text(ciError), findsOneWidget);
      expect(find.text(passwordError), findsOneWidget);
      expect(auth.logins, isEmpty);
    });
  });
}
