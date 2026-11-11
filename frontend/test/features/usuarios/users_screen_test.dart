import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/new_user.dart';
import 'package:agenda_medica/features/usuarios/providers/create_user_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/new_user_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:agenda_medica/features/usuarios/screens/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

/// Ancho de pantalla de los tests de la tabla: sobra para que entre.
const Size _wideScreen = Size(1300, 1800);

Future<GoRouter> _pump(WidgetTester tester, {Size size = _wideScreen}) {
  final db = FakeAdminDatabase();
  return pumpAdminScreens(
    tester,
    size: size,
    initialLocation: kUsersPath,
    routes: [
      GoRoute(path: kUsersPath, builder: (_, _) => const UsersScreen()),
      GoRoute(path: kNewUserPath, builder: (_, _) => const NewUserScreen()),
    ],
    overrides: [
      userRepositoryProvider.overrideWith(
        (ref) async => FakeUserRepository(db, latency: Duration.zero),
      ),
    ],
  );
}

/// Las filas de la tabla como "Apellido, nombre" (segunda columna).
List<String> _names(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    (row.cells[1].child as Text).data!,
];

Finder get _search => find.widgetWithText(FilledButton, 'Buscar');

Future<void> _choose(
  WidgetTester tester,
  Finder dropdown,
  String option,
) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder get _roleFilter => find.byType(DropdownButtonFormField<UserRole?>);
Finder get _statusFilter => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField &&
      w.runtimeType.toString().contains('AccountStatus'),
);
Finder get _orderFilter => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField &&
      w.runtimeType.toString().contains('UserOrder'),
);

/// Cuánto se puede desplazar la tabla hacia los costados: 0 si entra entera.
double _tableOverflow(WidgetTester tester) {
  final horizontal = find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
  );
  final scrollable = find.descendant(
    of: horizontal,
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
}

void main() {
  // Los anchos se miden con la tipografía real, no con Ahem.
  setUpAll(loadRoboto);

  testWidgets('muestra las columnas de RF-35 y la primera página', (
    tester,
  ) async {
    await _pump(tester);

    for (final header in [
      'CI',
      'Apellido y nombre',
      'Rol',
      'Correo',
      'Estado',
      'Activada',
      'Alta',
    ]) {
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text(header),
        ),
        findsOneWidget,
      );
    }
    final names = _names(tester);
    expect(names, hasLength(20));
    expect(names.first, 'Acosta, Florencia');
    expect(find.text('Página 1 de 2 · 25 cuentas'), findsOneWidget);
  });

  testWidgets('la paginación pide la página siguiente al servidor', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(_names(tester), hasLength(5));
    expect(find.text('Página 2 de 2 · 25 cuentas'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Siguiente'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(_names(tester), hasLength(20));
  });

  testWidgets('filtra por rol', (tester) async {
    await _pump(tester);

    await _choose(tester, _roleFilter, 'Médico');
    // Todavía no se aplicó: hace falta "Buscar".
    expect(_names(tester), hasLength(20));
    await tester.tap(_search);
    await tester.pumpAndSettle();

    expect(_names(tester), hasLength(4));
    expect(find.text('Página 1 de 1 · 4 cuentas'), findsOneWidget);
  });

  testWidgets('filtra por estado y combina con el rol', (tester) async {
    await _pump(tester);

    await _choose(tester, _statusFilter, 'Inactivo');
    await tester.tap(_search);
    await tester.pumpAndSettle();
    expect(_names(tester), hasLength(4));

    await _choose(tester, _roleFilter, 'Socio');
    await tester.tap(_search);
    await tester.pumpAndSettle();
    expect(_names(tester), hasLength(3));
  });

  testWidgets('busca por apellido sin importar mayúsculas ni tildes', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'CI o apellido'),
      'MENDEZ',
    );
    await tester.tap(_search);
    await tester.pumpAndSettle();

    expect(_names(tester), ['Méndez, Carla']);
    expect(find.text('Página 1 de 1 · 1 cuenta'), findsOneWidget);
  });

  testWidgets('busca por CI al apretar Enter', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'CI o apellido'),
      '45678905',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(_names(tester), ['Fernández, Diego']);
  });

  testWidgets('sin coincidencias avisa que no hay resultados', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'CI o apellido'),
      'zzz',
    );
    await tester.tap(_search);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se encontraron usuarios con esos filtros. Cambiá los criterios y '
        'volvé a buscar.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('ordena por fecha de alta y cambia el sentido', (tester) async {
    await _pump(tester);

    await _choose(tester, _orderFilter, 'Fecha de alta');
    expect(_names(tester).first, 'Pereira, Bruno'); // la más antigua

    await tester.tap(find.text('Ascendente'));
    await tester.pumpAndSettle();
    expect(find.text('Descendente'), findsOneWidget);
    expect(_names(tester).first, 'González, Lucía'); // la más reciente
  });

  testWidgets('en pantallas angostas cada cuenta es una tarjeta', (
    tester,
  ) async {
    await _pump(tester);

    tester.view.physicalSize = const Size(400, 1800);
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Acosta, Florencia'), findsOneWidget);
    expect(find.textContaining('Activada: No'), findsWidgets);
  });

  testWidgets('"Alta de usuario" lleva al formulario', (tester) async {
    final router = await _pump(tester);

    await tester.tap(find.text('Alta de usuario'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), kNewUserPath);
  });

  testWidgets('un alta nueva se refleja en el listado', (tester) async {
    await _pump(tester);
    expect(find.text('Página 1 de 2 · 25 cuentas'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsersScreen)),
    );
    final submitted = container
        .read(createUserControllerProvider.notifier)
        .submit(
          NewUser(
            ci: '31415921',
            firstName: 'Marta',
            lastName: 'Zabala',
            birthDate: DateTime(1978, 3, 15),
            email: 'marta@example.org',
            phone1: '099111222',
            role: UserRole.funcionario,
          ),
        );
    await tester.pumpAndSettle();
    await submitted;

    expect(find.text('Página 1 de 2 · 26 cuentas'), findsOneWidget);
  });

  group('según el ancho de la pantalla', () {
    const columns = [
      'CI',
      'Apellido y nombre',
      'Rol',
      'Correo',
      'Estado',
      'Activada',
      'Alta',
    ];

    for (final width in [500.0, 800.0]) {
      testWidgets('con $width px la tabla no entra y se usan tarjetas', (
        tester,
      ) async {
        await _pump(tester, size: Size(width, 1800));

        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(Card), findsNWidgets(20));
        expect(find.text('Acosta, Florencia'), findsOneWidget);
      });
    }

    for (final width in [1100.0, 1300.0]) {
      testWidgets('con $width px entra la tabla completa, sin desplazarla', (
        tester,
      ) async {
        await _pump(tester, size: Size(width, 1800));

        expect(find.byType(Card), findsNothing);
        for (final column in columns) {
          final header = find.descendant(
            of: find.byType(DataTable),
            matching: find.text(column),
          );
          expect(header, findsOneWidget, reason: column);
          expect(
            tester.getTopRight(header).dx,
            lessThanOrEqualTo(width),
            reason: 'la columna $column se sale de la pantalla',
          );
        }
        expect(_tableOverflow(tester), 0);
      });
    }
  });
}
