import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/providers/account_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart' show pumpApp, unmountApp;
import 'account_current_state_support.dart';
import 'account_test_support.dart';

/// Empieza un guardado sin esperarlo y anota cómo termina.
({Account? Function() saved, Object? Function() failure}) _startSave(
  ProviderContainer container,
) {
  Account? saved;
  Object? failure;
  unawaited(
    container
        .read(accountProvider.notifier)
        .save(const AccountChanges(address: newAddress))
        .then<void>(
          (account) => saved = account,
          onError: (Object error) {
            failure = error;
          },
        ),
  );
  return (saved: () => saved, failure: () => failure);
}

Future<void> _openEdit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-edit')));
  await tester.pumpAndSettle();
}

/// Escribe la dirección nueva en Editar y toca "Guardar".
Future<void> _writeAddressAndSave(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('edit-address')), newAddress);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('edit-save')));
  await tester.tap(find.byKey(const Key('edit-save')));
  await tester.pump();
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('volver a la app pide la cuenta una vez y muestra el dato nuevo '
      'sin pantalla de carga', (tester) async {
    final repo = CurrentStateRepository();
    await pumpAccountScreens(tester, repo);
    expect(repo.calls, 1);
    expect(textOf(tester, 'account-address'), oldAddress);

    repo.account = movedLucia();
    final gate = repo.gate = Completer<void>();
    await returnToApp(tester);

    expect(repo.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(textOf(tester, 'account-address'), oldAddress);

    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'account-address'), newAddress);
    expect(repo.calls, 2);
  });

  testWidgets('guardar bien volviendo a la app en el medio no suma pedidos ni '
      'corta el guardado', (tester) async {
    final repo = CurrentStateRepository()..saveGate = Completer<void>();
    final container = await pumpAccountScreens(tester, repo);
    await _openEdit(tester);
    expect(repo.calls, 2);

    await _writeAddressAndSave(tester);
    await returnToApp(tester);
    expect(repo.calls, 2);
    expect(container.read(accountProvider).isLoading, isFalse);

    repo.saveGate!.complete();
    await tester.pumpAndSettle();

    expect(repo.updates, 1);
    expect(textOf(tester, 'account-address'), newAddress);
    expect(repo.calls, 2);
  });

  testWidgets('volver a la app durante un guardado que falla pide la cuenta '
      'una vez al terminar', (tester) async {
    final repo = CurrentStateRepository()
      ..saveGate = Completer<void>()
      ..saveError = const ApiException('Fallo controlado al guardar.');
    final container = await pumpAccountScreens(tester, repo);
    final save = _startSave(container);
    await tester.pump();
    await returnToApp(tester);
    await returnToApp(tester);
    expect(repo.calls, 1);

    repo.saveGate!.complete();
    await tester.pumpAndSettle();

    expect(
      (save.failure()! as ApiException).message,
      'Fallo controlado al guardar.',
    );
    expect(repo.calls, 2);
    expect(textOf(tester, 'account-address'), oldAddress);
  });

  testWidgets('un cambio de sesión durante un guardado que falla se pide como '
      'recarga al terminar', (tester) async {
    final repo = CurrentStateRepository()
      ..saveGate = Completer<void>()
      ..saveError = const ApiException('Fallo controlado al guardar.');
    final container = await pumpAccountScreens(tester, repo);
    _startSave(container);
    await tester.pump();
    container
        .read(sessionProvider.notifier)
        .setAuthenticated(accessToken: 'otro-token', role: UserRole.socio);
    await returnToApp(tester);
    expect(repo.calls, 1);

    final gate = repo.gate = Completer<void>();
    repo.saveGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    expect(container.read(accountProvider).isReloading, isTrue);

    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });

  testWidgets('camino real: se lee al abrir Inicio y al abrir Editar, no al '
      'guardar y volver', (tester) async {
    final repo = CurrentStateRepository();
    final container = await pumpApp(
      tester,
      overrides: [accountRepositoryProvider.overrideWith((ref) async => repo)],
    );
    await loginAs(tester, container, UserRole.socio);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final router = appRouter(container);
    expect(locationOf(router), '/socio/inicio');
    expect(repo.calls, 1);

    await tester.tap(find.byKey(const Key('open-account')));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    // Al abrir Editar el provider informa un cambio de pantalla instantáneo.
    await _openEdit(tester);
    expect(topOf(router), '/cuenta/editar');
    expect(repo.calls, 2);

    await _writeAddressAndSave(tester);
    await tester.pumpAndSettle();
    expect(topOf(router), '/cuenta');
    expect(repo.updates, 1);
    expect(textOf(tester, 'account-address'), newAddress);
    expect(repo.calls, 2);
    await unmountApp(tester);
  });

  testWidgets('Mi cuenta sobre Inicio: tras ir a segundo plano muestra el '
      'teléfono nuevo', (tester) async {
    final repo = CurrentStateRepository();
    final container = await pumpApp(
      tester,
      overrides: [accountRepositoryProvider.overrideWith((ref) async => repo)],
    );
    await loginAs(tester, container, UserRole.socio);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-account')));
    await tester.pumpAndSettle();
    expect(topOf(appRouter(container)), '/cuenta');
    expect(textOf(tester, 'account-phone1'), '099123456');
    expect(repo.calls, 1);

    repo.account = Account.fromJson({...luciaJson(), 'telefono1': '098765432'});
    backgroundAndReturn(tester);
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(textOf(tester, 'account-phone1'), '098765432');
    await unmountApp(tester);
  });

  testWidgets('entrada directa a Editar: guardar lee la cuenta una vez más al '
      'llegar a Mi cuenta', (tester) async {
    final repo = CurrentStateRepository();
    await pumpAccountScreens(tester, repo, location: kAccountEditPath);
    expect(repo.calls, 1);

    await _writeAddressAndSave(tester);
    await tester.pumpAndSettle();

    expect(repo.updates, 1);
    expect(textOf(tester, 'account-address'), newAddress);
    expect(repo.calls, 2);
  });

  testWidgets(
    'medición: pedidos de la cuenta al abrir Mi cuenta desde Inicio',
    (tester) async {
      final repo = CurrentStateRepository();
      final container = await pumpApp(
        tester,
        overrides: [
          accountRepositoryProvider.overrideWith((ref) async => repo),
        ],
      );
      await loginAs(tester, container, UserRole.socio);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final router = appRouter(container);
      expect(locationOf(router), '/socio/inicio');
      final onHome = repo.calls;

      await tester.tap(find.byKey(const Key('open-account')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(topOf(router), '/cuenta');

      // Número medido antes del cambio: Mi cuenta usa la cuenta que ya pidió
      // Inicio y al abrirla no sale otro pedido.
      expect(
        (enInicio: onHome, alAbrir: repo.calls - onHome),
        (enInicio: 1, alAbrir: 0),
      );
      await unmountApp(tester);
    },
  );
}
