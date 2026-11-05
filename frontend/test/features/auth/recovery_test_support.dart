import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/password_recovery_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_password_recovery_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un [PasswordRecoveryRepository] que anota los pedidos y las contraseñas
/// nuevas. Falla con [requestError] o [completeError] si se indican; con
/// [completeGate] puesto, `complete` espera a que se complete.
class RecordingPasswordRecoveryRepository
    implements PasswordRecoveryRepository {
  RecordingPasswordRecoveryRepository({this.requestError, this.completeError});

  final Exception? requestError;
  Exception? completeError;
  Completer<void>? completeGate;
  final List<({String ci, AccessType access})> requests = [];
  final List<({String token, String password})> completions = [];

  @override
  Future<void> requestLink({
    required String ci,
    required AccessType access,
  }) async {
    requests.add((ci: ci, access: access));
    if (requestError != null) throw requestError!;
  }

  @override
  Future<void> complete({
    required String token,
    required String password,
  }) async {
    completions.add((token: token, password: password));
    await completeGate?.future;
    if (completeError != null) throw completeError!;
  }
}

/// Un [AuthRepository] cuyo login queda en curso hasta que se complete
/// [gate], y después rechaza las credenciales: sirve para mirar la pantalla
/// de login mientras carga.
class GatedAuthRepository implements AuthRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    await gate.future;
    throw const InvalidCredentialsException();
  }

  @override
  Future<void> refresh() async => throw const AuthException();

  @override
  Future<void> logout() async {}
}

/// Monta la app completa como `pumpApp`, con el repositorio de recuperación
/// [recovery] (o el falso sin latencia) y, si se indica, el de login [auth].
/// `pumpApp` no acepta el de recuperación y no se edita, por eso este helper
/// vive acá.
Future<ProviderContainer> pumpRecoveryApp(
  WidgetTester tester, {
  PasswordRecoveryRepository? recovery,
  AuthRepository? auth,
  bool employeeAccess = true,
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      employeeAccessAvailableProvider.overrideWithValue(employeeAccess),
      authRepositoryProvider.overrideWith(
        (ref) async =>
            auth ??
            FakeAuthRepository(
              ref.read(sessionProvider.notifier),
              latency: Duration.zero,
            ),
      ),
      firstLoginRepositoryProvider.overrideWith(
        (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
      ),
      passwordRecoveryRepositoryProvider.overrideWith(
        (ref) async =>
            recovery ?? FakePasswordRecoveryRepository(latency: Duration.zero),
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
