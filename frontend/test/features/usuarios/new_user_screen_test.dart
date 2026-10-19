import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/usuarios/models/new_user.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/models/user_page.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/new_user_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

/// Un repository que rechaza todas las altas con [error].
class _RejectingUserRepository implements UserRepository {
  _RejectingUserRepository(this.error);

  final Exception error;

  @override
  Future<void> createUser(NewUser user) async => throw error;

  @override
  Future<UserPage> listUsers(UserFilters filters) => throw UnimplementedError();
}

class _Harness {
  _Harness(this.db, this.router);

  final FakeAdminDatabase db;
  final GoRouter router;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  UserRepository? repository,
}) async {
  final db = FakeAdminDatabase();
  final router = await pumpAdminScreens(
    tester,
    initialLocation: kNewUserPath,
    routes: [
      GoRoute(
        path: kUsersPath,
        builder: (_, _) => const Scaffold(body: Text('Listado de usuarios')),
      ),
      GoRoute(path: kNewUserPath, builder: (_, _) => const NewUserScreen()),
    ],
    overrides: [
      userRepositoryProvider.overrideWith(
        (ref) async =>
            repository ?? FakeUserRepository(db, latency: Duration.zero),
      ),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(db, latency: Duration.zero),
      ),
    ],
  );
  return _Harness(db, router);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);
Finder get _register => find.widgetWithText(FilledButton, 'Registrar usuario');

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
}

Future<void> _chooseRole(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(DropdownButtonFormField<UserRole>));
  await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String ci = '31415921',
  String firstName = 'Marta',
  String lastName = 'Rodríguez',
  String birthDate = '15/03/1978',
  String email = 'marta@example.org',
  String phone1 = '099111222',
}) async {
  await _enter(tester, 'Cédula de identidad', ci);
  await _enter(tester, 'Nombre', firstName);
  await _enter(tester, 'Apellido', lastName);
  await _enter(tester, 'Fecha de nacimiento (dd/mm/aaaa)', birthDate);
  await _enter(tester, 'Correo electrónico', email);
  await _enter(tester, 'Teléfono 1', phone1);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_register);
  await tester.tap(_register);
  await tester.pumpAndSettle();
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

