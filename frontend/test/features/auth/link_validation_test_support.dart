import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_link_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/password_recovery_link_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/password_recovery_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_password_recovery_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_link_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_link_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Un validador de enlaces que anota los tokens que recibe. Sirve para los
/// dos flujos: tiene la misma firma en las dos interfaces. Falla con [error]
/// si se indica; con [gate] puesto, espera a que se complete.
class RecordingLinkRepository
    implements PasswordRecoveryLinkRepository, FirstLoginLinkRepository {
  RecordingLinkRepository({this.error});

  Object? error;
  Completer<void>? gate;
  final List<String> tokens = [];

  @override
  Future<void> validateLink({required String token}) async {
    tokens.add(token);
    await gate?.future;
    if (error != null) throw error!;
  }
}

List<Override> _overrides(RecordingLinkRepository link) => [
  useFakesProvider.overrideWithValue(true),
  employeeAccessAvailableProvider.overrideWithValue(true),
  firstLoginRepositoryProvider.overrideWith(
    (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
  ),
  passwordRecoveryRepositoryProvider.overrideWith(
    (ref) async => FakePasswordRecoveryRepository(latency: Duration.zero),
  ),
  passwordRecoveryLinkRepositoryProvider.overrideWith((ref) async => link),
  firstLoginLinkRepositoryProvider.overrideWith((ref) async => link),
];

/// Monta la app completa (router real) con [link] como validador de los dos
/// enlaces. `pumpApp` no acepta estos providers y no se edita, por eso este
/// helper vive acá.
Future<ProviderContainer> pumpLinkApp(
  WidgetTester tester, {
  required RecordingLinkRepository link,
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      ..._overrides(link),
      authRepositoryProvider.overrideWith(
        (ref) async => FakeAuthRepository(
          ref.read(sessionProvider.notifier),
          latency: Duration.zero,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(goRouterProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Monta una sola pantalla, sin router, para mirar la carga y el caso sin
/// token sin pasar por el guard. Un solo `pump`: la pantalla puede quedar con
/// un indicador animado.
Future<void> pumpLinkScreen(
  WidgetTester tester,
  Widget screen, {
  required RecordingLinkRepository link,
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(link),
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pump();
}
