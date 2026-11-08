import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/load_roboto.dart';

class _ActivationLinkError extends InvalidActivationLinkException {
  const _ActivationLinkError();

  @override
  String get message =>
      'El servidor no acepta este enlace para activar la cuenta.';
}

void _expectInvalidActivationNotice() {
  expect(find.text('Este enlace ya no sirve'), findsOneWidget);
  expect(
    find.text('El servidor no acepta este enlace para activar la cuenta.'),
    findsOneWidget,
  );
  expect(
    find.text('Podés pedir un enlace nuevo con tu cédula.'),
    findsOneWidget,
  );
  expect(
    find.text('Si el problema sigue, comunicate con la institución.'),
    findsOneWidget,
  );
  expect(
    find.textContaining(
      RegExp(r'venci[oó]|se us[oó]|reemplaz', caseSensitive: false),
    ),
    findsNothing,
  );
}

Finder get _fields => find.byType(TextFormField);
Finder get _activate => find.widgetWithText(FilledButton, 'Activar cuenta');

Future<ProviderContainer> _openActivation(
  WidgetTester tester, {
  RecordingFirstLoginRepository? repo,
  String token = 'abc123',
}) async {
  final container = await pumpApp(tester, firstLogin: repo);
  await goTo(tester, container, '/primer-ingreso?token=$token');
  return container;
}

Future<void> _fill(
  WidgetTester tester, {
  String address = 'Av. 18 de Julio 1234',
  String phone1 = '099123456',
  String phone2 = '',
  String password = 'claveSegura1',
  String confirm = 'claveSegura1',
}) async {
  await tester.enterText(_fields.at(0), address);
  await tester.enterText(_fields.at(1), phone1);
  await tester.enterText(_fields.at(2), phone2);
  await tester.enterText(_fields.at(3), password);
  await tester.enterText(_fields.at(4), confirm);
}

