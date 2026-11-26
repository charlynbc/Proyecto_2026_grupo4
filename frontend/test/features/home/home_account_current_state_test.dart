import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/providers/account_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../cuenta/account_current_state_support.dart' show returnToApp;
import '../cuenta/account_test_support.dart';

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'sesion-de-prueba',
  );
}

/// Monta el Inicio del socio con la cuenta de Lucía ya a la vista.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  RecordingAccountRepository repo,
) async {
  await pumpAdminScreens(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const HomeScreen(role: UserRole.socio),
      ),
    ],
    initialLocation: '/',
    size: const Size(1280, 1000),
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_Session.new),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
      accountRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  expect(textOf(tester, 'home-greeting'), 'Bienvenido/a, Lucía');
  expect(find.text('Lucía Fernández'), findsOneWidget);
  return ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
    listen: false,
  );
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Inicio conserva el saludo y el nombre mientras se vuelve a '
      'pedir la cuenta', (tester) async {
    final repo = RecordingAccountRepository();
    await _pumpHome(tester, repo);

    final gate = repo.gate = Completer<void>();
    await returnToApp(tester);

    expect(repo.calls, 2);
    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a, Lucía');
    expect(find.text('Lucía Fernández'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a, Lucía');
  });

  testWidgets('si la sesión cambia a otra cuenta, Inicio no muestra el nombre '
      'anterior', (tester) async {
    final repo = RecordingAccountRepository();
    final container = await _pumpHome(tester, repo);

    repo.account = Account.fromJson({
      ...luciaJson(),
      'ci': '12345672',
      'nombre': 'Ana',
      'apellido': 'Rodríguez',
    });
    final gate = repo.gate = Completer<void>();
    container
        .read(sessionProvider.notifier)
        .setAuthenticated(accessToken: 'otra-sesion', role: UserRole.socio);
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2);
    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a');
    expect(find.text('Lucía Fernández'), findsNothing);

    // Volver a la app con ese pedido en vuelo tampoco lo hace aparecer.
    await returnToApp(tester);
    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a');
    expect(find.text('Lucía Fernández'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a, Ana');
    expect(find.text('Ana Rodríguez'), findsOneWidget);
  });

  testWidgets('si falla el pedido al volver, Inicio saluda sin nombre', (
    tester,
  ) async {
    final repo = RecordingAccountRepository();
    final container = await _pumpHome(tester, repo);

    repo.error = const ApiException('Fallo controlado.');
    container.invalidate(accountProvider);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'home-greeting'), 'Bienvenido/a');
    expect(find.text('Lucía Fernández'), findsNothing);
  });
}
