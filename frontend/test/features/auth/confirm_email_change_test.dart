import 'dart:async';

import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/email_change_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'email_change_test_support.dart';

const _changedMessage = 'Tu correo se actualizó correctamente.';
const _invalidLinkMessage =
    'El enlace ya no es válido. Pedí uno nuevo desde tu perfil.';

Finder get _confirm => find.byKey(const Key('email-change-confirm'));
Finder get _home => find.byKey(const Key('email-change-home'));

Future<ProviderContainer> _open(
  WidgetTester tester, {
  RecordingEmailChangeRepository? repo,
  String token = 'abc123',
  Size size = const Size(900, 1800),
}) async {
  final container = await pumpEmailChangeApp(
    tester,
    emailChange: repo,
    size: size,
  );
  await goTo(tester, container, '/cambio-correo?token=$token');
  return container;
}

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_confirm).onPressed != null;

void main() {
  setUpAll(loadRoboto);

  test('el texto de éxito es el exacto del contrato', () {
    expect(kEmailChangedMessage, _changedMessage);
  });

  testWidgets('abre mostrando el botón y sin confirmar todavía', (
    tester,
  ) async {
    final repo = RecordingEmailChangeRepository();
    await _open(tester, repo: repo);

    expect(find.text('Confirmar cambio de correo'), findsWidgets);
    expect(
      find.text(
        'Confirmá que querés usar este correo en tu cuenta. El enlace sirve '
        'una sola vez y vale 24 horas.',
      ),
      findsOneWidget,
    );
    expect(_confirm, findsOneWidget);
    expect(_enabled(tester), isTrue);
    expect(repo.tokens, isEmpty);
  });

  testWidgets('tocar el botón confirma una vez con el token de la URL; el '
      'éxito muestra el mensaje y "Ir al inicio" lleva al login', (
    tester,
  ) async {
    final repo = RecordingEmailChangeRepository();
    final container = await _open(tester, repo: repo, token: 'tok-789');

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(repo.tokens, ['tok-789']);
    expect(find.text(_changedMessage), findsOneWidget);
    expect(_confirm, findsNothing);

    // Sin sesión, "/" lleva al login.
    await tester.tap(_home);
    await tester.pumpAndSettle();
    expect(locationOf(container), '/login');
  });

  testWidgets('el botón se apaga mientras confirma', (tester) async {
    final repo = RecordingEmailChangeRepository()..gate = Completer<void>();
    await _open(tester, repo: repo);

    await tester.tap(_confirm);
    await tester.pump();
    expect(_enabled(tester), isFalse);

    repo.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('dos toques seguidos hacen una sola llamada', (tester) async {
    final repo = RecordingEmailChangeRepository()..gate = Completer<void>();
    await _open(tester, repo: repo);

    // Sin redibujar entre los dos toques, como un doble clic rápido: el
    // botón todavía está habilitado y lo que frena el segundo es el
    // controlador.
    await tester.tap(_confirm);
    await tester.tap(_confirm);
    await tester.pump();
    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(repo.tokens, hasLength(1));
  });

  testWidgets('enlace inválido: muestra el mensaje del servidor y "Ir al '
      'inicio"', (tester) async {
    final container = await _open(
      tester,
      repo: RecordingEmailChangeRepository(
        error: const InvalidEmailChangeLinkException(_invalidLinkMessage),
      ),
    );

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(find.text(_invalidLinkMessage), findsOneWidget);
    expect(_confirm, findsNothing);
    await tester.tap(_home);
    await tester.pumpAndSettle();
    expect(locationOf(container), '/login');
  });

  testWidgets('otro error muestra el mensaje y deja reintentar', (
    tester,
  ) async {
    final repo = RecordingEmailChangeRepository(
      error: const AuthException('No hay conexión.'),
    );
    await _open(tester, repo: repo);

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(find.text('No hay conexión.'), findsOneWidget);
    expect(_confirm, findsOneWidget);
    expect(_enabled(tester), isTrue);

    repo.error = null;
    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(repo.tokens, hasLength(2));
    expect(find.text(_changedMessage), findsOneWidget);
  });

  testWidgets('con el repositorio falso, el token "vencido" da enlace '
      'inválido', (tester) async {
    await _open(tester, token: 'vencido');

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(find.text(_invalidLinkMessage), findsOneWidget);
  });

  group('a 320 px con Roboto', () {
    const size = Size(320, 640);

    testWidgets('al abrir no desborda', (tester) async {
      await _open(tester, size: size);

      expect(_confirm, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el éxito no desborda', (tester) async {
      await _open(tester, size: size);

      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(find.text(_changedMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error no desborda', (tester) async {
      await _open(tester, size: size, token: 'vencido');

      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(find.text(_invalidLinkMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
