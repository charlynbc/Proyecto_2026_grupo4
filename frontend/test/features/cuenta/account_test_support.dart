import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/repositories/account_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// El JSON del ejemplo del contrato (fila 46), escrito a mano.
Map<String, dynamic> luciaJson({String? pendingEmail}) => {
  'ci': '45678911',
  'nombre': 'Lucía',
  'apellido': 'Fernández',
  'rol': 'SOCIO',
  'correo': 'lucia@example.org',
  'correoPendiente': pendingEmail,
  'telefono1': '099123456',
  'telefono2': null,
  'direccion': 'Av. 18 de Julio 1234, Montevideo',
};

/// La misma cuenta de Lucía, armada a mano sin pasar por `fromJson`. El rol,
/// el teléfono 2 y el correo pendiente se pueden cambiar para cada test.
Account lucia({
  String? pendingEmail,
  String? phone2,
  UserRole role = UserRole.socio,
}) => Account(
  ci: '45678911',
  name: 'Lucía',
  lastName: 'Fernández',
  role: role,
  email: 'lucia@example.org',
  pendingEmail: pendingEmail,
  phone1: '099123456',
  phone2: phone2,
  address: 'Av. 18 de Julio 1234, Montevideo',
);

/// Un [AccountRepository] escrito a mano: devuelve [account] (Lucía si no se
/// indica) o falla con [error], y cuenta los pedidos. Con [gate] puesto,
/// `get` espera a que se complete.
class RecordingAccountRepository implements AccountRepository {
  RecordingAccountRepository({this.account, this.error});

  Account? account;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Account> get() async {
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return account ?? lucia();
  }
}

/// El texto del [Text] con la key [key].
String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

/// Monta la app completa con datos falsos y sin latencia en el login, como
/// `pumpApp`, que no se edita. El repositorio de la cuenta es el falso real
/// (el que lee el rol de la sesión).
Future<ProviderContainer> pumpAccountApp(
  WidgetTester tester, {
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

/// Inicia sesión con la persona de prueba de [role].
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

/// El router de la app completa montada con [pumpAccountApp].
GoRouter appRouter(ProviderContainer container) =>
    container.read(goRouterProvider);

/// La ubicación actual del router.
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// La pantalla de arriba de la pila. Un `push` no cambia la uri del router
/// (go_router no la refleja por defecto), pero sí apila la ruta: su
/// `matchedLocation` es la que se ve.
String topOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;
