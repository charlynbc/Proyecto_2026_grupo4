import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/core/widgets/ui_date_field.dart';
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

/// Un repository que guarda lo que se le manda para dar de alta.
class _CapturingUserRepository implements UserRepository {
  final List<NewUser> created = [];

  @override
  Future<void> createUser(NewUser user) async => created.add(user);

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
        find.text('Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.'),
        findsNothing,
      );
    });

    testWidgets('la fecha tiene que existir y no ser futura', (tester) async {
      await _pump(tester);
      const fieldLabel = 'Fecha de nacimiento (dd/mm/aaaa)';

      await _enter(tester, fieldLabel, '1978-03-15');
      await _submit(tester);
      expect(
        find.text('Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.'),
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

  group('fecha de nacimiento como la cédula', () {
    const dateLabel = 'Fecha de nacimiento (dd/mm/aaaa)';
    const formatError =
        'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';
    const missingError =
        'Esa fecha no existe en el calendario. Revisá el día y el mes.';

    Future<void> focusAndType(WidgetTester tester, String text) async {
      await tester.ensureVisible(_field(dateLabel));
      await tester.tap(_field(dateLabel));
      await tester.pump();
      await tester.enterText(_field(dateLabel), text);
      await tester.pump();
    }

    /// Sale del campo de la fecha pasando al del nombre.
    Future<void> leaveDate(WidgetTester tester) async {
      await tester.ensureVisible(_field('Nombre'));
      await tester.tap(_field('Nombre'));
      await tester.pump();
    }

    void expectNoDateError() {
      expect(find.text(formatError), findsNothing);
      expect(find.text(missingError), findsNothing);
      expect(find.textContaining('no puede ser futura'), findsNothing);
      expect(find.textContaining('Revisá el año'), findsNothing);
      expect(find.text('Ingresá la fecha de nacimiento.'), findsNothing);
    }

    String dateText(WidgetTester tester) =>
        tester.widget<TextFormField>(_field(dateLabel)).controller!.text;

    testWidgets('con foco y menos de 10 caracteres no marca error', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, '15/03/19');

      expectNoDateError();
    });

    testWidgets('con 10 caracteres valida ya, sin enviar', (tester) async {
      await _pump(tester);

      await focusAndType(tester, '31/02/1990');
      expect(find.text(missingError), findsOneWidget);
      expect(find.text(formatError), findsNothing);

      await focusAndType(tester, '01/01/${DateTime.now().year + 1}');
      expect(
        find.text('La fecha de nacimiento no puede ser futura.'),
        findsOneWidget,
      );

      await focusAndType(tester, '15/03/1850');
      expect(find.text('Revisá el año de nacimiento.'), findsOneWidget);

      await focusAndType(tester, '15/03/1978');
      expectNoDateError();
    });

    testWidgets('al salir con la fecha incompleta avisa del formato', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, '15/03');
      expectNoDateError();
      await leaveDate(tester);

      expect(find.text(formatError), findsOneWidget);
    });

    testWidgets('un campo borrado por completo no marca error al salir', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, '15/03');
      await focusAndType(tester, '');
      await leaveDate(tester);

      expectNoDateError();
    });

    testWidgets('vacía se reclama al enviar y el aviso queda visible', (
      tester,
    ) async {
      await _pump(tester);

      // La toca y se va sin escribir: todavía no es un error.
      await focusAndType(tester, '');
      await leaveDate(tester);
      expectNoDateError();

      await _submit(tester);
      expect(find.text('Ingresá la fecha de nacimiento.'), findsOneWidget);

      // Seguir moviéndose por el formulario no lo borra.
      await tester.tap(_field('Apellido'));
      await tester.pump();
      expect(find.text('Ingresá la fecha de nacimiento.'), findsOneWidget);
    });

    testWidgets('solo acepta dígitos y barras, hasta 10 caracteres', (
      tester,
    ) async {
      await _pump(tester);

      await focusAndType(tester, 'ab12/x3');
      expect(dateText(tester), '12/3');

      await focusAndType(tester, '15/03/19781');
      expect(dateText(tester), '15/03/1978');
    });
  });

  group('fecha de nacimiento con el campo compartido', () {
    const dateLabel = 'Fecha de nacimiento (dd/mm/aaaa)';
    const futureError = 'La fecha de nacimiento no puede ser futura.';
    const yearError = 'Revisá el año de nacimiento.';
    final dateField = find.byType(UiDateField);
    final cross = find.descendant(
      of: dateField,
      matching: find.byIcon(Icons.close),
    );

    testWidgets('es el campo compartido, con etiqueta y calendario', (
      tester,
    ) async {
      await _pump(tester);

      expect(dateField, findsOneWidget);
      expect(_field(dateLabel), findsOneWidget);
      expect(
        find.descendant(
          of: dateField,
          matching: find.byIcon(Icons.calendar_today_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Elegir fecha de nacimiento'), findsOneWidget);
      // Vacío: todavía no hay nada que borrar.
      expect(cross, findsNothing);
    });

    testWidgets('la cruz borra la fecha', (tester) async {
      await _pump(tester);
      await _enter(tester, dateLabel, '15/03/1978');
      await tester.pump();

      expect(cross, findsOneWidget);
      await tester.ensureVisible(cross);
      await tester.tap(cross);
      await tester.pump();

      expect(
        tester.widget<TextFormField>(_field(dateLabel)).controller!.text,
        isEmpty,
      );
      expect(cross, findsNothing);
    });

    testWidgets('una fecha válida se acepta y se envía como yyyy-MM-dd', (
      tester,
    ) async {
      final repository = _CapturingUserRepository();
      await _pump(tester, repository: repository);
      await _fill(tester, birthDate: '15/03/1978');
      await _chooseRole(tester, 'Funcionario');

      await _submit(tester);

      expect(repository.created, hasLength(1));
      expect(repository.created.single.birthDate, DateTime.utc(1978, 3, 15));
      expect(
        repository.created.single.toJson()['fechaNacimiento'],
        '1978-03-15',
      );
    });

    testWidgets('hoy se acepta y mañana es futura', (tester) async {
      await _pump(tester);
      final today = UruguayTime.today();

      await _enter(tester, dateLabel, _formatDate(today));
      await _submit(tester);
      expect(find.text(futureError), findsNothing);

      await _enter(
        tester,
        dateLabel,
        _formatDate(today.add(const Duration(days: 1))),
      );
      await _submit(tester);
      expect(find.text(futureError), findsOneWidget);
    });

    testWidgets('1900 se acepta y antes de 1900 se rechaza', (tester) async {
      await _pump(tester);

      await _enter(tester, dateLabel, '01/01/1900');
      await _submit(tester);
      expect(find.text(yearError), findsNothing);

      await _enter(tester, dateLabel, '31/12/1899');
      await _submit(tester);
      expect(find.text(yearError), findsOneWidget);
    });

    testWidgets('un formato inválido da el mensaje del campo compartido', (
      tester,
    ) async {
      await _pump(tester);

      await _enter(tester, dateLabel, '15/03');
      await _submit(tester);

      expect(
        find.text('Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.'),
        findsOneWidget,
      );
    });

    testWidgets('vacío se reclama al enviar', (tester) async {
      await _pump(tester);

      await _submit(tester);

      expect(find.text('Ingresá la fecha de nacimiento.'), findsOneWidget);
    });

    testWidgets('el calendario no pasa de hoy', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.tap(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.pumpAndSettle();

      final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
    });

    testWidgets('el calendario no baja de 1900', (tester) async {
      await _pump(tester);
      await _enter(tester, dateLabel, '01/01/1900');

      await tester.ensureVisible(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.tap(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.pumpAndSettle();

      final previous = find.widgetWithIcon(IconButton, Icons.chevron_left);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
    });

    testWidgets('a 320 px de ancho no desborda, con cruz y con error', (
      tester,
    ) async {
      await _pump(tester);
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      await _enter(tester, dateLabel, '01/01/${DateTime.now().year + 1}');
      await _submit(tester);

      expect(find.text(futureError), findsOneWidget);
      expect(cross, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('teléfono', () {
    const phoneError =
        'Ese teléfono no parece válido. Revisá el número; si es de otro país, '
        'empezalo con + y el código de país.';

    String text(WidgetTester tester, String label) =>
        tester.widget<TextFormField>(_field(label)).controller!.text;

    Future<_Harness> registerWith(
      WidgetTester tester, {
      String phone1 = '099111222',
      String? phone2,
    }) async {
      final h = await _pump(tester);
      await _fill(tester, phone1: phone1);
      if (phone2 != null) await _enter(tester, 'Teléfono 2 (opcional)', phone2);
      await _chooseRole(tester, 'Funcionario');
      await _submit(tester);
      return h;
    }

    for (final label in ['Teléfono 1', 'Teléfono 2 (opcional)']) {
      testWidgets('$label no acepta letras al escribir', (tester) async {
        await _pump(tester);

        await _enter(tester, label, 'abc123');

        expect(text(tester, label), '123');
      });

      testWidgets('$label conserva +, espacios, guiones y paréntesis', (
        tester,
      ) async {
        await _pump(tester);

        await _enter(tester, label, '+598 99 123 456');
        expect(text(tester, label), '+598 99 123 456');

        await _enter(tester, label, '(02) 123-4567');
        expect(text(tester, label), '(02) 123-4567');
      });
    }

    testWidgets('con 7 dígitos se rechaza al enviar', (tester) async {
      final h = await registerWith(tester, phone1: '1234567');

      expect(find.text(phoneError), findsOneWidget);
      expect(currentLocation(h.router), kNewUserPath);
    });

    testWidgets('un celular uruguayo válido se acepta', (tester) async {
      final h = await registerWith(tester, phone1: '099 123 456');

      expect(find.text(phoneError), findsNothing);
      expect(currentLocation(h.router), kUsersPath);
    });

    testWidgets('cuenta solo los dígitos, no los símbolos', (tester) async {
      final h = await registerWith(tester, phone1: '+598 99 123 456');

      expect(find.text(phoneError), findsNothing);
      expect(currentLocation(h.router), kUsersPath);
    });

    testWidgets('con 16 dígitos se rechaza', (tester) async {
      final h = await registerWith(tester, phone1: '1234567890123456');

      expect(find.text(phoneError), findsOneWidget);
      expect(currentLocation(h.router), kNewUserPath);
    });

    testWidgets('el teléfono 2 vacío sigue valiendo', (tester) async {
      final h = await registerWith(tester);

      expect(find.text(phoneError), findsNothing);
      expect(currentLocation(h.router), kUsersPath);
    });

    testWidgets('el teléfono 2 con pocos dígitos se rechaza', (tester) async {
      final h = await registerWith(tester, phone2: '1234567');

      expect(find.text(phoneError), findsOneWidget);
      expect(currentLocation(h.router), kNewUserPath);
    });

    testWidgets('el teléfono 1 sigue siendo obligatorio', (tester) async {
      final h = await registerWith(tester, phone1: '');

      expect(find.text('Ingresá un teléfono.'), findsOneWidget);
      expect(find.text(phoneError), findsNothing);
      expect(currentLocation(h.router), kNewUserPath);
    });
  });

  group('teléfono mientras se escribe', () {
    const phoneError =
        'Ese teléfono no parece válido. Revisá el número; si es de otro país, '
        'empezalo con + y el código de país.';
    const requiredError = 'Ingresá un teléfono.';
    const phone1 = 'Teléfono 1';
    const phone2 = 'Teléfono 2 (opcional)';

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

    /// Sale del campo pasando al del nombre.
    Future<void> leaveField(WidgetTester tester) async {
      await tester.ensureVisible(_field('Nombre'));
      await tester.tap(_field('Nombre'));
      await tester.pump();
    }

    void expectNoPhoneError() {
      expect(find.text(phoneError), findsNothing);
      expect(find.text(requiredError), findsNothing);
    }

    for (final label in [phone1, phone2]) {
      group(label, () {
        testWidgets('con foco y 7 dígitos no marca error', (tester) async {
          await _pump(tester);

          await focusAndType(tester, label, '1234567');

          expectNoPhoneError();
        });

        testWidgets(
          'cuenta dígitos, no caracteres: "(02) 123" no marca error',
          (tester) async {
            await _pump(tester);

            await focusAndType(tester, label, '(02) 123');

            expectNoPhoneError();
          },
        );

        testWidgets('un número válido no marca error', (tester) async {
          await _pump(tester);

          await focusAndType(tester, label, '099 123 456');
          expectNoPhoneError();

          await focusAndType(tester, label, '(02) 123-4567');
          expectNoPhoneError();
        });

        testWidgets('con 16 dígitos marca el error ya, sin enviar', (
          tester,
        ) async {
          await _pump(tester);

          await focusAndType(tester, label, '1234567890123456');

          expect(find.text(phoneError), findsOneWidget);
          // No hay tope que bloquee la escritura.
          expect(
            tester.widget<TextFormField>(_field(label)).controller!.text,
            '1234567890123456',
          );
        });

        testWidgets('al salir con menos de 8 dígitos marca el error', (
          tester,
        ) async {
          await _pump(tester);

          await focusAndType(tester, label, '123');
          expectNoPhoneError();
          await leaveField(tester);

          expect(find.text(phoneError), findsOneWidget);
        });

        testWidgets('un campo borrado por completo no marca error al salir', (
          tester,
        ) async {
          await _pump(tester);

          await focusAndType(tester, label, '123');
          await focusAndType(tester, label, '');
          await leaveField(tester);

          expectNoPhoneError();
        });
      });
    }

    testWidgets('teléfono 1 vacío solo se reclama al enviar y queda visible', (
      tester,
    ) async {
      await _pump(tester);

      // Lo toca y se va sin escribir: todavía no es un error.
      await focusAndType(tester, phone1, '');
      await leaveField(tester);
      expectNoPhoneError();

      await _submit(tester);
      expect(find.text(requiredError), findsOneWidget);
      expect(find.text(phoneError), findsNothing);

      // Seguir moviéndose por el formulario no lo borra.
      await tester.tap(_field('Apellido'));
      await tester.pump();
      expect(find.text(requiredError), findsOneWidget);
    });

    testWidgets('teléfono 2 vacío nunca da error', (tester) async {
      await _pump(tester);

      await focusAndType(tester, phone2, '');
      await leaveField(tester);
      expectNoPhoneError();

      await _submit(tester);
      // El único reclamo es el del teléfono 1 (obligatorio).
      expect(find.text(requiredError), findsOneWidget);
      expect(find.text(phoneError), findsNothing);

      await tester.tap(_field('Apellido'));
      await tester.pump();
      expect(find.text(requiredError), findsOneWidget);
      expect(find.text(phoneError), findsNothing);
    });
  });

  group('mensajes de error largos', () {
    // Sin errorMaxLines el mensaje se corta con "…" en una sola línea.
    Future<void> expectErrorNotCut(
      WidgetTester tester, {
      required String label,
      required String input,
      required String message,
    }) async {
      await _pump(tester);

      await _enter(tester, label, input);
      await _submit(tester);

      final error = tester.widget<Text>(find.text(message));
      expect(error.maxLines, greaterThanOrEqualTo(2));
    }

    testWidgets('el del teléfono 1 no se corta', (tester) async {
      await expectErrorNotCut(
        tester,
        label: 'Teléfono 1',
        input: '12345678',
        message:
            'Ese teléfono no parece válido. Revisá el número; si es de otro '
            'país, empezalo con + y el código de país.',
      );
    });

    testWidgets('el del teléfono 2 no se corta', (tester) async {
      await expectErrorNotCut(
        tester,
        label: 'Teléfono 2 (opcional)',
        input: '12345678',
        message:
            'Ese teléfono no parece válido. Revisá el número; si es de otro '
            'país, empezalo con + y el código de país.',
      );
    });

    testWidgets('el de la fecha mal escrita no se corta', (tester) async {
      await expectErrorNotCut(
        tester,
        label: 'Fecha de nacimiento (dd/mm/aaaa)',
        input: '15/03',
        message: 'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.',
      );
    });

    testWidgets('el de la fecha inexistente no se corta', (tester) async {
      await expectErrorNotCut(
        tester,
        label: 'Fecha de nacimiento (dd/mm/aaaa)',
        input: '29/02/2021',
        message:
            'Esa fecha no existe en el calendario. Revisá el día y el mes.',
      );
    });

    testWidgets('el del correo no se corta', (tester) async {
      await expectErrorNotCut(
        tester,
        label: 'Correo electrónico',
        input: 'marta.example.org',
        message: 'Ingresá un correo válido, por ejemplo nombre@ejemplo.org.',
      );
    });
  });
}
