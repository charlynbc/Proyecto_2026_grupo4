import 'dart:async';

import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/change_password_controller.dart';
import 'package:agenda_medica/features/cuenta/providers/password_change_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/repositories/password_change_repository.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import 'account_test_support.dart';

class RecordingPasswordRepository implements PasswordChangeRepository {
  RecordingPasswordRepository({this.error, this.gate});

  final Object? error;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
  }
}

Finder field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<void> openForm(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
}) async {
  final container = await pumpAccountApp(tester, size: size);
  await loginAs(tester, container, UserRole.socio);
  appRouter(container).go(kAccountPasswordPath);
  await tester.pumpAndSettle();
}

Future<void> fill(
  WidgetTester tester, {
  String current = 'prueba1234',
  String next = 'claveNueva9',
  String repeat = 'claveNueva9',
}) async {
  await tester.enterText(field('password-current'), current);
  await tester.enterText(field('password-new'), next);
  await tester.enterText(field('password-repeat'), repeat);
}

void main() {
  test('el controlador ignora una segunda solicitud mientras guarda', () async {
    final gate = Completer<void>();
    final repo = RecordingPasswordRepository(gate: gate);
    final container = ProviderContainer(
      overrides: [
        passwordChangeRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      changePasswordControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      changePasswordControllerProvider.notifier,
    );
    final first = controller.submit(
      currentPassword: 'actual',
      newPassword: 'nueva123',
    );
    final second = await controller.submit(
      currentPassword: 'actual',
      newPassword: 'nueva123',
    );
    expect(second, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 1);
    gate.complete();
    expect(await first, isTrue);
  });

  for (final testCase in [
    (
      PasswordChangeFailure.validation,
      'Mensaje de validación del servidor',
      'Mensaje de validación del servidor',
    ),
    (
      PasswordChangeFailure.other,
      'Error interno',
      'No pudimos cambiar tu contraseña. Intentá de nuevo.',
    ),
  ]) {
    testWidgets('muestra error general ${testCase.$1} y lo limpia al editar', (
      tester,
    ) async {
      final repo = RecordingPasswordRepository(
        error: PasswordChangeException(testCase.$1, testCase.$2),
      );
      final container = await pumpAccountApp(tester, passwordRepository: repo);
      await loginAs(tester, container, UserRole.socio);
      appRouter(container).go(kAccountPasswordPath);
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.byKey(const Key('password-save')));
      await tester.pumpAndSettle();
      final errorFinder = find.byKey(const Key('password-error'));
      final error = tester.widget<Text>(errorFinder);
      expect(error.data, testCase.$3);
      expect(
        error.style?.color,
        Theme.of(tester.element(errorFinder)).colorScheme.error,
      );
      await tester.enterText(field('password-current'), 'otra clave');
      await tester.pump();
      expect(errorFinder, findsNothing);
    });
  }

  testWidgets('dos toques envían una sola solicitud', (tester) async {
    final gate = Completer<void>();
    final repo = RecordingPasswordRepository(gate: gate);
    final container = await pumpAccountApp(tester, passwordRepository: repo);
    await loginAs(tester, container, UserRole.socio);
    appRouter(container).go(kAccountPasswordPath);
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pump();
    expect(repo.calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('valida obligatorios y coincidencia', (tester) async {
    await openForm(tester);
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá tu contraseña actual.'), findsOneWidget);
    expect(find.text('Elegí una contraseña nueva.'), findsOneWidget);
    expect(find.text('Repetí la contraseña nueva.'), findsOneWidget);

    await fill(tester, repeat: 'distinta99');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Las contraseñas no coinciden. Escribilas de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('valida siete caracteres y el límite en bytes UTF-8', (
    tester,
  ) async {
    await openForm(tester);
    await fill(tester, next: '1234567', repeat: '1234567');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('La contraseña tiene que tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('password-error')), findsNothing);

    await fill(tester, next: 'ñ' * 37, repeat: 'ñ' * 37);
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('La contraseña es demasiado larga. Usá una más corta.'),
      findsOneWidget,
    );

    await fill(tester, next: 'ñ' * 36, repeat: 'ñ' * 36);
    await tester.pumpAndSettle();
    expect(
      find.text('La contraseña es demasiado larga. Usá una más corta.'),
      findsNothing,
    );
  });

  testWidgets('éxito conserva la sesión y vuelve a Mi cuenta con aviso', (
    tester,
  ) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.socio);
    final router = appRouter(container);
    router.go(kAccountPath);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-password')));
    await tester.pumpAndSettle();
    expect(topOf(router), kAccountPasswordPath);

    await fill(tester);
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(topOf(router), kAccountPath);
    expect(find.byKey(const Key('password-changed')), findsOneWidget);
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });

  testWidgets('clave actual incorrecta conserva las nuevas y la sesión', (
    tester,
  ) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.socio);
    appRouter(container).go(kAccountPasswordPath);
    await tester.pumpAndSettle();
    await fill(tester, current: 'equivocada');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byKey(const Key('password-current-error')), findsOneWidget);
    final error = tester.widget<Text>(
      find.byKey(const Key('password-current-error')),
    );
    expect(error.data, 'La contraseña actual no es correcta.');
    expect(
      error.style?.color,
      Theme.of(tester.element(find.byKey(const Key('password-current-error'))))
          .colorScheme
          .error,
    );
    expect(
      tester.widget<TextFormField>(field('password-new')).controller!.text,
      'claveNueva9',
    );
    expect(
      tester.widget<TextFormField>(field('password-repeat')).controller!.text,
      'claveNueva9',
    );
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });

  testWidgets('deshabilita Guardar durante el pedido', (tester) async {
    await openForm(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('password-save')))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a 320 px muestra los errores sin desbordes', (tester) async {
    await loadRoboto();
    await openForm(tester, size: const Size(320, 640));
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá tu contraseña actual.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
