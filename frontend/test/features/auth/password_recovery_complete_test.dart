import 'dart:async';

import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'recovery_test_support.dart';

const _recoveredMessage =
    'Tu contraseña se actualizó correctamente. Ya podés iniciar sesión.';
const _invalidLinkMessage =
    'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.';

Finder get _fields => find.byType(TextFormField);
Finder get _save => find.widgetWithText(FilledButton, 'Guardar contraseña');

Future<ProviderContainer> _open(
  WidgetTester tester, {
  RecordingPasswordRecoveryRepository? repo,
  String token = 'abc123',
  Size size = const Size(900, 1800),
}) async {
  final container = await pumpRecoveryApp(tester, recovery: repo, size: size);
  await goTo(tester, container, '/recuperacion?token=$token');
  return container;
}

Future<void> _fill(
  WidgetTester tester, {
  required String password,
  String? confirm,
}) async {
  await tester.enterText(_fields.at(0), password);
  await tester.enterText(_fields.at(1), confirm ?? password);
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  test('el aviso del login es el texto exacto del contrato', () {
    expect(kPasswordRecoveredMessage, _recoveredMessage);
  });

  testWidgets('muestra el título, los dos campos y el botón', (tester) async {
    await _open(tester);

    expect(find.text('Nueva contraseña'), findsOneWidget);
    expect(find.text('Contraseña nueva'), findsOneWidget);
    expect(find.text('Repetir contraseña'), findsOneWidget);
    expect(_fields, findsNWidgets(2));
    expect(_save, findsOneWidget);
  });

  testWidgets('vacías: pide elegir y repetir la contraseña', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _tapSave(tester);

    expect(find.text('Elegí una contraseña.'), findsOneWidget);
    expect(find.text('Repetí la contraseña.'), findsOneWidget);
    expect(repo.completions, isEmpty);
  });

  testWidgets('7 caracteres da el error de 8', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _fill(tester, password: 'corta12');
    await _tapSave(tester);

    expect(
      find.text('La contraseña tiene que tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(repo.completions, isEmpty);
  });

  testWidgets('37 "ñ" (74 bytes) dan el error de largo', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _fill(tester, password: 'ñ' * 37);
    await _tapSave(tester);

    expect(
      find.text('La contraseña es demasiado larga. Usá una más corta.'),
      findsOneWidget,
    );
    expect(repo.completions, isEmpty);
  });

  testWidgets('35 "ñ" y 3 letras (73 bytes, uno de más) dan el error de '
      'largo', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _fill(tester, password: '${'ñ' * 35}abc');
    await _tapSave(tester);

    expect(
      find.text('La contraseña es demasiado larga. Usá una más corta.'),
      findsOneWidget,
    );
    expect(repo.completions, isEmpty);
  });

  testWidgets('36 "ñ" (72 bytes) pasan', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _fill(tester, password: 'ñ' * 36);
    await _tapSave(tester);

    expect(
      find.text('La contraseña es demasiado larga. Usá una más corta.'),
      findsNothing,
    );
    expect(repo.completions.single.password, 'ñ' * 36);
  });

  testWidgets('contraseñas distintas dan el error de coincidencia', (
    tester,
  ) async {
    final repo = RecordingPasswordRecoveryRepository();
    await _open(tester, repo: repo);

    await _fill(tester, password: 'claveNueva9', confirm: 'claveNueva8');
    await _tapSave(tester);

    expect(
      find.text('Las contraseñas no coinciden. Escribilas de nuevo.'),
      findsOneWidget,
    );
    expect(repo.completions, isEmpty);
  });

  testWidgets('con datos válidos llama una vez con el token de la URL y vuelve '
      'al login con el aviso', (tester) async {
    final repo = RecordingPasswordRecoveryRepository();
    final container = await _open(tester, repo: repo, token: 'tok-789');

    await _fill(tester, password: 'claveNueva9');
    await _tapSave(tester);

    expect(repo.completions, [(token: 'tok-789', password: 'claveNueva9')]);
    expect(locationOf(container), '/login?recuperada=1');
    expect(find.text(_recoveredMessage), findsOneWidget);
  });

  testWidgets('dos toques seguidos hacen una sola llamada', (tester) async {
    final repo = RecordingPasswordRecoveryRepository()
      ..completeGate = Completer<void>();
    await _open(tester, repo: repo);

    await _fill(tester, password: 'claveNueva9');
    // Sin redibujar entre los dos toques, como en un doble clic rápido: el
    // botón todavía está habilitado y lo único que frena el segundo pedido es
    // el controlador.
    await tester.tap(_save);
    await tester.tap(_save);
    await tester.pump();
    repo.completeGate!.complete();
    await tester.pumpAndSettle();

    expect(repo.completions, hasLength(1));
  });

  testWidgets('enlace inválido: muestra el mensaje y "Pedir un enlace nuevo" '
      'lleva a pedir otro', (tester) async {
    final container = await _open(
      tester,
      repo: RecordingPasswordRecoveryRepository(
        completeError: const InvalidRecoveryLinkException(_invalidLinkMessage),
      ),
    );

    await _fill(tester, password: 'claveNueva9');
    await _tapSave(tester);

    expect(find.text('No pudimos cambiar tu contraseña'), findsOneWidget);
    expect(find.text('Este enlace ya no sirve'), findsNothing);
    expect(find.text(_invalidLinkMessage), findsOneWidget);
    await tester.tap(find.text('Pedir un enlace nuevo'));
    await tester.pumpAndSettle();
    expect(locationOf(container), '/recuperacion/solicitar');
  });

  testWidgets('VALIDACION: muestra el mensaje y deja reintentar', (
    tester,
  ) async {
    final repo = RecordingPasswordRecoveryRepository(
      completeError: const AuthException(
        'La contraseña debe tener entre 8 caracteres y 72 bytes',
      ),
    );
    final container = await _open(tester, repo: repo);

    await _fill(tester, password: 'claveNueva9');
    await _tapSave(tester);

    expect(
      find.text('La contraseña debe tener entre 8 caracteres y 72 bytes'),
      findsOneWidget,
    );
    expect(_save, findsOneWidget);

    repo.completeError = null;
    await _tapSave(tester);

    expect(repo.completions, hasLength(2));
    expect(locationOf(container), '/login?recuperada=1');
  });

  testWidgets('con el repositorio falso, el token "vencido" da enlace '
      'inválido', (tester) async {
    // La validación al abrir ya rechaza el enlace: el aviso aparece sin
    // llenar el formulario, que ni siquiera se muestra.
    final container = await _open(tester, token: 'vencido');

    expect(_fields, findsNothing);
    expect(_save, findsNothing);
    expect(find.text(_invalidLinkMessage), findsOneWidget);

    await tester.tap(find.text('Pedir un enlace nuevo'));
    await tester.pumpAndSettle();
    expect(locationOf(container), '/recuperacion/solicitar');
  });

  group('a 320 px con Roboto', () {
    const size = Size(320, 640);

    testWidgets('el formulario con los errores a la vista no desborda', (
      tester,
    ) async {
      await _open(tester, size: size);

      await _fill(tester, password: 'ñ' * 37, confirm: 'otra');
      await _tapSave(tester);

      expect(
        find.text('La contraseña es demasiado larga. Usá una más corta.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error del servidor no desborda', (tester) async {
      await _open(
        tester,
        size: size,
        repo: RecordingPasswordRecoveryRepository(
          completeError: const AuthException(
            'La contraseña debe tener entre 8 caracteres y 72 bytes',
          ),
        ),
      );

      await _fill(tester, password: 'claveNueva9');
      await _tapSave(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('el aviso de enlace inválido no desborda', (tester) async {
      await _open(tester, size: size, token: 'vencido');

      expect(_fields, findsNothing);
      expect(_save, findsNothing);
      expect(find.text(_invalidLinkMessage), findsOneWidget);
      expect(find.text('Pedir un enlace nuevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
