import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/email_change_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/email_change_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_email_change_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un [EmailChangeRepository] que anota los tokens confirmados. Falla con
/// [error] si se indica; con [gate] puesto, `confirm` espera a que se
/// complete.
class RecordingEmailChangeRepository implements EmailChangeRepository {
  RecordingEmailChangeRepository({this.error});

  Exception? error;
  Completer<void>? gate;
  final List<String> tokens = [];

  @override
  Future<void> confirm({required String token}) async {
    tokens.add(token);
    await gate?.future;
    if (error != null) throw error!;
  }
}

/// Monta la app completa como `pumpApp`, con el repositorio de cambio de
/// correo [emailChange] (o el falso sin latencia). `pumpApp` no lo acepta y
/// no se edita, por eso este helper vive acá.
Future<ProviderContainer> pumpEmailChangeApp(
  WidgetTester tester, {
  EmailChangeRepository? emailChange,
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      employeeAccessAvailableProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWith(
        (ref) async => FakeAuthRepository(
          ref.read(sessionProvider.notifier),
          latency: Duration.zero,
        ),
      ),
      firstLoginRepositoryProvider.overrideWith(
        (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
      ),
      emailChangeRepositoryProvider.overrideWith(
        (ref) async =>
            emailChange ?? FakeEmailChangeRepository(latency: Duration.zero),
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

/// Inicia sesión con la persona de prueba de [role], con el repositorio de
/// login falso.
Future<void> loginAs(
  WidgetTester tester,
  ProviderContainer container,
  UserRole role,
) async {
  final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
  final repo = await container.read(authRepositoryProvider.future);
  final done = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(role),
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}
