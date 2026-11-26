import 'dart:async';

import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:agenda_medica/features/cuenta/screens/edit_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import 'account_test_support.dart';

const oldAddress = 'Av. 18 de Julio 1234, Montevideo';
const newAddress = 'Av. Italia 1234';
const loadError = 'No pudimos cargar tus datos. Intentá de nuevo.';

/// La cuenta de Lucía con otra dirección, como la devolvería el servidor.
Account movedLucia() =>
    Account.fromJson({...luciaJson(), 'direccion': newAddress});

/// Repositorio que además guarda: `update` espera [saveGate] y falla con
/// [saveError] o deja la cuenta nueva como la que devuelven los pedidos
/// siguientes.
class CurrentStateRepository extends RecordingAccountRepository {
  Completer<void>? saveGate;
  Object? saveError;
  int updates = 0;

  @override
  Future<Account> update(AccountChanges changes) async {
    updates++;
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    return account = movedLucia();
  }
}

/// Sesión de socio ya iniciada; los tests la cambian con `setAuthenticated`.
class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'sesion-de-prueba',
  );
}

/// Monta Mi cuenta y Editar, arrancando en [location].
Future<ProviderContainer> pumpAccountScreens(
  WidgetTester tester,
  CurrentStateRepository repo, {
  String location = kAccountPath,
}) async {
  await pumpAdminScreens(
    tester,
    routes: [
      GoRoute(path: kAccountPath, builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: kAccountEditPath,
        builder: (_, _) => const EditAccountScreen(),
      ),
    ],
    initialLocation: location,
    overrides: [
      sessionProvider.overrideWith(_Session.new),
      accountRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
    listen: false,
  );
}

/// La app pierde el foco y lo recupera.
Future<void> returnToApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  // El pedido se difiere un instante: un cuadro lo lanza y otro lo dibuja.
  await tester.pump();
  await tester.pump();
}

/// Lo que tiene escrito el campo `edit-[name]`.
String fieldValue(WidgetTester tester, String name) => tester
    .widget<TextFormField>(find.byKey(Key('edit-$name')))
    .controller!
    .text;
