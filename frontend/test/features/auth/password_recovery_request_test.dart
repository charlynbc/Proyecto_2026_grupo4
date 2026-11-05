import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'recovery_test_support.dart';

const _requestedMessage =
    'Si su cédula se encuentra registrada, se le ha enviado un correo '
    'electrónico con las instrucciones.';

Finder get _ciField => find.byType(TextFormField);
Finder get _continue => find.widgetWithText(FilledButton, 'Continuar');

Future<void> _submitCi(WidgetTester tester, String ci) async {
  await tester.enterText(_ciField, ci);
  await tester.tap(_continue);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  test('el mensaje es el texto exacto del contrato', () {
    expect(kPasswordRecoveryRequestedMessage, _requestedMessage);
  });

  testWidgets('muestra el título y la explicación', (tester) async {
    final container = await pumpRecoveryApp(tester);
    await goTo(tester, container, '/recuperacion/solicitar');

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(
      find.text(
        'Ingresá tu cédula y, si tenés una cuenta, te enviamos por correo un '
        'enlace para elegir una contraseña nueva. El enlace sirve una sola vez '
        'y vale 24 horas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra siempre el mismo mensaje y envía cédula y acceso', (
    tester,
  ) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await pumpRecoveryApp(tester, recovery: repo);
    await goTo(tester, container, '/recuperacion/solicitar');

    await _submitCi(tester, '12345672');

    expect(find.text('Revisá tu correo'), findsOneWidget);
    expect(find.text(_requestedMessage), findsOneWidget);
    expect(repo.requests.single.ci, '12345672');
    expect(repo.requests.single.access, AccessType.socio);
  });

  testWidgets('con el selector en Empleado manda EMPLEADO', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await pumpRecoveryApp(tester, recovery: repo);
    await goTo(tester, container, '/recuperacion/solicitar');

    await tester.tap(find.text('Empleado'));
    await tester.pumpAndSettle();
    await _submitCi(tester, '23456783');

    expect(repo.requests.single.access, AccessType.empleado);
  });

  testWidgets('con ?acceso=empleado arranca en Empleado', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await pumpRecoveryApp(tester, recovery: repo);
    await goTo(tester, container, '/recuperacion/solicitar?acceso=empleado');

    await _submitCi(tester, '23456783');

    expect(repo.requests.single.access, AccessType.empleado);
  });

  testWidgets('valida la cédula antes de enviar', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await pumpRecoveryApp(tester, recovery: repo);
    await goTo(tester, container, '/recuperacion/solicitar');

    await _submitCi(tester, '12345678');

    expect(
      find.text(
        'La cédula no es válida. Escribila completa, con el dígito '
        'verificador, sin puntos ni guiones.',
      ),
      findsOneWidget,
    );
    expect(repo.requests, isEmpty);
    expect(find.text(_requestedMessage), findsNothing);
  });

  testWidgets('en Android no ofrece el acceso de empleados y manda SOCIO', (
    tester,
  ) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await pumpRecoveryApp(
      tester,
      recovery: repo,
      employeeAccess: false,
    );
    await goTo(tester, container, '/recuperacion/solicitar?acceso=empleado');

    expect(find.byType(SegmentedButton<AccessType>), findsNothing);
    await _submitCi(tester, '12345672');
    expect(repo.requests.single.access, AccessType.socio);
  });

  testWidgets('un error del repositorio muestra "No pudimos enviar tu pedido" '
      'con su mensaje', (tester) async {
    final container = await pumpRecoveryApp(
      tester,
      recovery: RecordingPasswordRecoveryRepository(
        requestError: const AuthException('No hay conexión.'),
      ),
    );
    await goTo(tester, container, '/recuperacion/solicitar');

    await _submitCi(tester, '12345672');

    expect(find.text('No pudimos enviar tu pedido'), findsOneWidget);
    expect(find.text('No hay conexión.'), findsOneWidget);
    expect(find.text(_requestedMessage), findsNothing);
  });

  testWidgets('"Volver al ingreso" vuelve al login del mismo acceso', (
    tester,
  ) async {
    final container = await pumpRecoveryApp(tester);
    await goTo(tester, container, '/recuperacion/solicitar?acceso=empleado');

    await tester.tap(find.text('Volver al ingreso'));
    await tester.pumpAndSettle();

    expect(locationOf(container), '/login?acceso=empleado');
  });

  group('a 320 px con Roboto', () {
    const size = Size(320, 640);

    testWidgets('el formulario no desborda', (tester) async {
      final container = await pumpRecoveryApp(tester, size: size);
      await goTo(tester, container, '/recuperacion/solicitar');

      expect(tester.takeException(), isNull);
      expect(_continue, findsOneWidget);
    });

    testWidgets('con el error de la cédula y el del pedido no desborda', (
      tester,
    ) async {
      final container = await pumpRecoveryApp(
        tester,
        size: size,
        recovery: RecordingPasswordRecoveryRepository(
          requestError: const AuthException('No hay conexión.'),
        ),
      );
      await goTo(tester, container, '/recuperacion/solicitar');

      await _submitCi(tester, '12345678');
      expect(tester.takeException(), isNull);

      await _submitCi(tester, '12345672');
      expect(find.text('No pudimos enviar tu pedido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el aviso de "Revisá tu correo" no desborda', (tester) async {
      final container = await pumpRecoveryApp(tester, size: size);
      await goTo(tester, container, '/recuperacion/solicitar');

      await _submitCi(tester, '12345672');

      expect(find.text(_requestedMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