void main() {
  group('validaciones', () {
    testWidgets('con todo vacío pide los datos obligatorios y no registra', (
      tester,
    ) async {
      final h = await _pump(tester);
      final before = h.db.accounts.length;

      await _submit(tester);

      expect(find.text('Ingresá tu cédula.'), findsOneWidget);
      expect(find.text('Ingresá el nombre.'), findsOneWidget);
      expect(find.text('Ingresá el apellido.'), findsOneWidget);
      expect(find.text('Ingresá la fecha de nacimiento.'), findsOneWidget);
      expect(find.text('Ingresá el correo.'), findsOneWidget);
      expect(find.text('Ingresá un teléfono.'), findsOneWidget);
      expect(find.text('Elegí el rol.'), findsOneWidget);
      expect(h.db.accounts.length, before);
      expect(currentLocation(h.router), kNewUserPath);
    });

    testWidgets('una CI con el dígito verificador malo se rechaza', (
      tester,
    ) async {
      final h = await _pump(tester);
      final before = h.db.accounts.length;

      await _fill(tester, ci: '31415920');
      await _chooseRole(tester, 'Funcionario');
      await _submit(tester);

      expect(
        find.text(
          'La cédula no es válida. Escribila completa, con el dígito '
          'verificador, sin puntos ni guiones.',
        ),
        findsOneWidget,
      );
      expect(h.db.accounts.length, before);
    });

    testWidgets('una CI de largo incorrecto se rechaza al enviar', (
      tester,
    ) async {
      await _pump(tester);

      await _enter(tester, 'Cédula de identidad', '314159');
      await _submit(tester);

      expect(
        find.text(
          'La cédula no es válida. Escribila completa, con el dígito '
          'verificador, sin puntos ni guiones.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('un correo sin forma de correo se rechaza', (tester) async {
      await _pump(tester);

      await _enter(tester, 'Correo electrónico', 'marta.example.org');
      await _submit(tester);

      expect(
        find.text('Ingresá un correo válido, por ejemplo nombre@ejemplo.org.'),
        findsOneWidget,
      );
    });

    testWidgets('una fecha con formato correcto pero inexistente lo dice', (
      tester,
    ) async {
      await _pump(tester);
      const fieldLabel = 'Fecha de nacimiento (dd/mm/aaaa)';

      // 2021 no fue bisiesto.
      await _enter(tester, fieldLabel, '29/02/2021');
      await _submit(tester);

      expect(
        find.text(
          'Esa fecha no existe en el calendario. Revisá el día y el mes.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Escribí la fecha como día/mes/año, por ejemplo 15/03/1978.'),
        findsNothing,
      );
    });

    testWidgets('la fecha tiene que existir y no ser futura', (tester) async {
      await _pump(tester);
      const fieldLabel = 'Fecha de nacimiento (dd/mm/aaaa)';

      await _enter(tester, fieldLabel, '1978-03-15');
      await _submit(tester);
      expect(
        find.text('Escribí la fecha como día/mes/año, por ejemplo 15/03/1978.'),
        findsOneWidget,
      );

      await _enter(tester, fieldLabel, '31/02/1990');
      await _submit(tester);
      expect(
        find.text(
          'Esa fecha no existe en el calendario. Revisá el día y el mes.',
        ),
        findsOneWidget,
      );

      final nextYear = DateTime.now().year + 1;
      await _enter(tester, fieldLabel, '01/01/$nextYear');
      await _submit(tester);
      expect(
        find.text('La fecha de nacimiento no puede ser futura.'),
        findsOneWidget,
      );
    });
  });

  group('cédula como en el login', () {
    const ciLabel = 'Cédula de identidad';
    const ciError =
        'La cédula no es válida. Escribila completa, con el dígito '
        'verificador, sin puntos ni guiones.';

    Future<void> focusAndType(
      WidgetTester tester,
      String label,
      String text,
    ) async {
      await tester.ensureVisible(_field(label));
      await tester.tap(_field(label));
      await tester.pump();
      await tester.enterText(_field(label), text);
      await tester.pump();
    }

    void expectNoCiError() {
      expect(find.textContaining('La cédula no es válida'), findsNothing);
      expect(find.textContaining('Ingresá la cédula'), findsNothing);
      expect(find.textContaining('Ingresá tu cédula'), findsNothing);
    }

    testWidgets('con foco y menos de 8 dígitos no marca error', (tester) async {
      await _pump(tester);

      await focusAndType(tester, ciLabel, '1234567');

      expectNoCiError();
    });

    testWidgets('con 8 dígitos de verificador inválido marca el error largo', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, ciLabel, '31415920');

      expect(find.text(ciError), findsOneWidget);
    });

    testWidgets('al salir con pocos dígitos marca error', (tester) async {
      await _pump(tester);
      await focusAndType(tester, ciLabel, '123');
      expect(find.text(ciError), findsNothing);

      await focusAndType(tester, 'Nombre', 'Marta');
      await tester.pumpAndSettle();

      expect(find.text(ciError), findsOneWidget);
    });

    testWidgets('una cédula borrada por completo no marca error al salir', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, ciLabel, '1234');
      await focusAndType(tester, ciLabel, '');
      await focusAndType(tester, 'Nombre', 'Marta');
      await tester.pumpAndSettle();

      expectNoCiError();
    });

    testWidgets('al enviar con la cédula vacía pide ingresarla, y el aviso '
        'sigue visible si ya se había tocado el campo', (tester) async {
      final h = await _pump(tester);
      final before = h.db.accounts.length;

      await focusAndType(tester, ciLabel, '1234');
      await focusAndType(tester, ciLabel, '');
      await focusAndType(tester, 'Nombre', 'Marta');
      await _submit(tester);

      expect(find.text('Ingresá tu cédula.'), findsOneWidget);
      expect(h.db.accounts.length, before);
    });

    testWidgets('solo admite dígitos y hasta 8', (tester) async {
      await _pump(tester);

      await _enter(tester, ciLabel, '3.141.592-1x9');

      final field = tester.widget<TextField>(
        find.descendant(of: _field(ciLabel), matching: find.byType(TextField)),
      );
      expect(field.controller!.text, '31415921');
    });
  });

  group('especialidades', () {
    testWidgets('solo aparecen con el rol Médico', (tester) async {
      await _pump(tester);
      expect(find.text('Especialidades (elegí una o más)'), findsNothing);

      await _chooseRole(tester, 'Funcionario');
      expect(find.text('Especialidades (elegí una o más)'), findsNothing);

      await _chooseRole(tester, 'Médico');
      expect(find.text('Especialidades (elegí una o más)'), findsOneWidget);
      expect(find.text('Cardiología'), findsOneWidget);
    });

    testWidgets('un Médico sin especialidad no se registra', (tester) async {
      final h = await _pump(tester);
      final before = h.db.accounts.length;

      await _fill(tester);
      await _chooseRole(tester, 'Médico');
      await _submit(tester);

      expect(
        find.text('Elegí al menos una especialidad para el médico.'),
        findsOneWidget,
      );
      expect(h.db.accounts.length, before);
    });

    testWidgets('al cambiar de rol se pierde la selección', (tester) async {
      await _pump(tester);

      await _chooseRole(tester, 'Médico');
      await tester.tap(find.text('Cardiología'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Cardiología'),
            )
            .value,
        isTrue,
      );

      await _chooseRole(tester, 'Socio');
      await _chooseRole(tester, 'Médico');

      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(tile.value, isFalse);
      }
    });
  });

  group('alta', () {
    testWidgets(
      'un médico con especialidades se registra y vuelve al listado',
      (tester) async {
        final h = await _pump(tester);
        final before = h.db.accounts.length;

        await _fill(tester);
        await _chooseRole(tester, 'Médico');
        await tester.tap(find.text('Cardiología'));
        await tester.tap(find.text('Dermatología'));
        await _submit(tester);

        expect(currentLocation(h.router), kUsersPath);
        expect(find.text('Listado de usuarios'), findsOneWidget);
        expect(find.textContaining('Es mi primera vez'), findsOneWidget);
        expect(h.db.accounts.length, before + 1);
        final created = h.db.accounts.last;
        expect(created.ci, '31415921');
        expect(created.role, UserRole.medico);
        expect(created.specialtyIds, [2, 3]);
        expect(created.activated, isFalse);
      },
    );

    testWidgets('la CI se acepta con puntos y guion, y se envía solo con '
        'dígitos', (tester) async {
      final h = await _pump(tester);

      await _fill(tester, ci: '3.141.592-1');
      await _chooseRole(tester, 'Funcionario');
      await _submit(tester);

      expect(currentLocation(h.router), kUsersPath);
      expect(h.db.accounts.last.ci, '31415921');
    });

    testWidgets('una cuenta de socio duplicada muestra el aviso y conserva '
        'lo escrito', (tester) async {
      final h = await _pump(tester);
      final ana = h.db.accounts.first;

      await _fill(
        tester,
        ci: ana.ci,
        firstName: ana.firstName,
        lastName: ana.lastName,
        birthDate: _formatDate(ana.birthDate),
      );
      await _chooseRole(tester, 'Socio');
      await _submit(tester);

      expect(
        find.text('Esa cédula ya tiene una cuenta de socio.'),
        findsOneWidget,
      );
      expect(currentLocation(h.router), kNewUserPath);
      expect(find.text(ana.ci), findsOneWidget);
      expect(find.text('marta@example.org'), findsOneWidget);
    });

    testWidgets('datos que no coinciden con la CI existente se informan', (
      tester,
    ) async {
      final h = await _pump(tester);
      final ana = h.db.accounts.first;

      await _fill(
        tester,
        ci: ana.ci,
        firstName: 'Otra',
        lastName: ana.lastName,
        birthDate: _formatDate(ana.birthDate),
      );
      await _chooseRole(tester, 'Funcionario');
      await _submit(tester);

      expect(
        find.textContaining('otro nombre, apellido o fecha'),
        findsOneWidget,
      );
      expect(currentLocation(h.router), kNewUserPath);
    });

    testWidgets('un empleado habilitado impide otra cuenta de empleado', (
      tester,
    ) async {
      final h = await _pump(tester);
      final bruno = h.db.accounts.firstWhere(
        (a) => a.role == UserRole.funcionario,
      );

      await _fill(
        tester,
        ci: bruno.ci,
        firstName: bruno.firstName,
        lastName: bruno.lastName,
        birthDate: _formatDate(bruno.birthDate),
      );
      await _chooseRole(tester, 'Administrador');
      await _submit(tester);

      expect(
        find.textContaining('cuenta de empleado habilitada o pendiente'),
        findsOneWidget,
      );
    });

    testWidgets('una falla inesperada muestra su mensaje', (tester) async {
      await _pump(
        tester,
        repository: _RejectingUserRepository(
          const ApiException('No pudimos registrar el usuario.'),
        ),
      );

      await _fill(tester);
      await _chooseRole(tester, 'Funcionario');
      await _submit(tester);

      expect(find.text('No pudimos registrar el usuario.'), findsOneWidget);
    });
  });
}
