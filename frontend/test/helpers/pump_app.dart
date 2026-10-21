import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un [AuthRepository] que anota los logins y rechaza todos con
/// `CREDENCIALES_INVALIDAS`.
class RecordingAuthRepository implements AuthRepository {
  final List<({String ci, String password, AccessType access})> logins = [];

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    logins.add((ci: ci, password: password, access: access));
    throw const InvalidCredentialsException();
  }

  @override
  Future<void> refresh() async => throw const AuthException();

  @override
  Future<void> logout() async {}
}

/// Un [FirstLoginRepository] que anota los pedidos y activa, o falla con
/// [activateError] si se indica.
class RecordingFirstLoginRepository implements FirstLoginRepository {
  RecordingFirstLoginRepository({this.activateError});

  final Exception? activateError;
  final List<({String ci, AccessType access})> requests = [];
  final List<Map<String, Object?>> activations = [];

  @override
  Future<void> requestLink({
    required String ci,
    required AccessType access,
  }) async {
    requests.add((ci: ci, access: access));
  }

  @override
  Future<AccessType> activate({
    required String token,
    required String address,
    required String phone1,
    String? phone2,
    required String password,
  }) async {
    activations.add({
      'token': token,
      'address': address,
      'phone1': phone1,
      'phone2': phone2,
      'password': password,
    });
    if (activateError != null) throw activateError!;
    return AccessType.socio;
  }
}

/// Monta la app completa (router real, sesión real) con repositories falsos
/// sin latencia. Con [employeeAccess] en `false` simula Android.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  bool employeeAccess = true,
  AuthRepository? auth,
  FirstLoginRepository? firstLogin,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
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
        (ref) async =>
            firstLogin ?? FakeFirstLoginRepository(latency: Duration.zero),
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

/// Desmonta la app y deja correr lo pendiente. Un test que arma varias apps
/// (una por rol) y termina con una pantalla de `autoDispose` a la vista lo
/// llama al final: al desmontar el árbol Riverpod agenda la liberación de esos
/// providers con un timer, y el test falla si queda uno pendiente.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // La liberación de un provider puede agendar la de otro que dependía de él.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

String locationOf(ProviderContainer container) => container
    .read(goRouterProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<void> goTo(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  container.read(goRouterProvider).go(location);
  await tester.pumpAndSettle();
}