void main() {
  setUpAll(loadRoboto);

  group('activación de la cuenta', () {
    testWidgets('pide dirección, teléfono 1, contraseña y confirmación; el '
        'correo no se edita', (tester) async {
      final repo = RecordingFirstLoginRepository();
      await _openActivation(tester, repo: repo);

      // Dirección, teléfono 1, teléfono 2, contraseña y confirmación: ningún
      // campo de correo.
      expect(_fields, findsNWidgets(5));
      expect(find.textContaining('no se puede cambiar'), findsOneWidget);

      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(find.text('Ingresá tu dirección.'), findsOneWidget);
      expect(find.text('Ingresá un teléfono.'), findsOneWidget);
      expect(find.text('Elegí una contraseña.'), findsOneWidget);
      expect(find.text('Repetí la contraseña.'), findsOneWidget);
      expect(repo.activations, isEmpty);
    });

    testWidgets('la contraseña necesita al menos 8 caracteres', (tester) async {
      final repo = RecordingFirstLoginRepository();
      await _openActivation(tester, repo: repo);

      await _fill(tester, password: 'corta12', confirm: 'corta12');
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(
        find.text('La contraseña tiene que tener al menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(repo.activations, isEmpty);
    });

    testWidgets('la confirmación tiene que coincidir', (tester) async {
      final repo = RecordingFirstLoginRepository();
      await _openActivation(tester, repo: repo);

      await _fill(tester, confirm: 'otraClave123');
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(
        find.text('Las contraseñas no coinciden. Escribilas de nuevo.'),
        findsOneWidget,
      );
      expect(repo.activations, isEmpty);
    });

    testWidgets('el teléfono 2 es opcional: sin él se activa y vuelve al '
        'login con aviso', (tester) async {
      final repo = RecordingFirstLoginRepository();
      final container = await _openActivation(tester, repo: repo);

      await _fill(tester);
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(repo.activations, [
        {
          'token': 'abc123',
          'address': 'Av. 18 de Julio 1234',
          'phone1': '099123456',
          'phone2': null,
          'password': 'claveSegura1',
        },
      ]);
      expect(locationOf(container), '/login?acceso=socio&activada=1');
      expect(find.text('Tu cuenta quedó activa'), findsOneWidget);
    });

    testWidgets('con teléfono 2 lo envía', (tester) async {
      final repo = RecordingFirstLoginRepository();
      await _openActivation(tester, repo: repo);

      await _fill(tester, phone2: '24001234');
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(repo.activations.single['phone2'], '24001234');
    });

    testWidgets('enlace vencido o ya usado: explica y ofrece pedir otro', (
      tester,
    ) async {
      final container = await _openActivation(
        tester,
        repo: RecordingFirstLoginRepository(
          activateError: const _ActivationLinkError(),
        ),
      );

      await _fill(tester);
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      _expectInvalidActivationNotice();
      expect(_fields, findsNothing);
      expect(_activate, findsNothing);

      await tester.tap(find.text('Pedir un enlace nuevo'));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/primer-ingreso/solicitar');
    });

    testWidgets(
      'con el repository falso, el token "usado" da enlace inválido',
      (tester) async {
        // La validación al abrir ya rechaza el enlace: el aviso aparece sin
        // llenar el formulario, que ni siquiera se muestra.
        final container = await _openActivation(
          tester,
          token: FakeFirstLoginRepository.usedToken,
        );

        expect(_fields, findsNothing);
        expect(_activate, findsNothing);
        expect(find.text('Este enlace ya no sirve'), findsOneWidget);

        await tester.tap(find.text('Pedir un enlace nuevo'));
        await tester.pumpAndSettle();
        expect(locationOf(container), '/primer-ingreso/solicitar');
      },
    );

    testWidgets(
      'aviso al guardar primer ingreso a 320 px con Roboto no desborda',
      (tester) async {
        final repo = RecordingFirstLoginRepository(
          activateError: const _ActivationLinkError(),
        );
        final container = await _openActivation(tester, repo: repo);
        await _fill(tester);
        tester.view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        await tester.ensureVisible(_activate);
        await tester.tap(_activate);
        await tester.pumpAndSettle();

        expect(tester.view.physicalSize, const Size(320, 640));
        expect(repo.activations, hasLength(1));
        _expectInvalidActivationNotice();
        expect(_fields, findsNothing);
        expect(_activate, findsNothing);
        expect(find.text('Pedir un enlace nuevo'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Pedir un enlace nuevo'));
        await tester.tap(find.text('Pedir un enlace nuevo'));
        await tester.pumpAndSettle();
        expect(locationOf(container), '/primer-ingreso/solicitar');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('otro error se muestra con su mensaje y deja reintentar', (
      tester,
    ) async {
      await _openActivation(
        tester,
        repo: RecordingFirstLoginRepository(
          activateError: const AuthException('No hay conexión.'),
        ),
      );

      await _fill(tester);
      await tester.tap(_activate);
      await tester.pumpAndSettle();

      expect(find.text('No hay conexión.'), findsOneWidget);
      expect(_activate, findsOneWidget);
    });
  });

  group('pedir el enlace', () {
    testWidgets('muestra siempre el mismo mensaje y envía cédula y acceso', (
      tester,
    ) async {
      final repo = RecordingFirstLoginRepository();
      final container = await pumpApp(tester, firstLogin: repo);
      await goTo(
        tester,
        container,
        '/primer-ingreso/solicitar?acceso=empleado',
      );

      await tester.enterText(_fields.first, '12345672');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.text(kFirstLoginRequestedMessage), findsOneWidget);
      expect(repo.requests.single.ci, '12345672');
      expect(repo.requests.single.access, AccessType.empleado);
    });

    testWidgets('valida la cédula antes de enviar', (tester) async {
      final repo = RecordingFirstLoginRepository();
      final container = await pumpApp(tester, firstLogin: repo);
      await goTo(tester, container, '/primer-ingreso/solicitar');

      await tester.enterText(_fields.first, '12345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La cédula no es válida'), findsOneWidget);
      expect(repo.requests, isEmpty);
      expect(find.text(kFirstLoginRequestedMessage), findsNothing);
    });

    testWidgets('en Android no ofrece el acceso de empleados', (tester) async {
      final container = await pumpApp(tester, employeeAccess: false);
      await goTo(
        tester,
        container,
        '/primer-ingreso/solicitar?acceso=empleado',
      );

      expect(find.byType(SegmentedButton<AccessType>), findsNothing);
    });
  });
}
