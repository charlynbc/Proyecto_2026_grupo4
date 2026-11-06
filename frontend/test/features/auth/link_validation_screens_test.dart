import 'dart:async';

import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:agenda_medica/features/auth/screens/first_login_activation_screen.dart';
import 'package:agenda_medica/features/auth/screens/password_recovery_complete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'link_validation_test_support.dart';

const _serverMessage = 'Mensaje del servidor para el enlace.';

/// Una de las dos pantallas que validan el enlace al abrirse. Los dos flujos
/// siguen la misma regla, con sus textos de hoy.
class _Flow {
  const _Flow({
    required this.name,
    required this.path,
    required this.requestPath,
    required this.invalidError,
    required this.saveLabel,
    required this.fieldCount,
    required this.expectNotice,
    required this.screen,
  });

  final String name;
  final String path;
  final String requestPath;
  final Object invalidError;
  final String saveLabel;
  final int fieldCount;
  final void Function() expectNotice;
  final Widget Function(String token) screen;

  Finder get fields => find.byType(TextFormField);
  Finder get save => find.widgetWithText(FilledButton, saveLabel);
  Finder get newLinkButton => find.text('Pedir un enlace nuevo');

  void expectForm() {
    expect(fields, findsNWidgets(fieldCount));
    expect(save, findsOneWidget);
    expect(newLinkButton, findsNothing);
  }

  void expectNoForm() {
    expect(fields, findsNothing);
    expect(save, findsNothing);
  }
}

final _flows = <_Flow>[
  _Flow(
    name: 'recuperación',
    path: '/recuperacion',
    requestPath: '/recuperacion/solicitar',
    invalidError: const InvalidRecoveryLinkException(_serverMessage),
    saveLabel: 'Guardar contraseña',
    fieldCount: 2,
    expectNotice: () {
      expect(find.text('No pudimos cambiar tu contraseña'), findsOneWidget);
      expect(find.text(_serverMessage), findsOneWidget);
    },
    screen: (token) => PasswordRecoveryCompleteScreen(token: token),
  ),
  _Flow(
    name: 'primer ingreso',
    path: '/primer-ingreso',
    requestPath: '/primer-ingreso/solicitar',
    invalidError: const InvalidActivationLinkException(),
    saveLabel: 'Activar cuenta',
    fieldCount: 5,
    expectNotice: () {
      expect(find.text('El enlace ya no es válido'), findsOneWidget);
      expect(find.textContaining('venció, ya se usó'), findsOneWidget);
      expect(
        find.text('Si el problema sigue, comunicate con la institución.'),
        findsOneWidget,
      );
    },
    screen: (token) => FirstLoginActivationScreen(token: token),
  ),
];

void main() {
  setUpAll(loadRoboto);

  for (final flow in _flows) {
    group('validar el enlace al abrir: ${flow.name}', () {
      testWidgets('token válido: consulta una vez y muestra el formulario', (
        tester,
      ) async {
        final link = RecordingLinkRepository();
        final container = await pumpLinkApp(tester, link: link);

        await goTo(tester, container, '${flow.path}?token=abc123');

        expect(link.tokens, ['abc123']);
        flow.expectForm();
      });

      testWidgets('token vencido: muestra el aviso y el botón, sin el '
          'formulario', (tester) async {
        final link = RecordingLinkRepository(error: flow.invalidError);
        final container = await pumpLinkApp(tester, link: link);

        await goTo(tester, container, '${flow.path}?token=vencido');

        flow.expectNotice();
        expect(flow.newLinkButton, findsOneWidget);
        flow.expectNoForm();
      });

      testWidgets('"Pedir un enlace nuevo" lleva a pedir el enlace de esta '
          'pantalla', (tester) async {
        final link = RecordingLinkRepository(error: flow.invalidError);
        final container = await pumpLinkApp(tester, link: link);
        await goTo(tester, container, '${flow.path}?token=vencido');

        await tester.tap(flow.newLinkButton);
        await tester.pumpAndSettle();

        expect(locationOf(container), flow.requestPath);
      });

      for (final error in <Object>[
        const AuthException('No pudimos conectarnos con el servidor.'),
        Exception('respuesta rara'),
      ]) {
        testWidgets('otro resultado ($error) no bloquea: muestra el '
            'formulario', (tester) async {
          final link = RecordingLinkRepository(error: error);
          final container = await pumpLinkApp(tester, link: link);

          await goTo(tester, container, '${flow.path}?token=abc123');

          flow.expectForm();
        });
      }

      testWidgets('una reconstrucción de la pantalla no vuelve a validar', (
        tester,
      ) async {
        final link = RecordingLinkRepository();
        final container = await pumpLinkApp(tester, link: link);
        await goTo(tester, container, '${flow.path}?token=abc123');

        // Tocar el botón con los campos vacíos reconstruye la pantalla.
        await tester.tap(flow.save);
        await tester.pumpAndSettle();
        // Cambiar el tamaño de la ventana también.
        tester.view.physicalSize = const Size(500, 1800);
        await tester.pumpAndSettle();

        expect(link.tokens, ['abc123']);
        flow.expectForm();
      });

      testWidgets('sin token no valida y muestra el formulario', (
        tester,
      ) async {
        final link = RecordingLinkRepository(error: flow.invalidError);

        await pumpLinkScreen(tester, flow.screen(''), link: link);
        await tester.pumpAndSettle();

        expect(link.tokens, isEmpty);
        flow.expectForm();
      });

      testWidgets('mientras responde muestra solo la carga, sin formulario ni '
          'aviso', (tester) async {
        final link = RecordingLinkRepository()..gate = Completer<void>();

        await pumpLinkScreen(tester, flow.screen('abc123'), link: link);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        flow.expectNoForm();
        expect(flow.newLinkButton, findsNothing);

        link.gate!.complete();
        await tester.pumpAndSettle();
        flow.expectForm();
      });

      group('a 320 px con Roboto', () {
        const size = Size(320, 640);

        testWidgets('el aviso de enlace inválido no desborda', (tester) async {
          final link = RecordingLinkRepository(error: flow.invalidError);

          await pumpLinkScreen(
            tester,
            flow.screen('vencido'),
            link: link,
            size: size,
          );
          await tester.pumpAndSettle();

          flow.expectNotice();
          expect(flow.newLinkButton, findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('la carga no desborda', (tester) async {
          final link = RecordingLinkRepository()..gate = Completer<void>();

          await pumpLinkScreen(
            tester,
            flow.screen('abc123'),
            link: link,
            size: size,
          );

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(tester.takeException(), isNull);

          link.gate!.complete();
          await tester.pumpAndSettle();
        });
      });
    });
  }
}
