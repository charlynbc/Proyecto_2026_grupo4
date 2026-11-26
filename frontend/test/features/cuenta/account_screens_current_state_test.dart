import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/providers/account_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import 'account_current_state_support.dart';
import 'account_test_support.dart';

const _typedAddress = 'Calle escrita a mano 99';

Future<void> _typeDraft(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('edit-address')), _typedAddress);
  await tester.enterText(find.byKey(const Key('edit-phone1')), '098000111');
  await tester.pump();
}

void _expectDraft(WidgetTester tester) {
  expect(fieldValue(tester, 'address'), _typedAddress);
  expect(fieldValue(tester, 'phone1'), '098000111');
}

void _renewSession(ProviderContainer container) => container
    .read(sessionProvider.notifier)
    .setAuthenticated(accessToken: 'otro-token', role: UserRole.socio);

/// Editar con un borrador escrito y el pedido hecho al volver ya fallado.
Future<ProviderContainer> _editWithFailedReturn(
  WidgetTester tester,
  CurrentStateRepository repo,
) async {
  final container = await pumpAccountScreens(
    tester,
    repo,
    location: kAccountEditPath,
  );
  await _typeDraft(tester);
  repo.error = const ApiException('Fallo controlado.');
  await returnToApp(tester);
  await tester.pumpAndSettle();
  expect(repo.calls, 2);
  expect(container.read(accountProvider).hasError, isTrue);
  return container;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('edit-save')));
  await tester.tap(find.byKey(const Key('edit-save')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Reintentar tras un error con dato previo muestra la carga', (
    tester,
  ) async {
    final repo = CurrentStateRepository();
    final container = await pumpAccountScreens(tester, repo);
    repo.error = const ApiException('Fallo controlado.');
    container.invalidate(accountProvider);
    await tester.pumpAndSettle();
    expect(find.text(loadError), findsOneWidget);
    expect(container.read(accountProvider).hasValue, isTrue);

    repo.error = null;
    final gate = repo.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('account-retry')));
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(loadError), findsNothing);
    expect(find.byKey(const Key('account-address')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'account-address'), oldAddress);
  });

  testWidgets('si falla el pedido al volver, Mi cuenta muestra el error con '
      'Reintentar', (tester) async {
    final repo = CurrentStateRepository();
    await pumpAccountScreens(tester, repo);
    repo.error = const ApiException('Fallo controlado.');
    await returnToApp(tester);
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text(loadError), findsOneWidget);
    expect(find.byKey(const Key('account-retry')), findsOneWidget);
    expect(find.byKey(const Key('account-address')), findsNothing);
  });

  testWidgets('si cambia la sesión, Mi cuenta muestra la carga y no los datos '
      'anteriores', (tester) async {
    final repo = CurrentStateRepository();
    final container = await pumpAccountScreens(tester, repo);

    final gate = repo.gate = Completer<void>();
    _renewSession(container);
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('account-address')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'account-address'), oldAddress);
  });

  testWidgets('Editar conserva lo escrito cuando la cuenta se refresca con la '
      'misma cédula y rol', (tester) async {
    final repo = CurrentStateRepository();
    final container = await pumpAccountScreens(
      tester,
      repo,
      location: kAccountEditPath,
    );
    await _typeDraft(tester);

    repo.account = movedLucia();
    final gate = repo.gate = Completer<void>();
    container.invalidate(accountProvider);
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    _expectDraft(tester);

    gate.complete();
    await tester.pumpAndSettle();

    final account = container.read(accountProvider).requireValue;
    expect(account.ci, '45678911');
    expect(account.role, UserRole.socio);
    expect(account.address, newAddress);
    _expectDraft(tester);
  });

  testWidgets('Editar conserva lo escrito mientras se vuelve a pedir la cuenta '
      'por un cambio de sesión', (tester) async {
    final repo = CurrentStateRepository();
    final container = await pumpAccountScreens(
      tester,
      repo,
      location: kAccountEditPath,
    );
    await _typeDraft(tester);

    final gate = repo.gate = Completer<void>();
    _renewSession(container);
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    _expectDraft(tester);

    gate.complete();
    await tester.pumpAndSettle();
    _expectDraft(tester);
  });

  testWidgets('si falla el pedido al volver, Editar conserva el formulario y '
      'lo escrito', (tester) async {
    await _editWithFailedReturn(tester, CurrentStateRepository());

    expect(find.text(loadError), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    _expectDraft(tester);
  });

  testWidgets('tras un pedido fallido, Guardar vuelve a leer la cuenta y '
      'guarda', (tester) async {
    final repo = CurrentStateRepository();
    await _editWithFailedReturn(tester, repo);

    repo.error = null;
    await _tapSave(tester);

    // La carga, la que falló al volver, la relectura antes de escribir y la del
    // cambio de pantalla instantáneo al llegar a Mi cuenta.
    expect(repo.calls, 4);
    expect(repo.updates, 1);
    expect(textOf(tester, 'account-address'), newAddress);
  });

  testWidgets('tras un pedido fallido, no guarda si la nueva lectura trae '
      'otra cuenta', (tester) async {
    final repo = CurrentStateRepository();
    await _editWithFailedReturn(tester, repo);

    repo.error = null;
    repo.account = Account.fromJson({...luciaJson(), 'ci': '12345672'});
    await _tapSave(tester);

    expect(repo.calls, 3);
    expect(repo.updates, 0);
    expect(
      textOf(tester, 'edit-error'),
      'La sesión cambió durante el guardado.',
    );
    _expectDraft(tester);
  });
}
