import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/usuarios/models/account_detail.dart';
import 'package:agenda_medica/features/usuarios/providers/user_correction_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/edit_user_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

// Las cuentas sembradas, por id: 1 Ana (socio, activada), 2 Bruno (funcionario,
// teléfono 2 cargado), 4 Carla (médico, especialidad Medicina General),
// 7 Florencia (médico, sin completar el primer ingreso, especialidades
// Medicina General y Dermatología).

class _Recording implements UserCorrectionRepository {
  _Recording(FakeAdminDatabase db)
    : _delegate = FakeUserCorrectionRepository(db, latency: Duration.zero);

  final UserCorrectionRepository _delegate;
  final corrected = <(int, Map<String, Object?>)>[];
  Completer<void>? fetchGate;
  Completer<void>? correctGate;
  UserCorrectionException? error;

  @override
  Future<AccountDetail> fetch(int id) async {
    await fetchGate?.future;
    return _delegate.fetch(id);
  }

  @override
  Future<AccountDetail> correct(int id, AccountCorrection changes) async {
    corrected.add((id, changes.toJson()));
    await correctGate?.future;
    if (error != null) throw error!;
    return _delegate.correct(id, changes);
  }
}

class _Harness {
  _Harness(this.db, this.repository, this.router);

  final FakeAdminDatabase db;
  final _Recording repository;
  final GoRouter router;
}

Future<_Harness> _pump(
  WidgetTester tester,
  int id, {
  Size size = const Size(900, 2400),
  _Recording? repository,
}) async {
  final db = FakeAdminDatabase();
  final repo = repository ?? _Recording(db);
  final router = await pumpAdminScreens(
    tester,
    initialLocation: userEditPath(id),
    size: size,
    routes: [
      GoRoute(
        path: kUsersPath,
        builder: (_, _) => const Scaffold(body: Text('Listado de usuarios')),
      ),
      GoRoute(
        path: '$kUsersPath/:id/corregir',
        builder: (_, state) =>
            EditUserScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
    overrides: [
      userCorrectionRepositoryProvider.overrideWith((ref) async => repo),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(db, latency: Duration.zero),
      ),
    ],
  );
  return _Harness(db, repo, router);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);
final _save = find.byKey(const Key('edit-user-save'));

String _value(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_field(label)).controller!.text;

/// El texto del `Text` que tiene la [key] dada.
String? _keyedText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed != null;

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

Finder _specialty(String name) => find.widgetWithText(CheckboxListTile, name);

Future<void> _toggle(WidgetTester tester, String name) async {
  await tester.ensureVisible(_specialty(name));
  await tester.tap(_specialty(name));
  await tester.pump();
}

bool _checked(WidgetTester tester, String name) =>
    tester.widget<CheckboxListTile>(_specialty(name)).value ?? false;

/// Una cédula libre y válida; el dígito verificador es un dato de entrada.
String _freeCi() {
  const body = '3644426';
  return '$body${calculateUruguayanCiVerifierDigit(body)}';
}

void main() {
  setUpAll(loadRoboto);

  group('precarga', () {
    testWidgets('Carla llega con sus datos y el rol como texto fijo', (
      tester,
    ) async {
      await _pump(tester, 4);

      expect(_value(tester, 'Cédula de identidad'), '34567894');
      expect(_value(tester, 'Nombre'), 'Carla');
      expect(_value(tester, 'Apellido'), 'Méndez');
      expect(_value(tester, 'Fecha de nacimiento (dd/mm/aaaa)'), '11/11/1978');
      expect(_value(tester, 'Correo electrónico'), 'carla.mendez@example.org');
      expect(_value(tester, 'Teléfono 1'), '094555777');
      expect(_value(tester, 'Teléfono 2 (opcional)'), '');
      expect(_value(tester, 'Dirección'), 'Calle Mercedes 870');
      expect(
        find.descendant(
          of: find.byKey(const Key('edit-user-role')),
          matching: find.text('Médico'),
        ),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<UserRole>), findsNothing);
      expect(_checked(tester, 'Medicina General'), isTrue);
      expect(_checked(tester, 'Cardiología'), isFalse);
      expect(_checked(tester, 'Dermatología'), isFalse);
    });

    testWidgets('un socio no tiene especialidades', (tester) async {
      await _pump(tester, 1);

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('Especialidades'), findsNothing);
    });

    testWidgets('Bruno trae su teléfono 2', (tester) async {
      await _pump(tester, 2);

      expect(_value(tester, 'Teléfono 2 (opcional)'), '099555666');
    });

    testWidgets('la dirección es obligatoria solo en una cuenta activada', (
      tester,
    ) async {
      await _pump(tester, 1);
      expect(_field('Dirección'), findsOneWidget);
      expect(_field('Dirección (opcional)'), findsNothing);
    });

    testWidgets('una cuenta sin primer ingreso trae la dirección opcional', (
      tester,
    ) async {
      await _pump(tester, 7);
      expect(_field('Dirección (opcional)'), findsOneWidget);
    });
  });

  group('cuenta que no se puede abrir', () {
    for (final id in [999, 0]) {
      testWidgets('el id $id muestra que no se encontró y vuelve', (
        tester,
      ) async {
        final h = await _pump(tester, id);

        expect(find.text('No encontramos esa cuenta.'), findsOneWidget);
        expect(find.byTooltip('Volver'), findsOneWidget);
        await tester.tap(find.byKey(const Key('edit-user-back')));
        await tester.pumpAndSettle();
        expect(currentLocation(h.router), kUsersPath);
      });
    }

    testWidgets('mientras carga muestra el indicador', (tester) async {
      final db = FakeAdminDatabase();
      final repo = _Recording(db)..fetchGate = Completer<void>();
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userCorrectionRepositoryProvider.overrideWith((ref) async => repo),
            specialtyRepositoryProvider.overrideWith(
              (ref) async =>
                  FakeSpecialtyRepository(db, latency: Duration.zero),
            ),
          ],
          child: const MaterialApp(home: EditUserScreen(id: 4)),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      repo.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_value(tester, 'Nombre'), 'Carla');
    });
  });

  group('guardar', () {
    testWidgets('sin diferencias el botón está deshabilitado', (tester) async {
      await _pump(tester, 4);

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('espacios sobrantes no cuentan como cambio', (tester) async {
      await _pump(tester, 4);

      await _enter(tester, 'Nombre', '  Carla  ');

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('volver al valor original lo deshabilita otra vez', (
      tester,
    ) async {
      await _pump(tester, 4);

      await _enter(tester, 'Nombre', 'Carlita');
      expect(_saveEnabled(tester), isTrue);
      await _enter(tester, 'Nombre', 'Carla');

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('manda solo el campo que cambió, avisa y vuelve al listado', (
      tester,
    ) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Teléfono 1', '091111222');
      await _tapSave(tester);

      expect(h.repository.corrected, hasLength(1));
      expect(h.repository.corrected.single.$1, 4);
      expect(h.repository.corrected.single.$2, {'telefono1': '091111222'});
      expect(find.text('Datos corregidos.'), findsOneWidget);
      expect(currentLocation(h.router), kUsersPath);
      expect(h.db.accounts.firstWhere((a) => a.id == 4).phone1, '091111222');
    });

    testWidgets('el correo viaja en minúsculas', (tester) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Correo electrónico', 'Carla.Nueva@Ejemplo.ORG');
      await _tapSave(tester);

      expect(h.repository.corrected.single.$2, {
        'correo': 'carla.nueva@ejemplo.org',
      });
    });

    testWidgets('el mismo correo con otras mayúsculas no es un cambio', (
      tester,
    ) async {
      await _pump(tester, 4);

      await _enter(tester, 'Correo electrónico', 'CARLA.MENDEZ@example.org');

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('vaciar el teléfono 2 manda null explícito', (tester) async {
      final h = await _pump(tester, 2);

      await _enter(tester, 'Teléfono 2 (opcional)', '');
      await _tapSave(tester);

      final sent = h.repository.corrected.single.$2;
      expect(sent.containsKey('telefono2'), isTrue);
      expect(sent['telefono2'], isNull);
      expect(sent.length, 1);
    });

    testWidgets('agregar el teléfono 2 lo manda como texto', (tester) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Teléfono 2 (opcional)', '099777888');
      await _tapSave(tester);

      expect(h.repository.corrected.single.$2, {'telefono2': '099777888'});
    });

    testWidgets('cambiar la fecha de nacimiento la manda como aaaa-mm-dd', (
      tester,
    ) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Fecha de nacimiento (dd/mm/aaaa)', '12/11/1978');
      await _tapSave(tester);

      expect(h.repository.corrected.single.$2, {
        'fechaNacimiento': '1978-11-12',
      });
    });

    testWidgets('cambiar las especialidades manda el conjunto completo', (
      tester,
    ) async {
      final h = await _pump(tester, 7);

      await _toggle(tester, 'Dermatología');
      await _tapSave(tester);

      expect(h.repository.corrected.single.$2, {
        'especialidadIds': [1],
      });
    });

    testWidgets('un doble toque hace una sola llamada', (tester) async {
      final db = FakeAdminDatabase();
      final repo = _Recording(db)..correctGate = Completer<void>();
      await _pump(tester, 4, repository: repo);

      await _enter(tester, 'Teléfono 1', '091111222');
      await tester.ensureVisible(_save);
      await tester.tap(_save);
      await tester.pump();
      expect(_saveEnabled(tester), isFalse);
      await tester.tap(_save, warnIfMissed: false);
      await tester.pump();
      repo.correctGate!.complete();
      await tester.pumpAndSettle();

      expect(repo.corrected, hasLength(1));
    });

    testWidgets('mientras guarda no se puede editar', (tester) async {
      final db = FakeAdminDatabase();
      final repo = _Recording(db)..correctGate = Completer<void>();
      await _pump(tester, 4, repository: repo);

      await _enter(tester, 'Teléfono 1', '091111222');
      await tester.ensureVisible(_save);
      await tester.tap(_save);
      await tester.pump();

      expect(tester.widget<TextFormField>(_field('Nombre')).enabled, isFalse);
      repo.correctGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('validaciones del cliente', () {
    testWidgets('dirección obligatoria en una cuenta activada', (tester) async {
      final h = await _pump(tester, 1);

      await _enter(tester, 'Dirección', '');
      await _tapSave(tester);

      expect(find.text('Ingresá la dirección.'), findsOneWidget);
      expect(h.repository.corrected, isEmpty);
    });

    testWidgets(
      'en una cuenta sin primer ingreso la dirección se puede vaciar',
      (tester) async {
        final h = await _pump(tester, 7);

        await _enter(tester, 'Dirección (opcional)', '');
        await _tapSave(tester);

        final sent = h.repository.corrected.single.$2;
        expect(sent.containsKey('direccion'), isTrue);
        expect(sent['direccion'], isNull);
        expect(sent.length, 1);
      },
    );

    testWidgets('nombre vacío, correo y teléfono inválidos', (tester) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Nombre', '');
      await _enter(tester, 'Correo electrónico', 'sin-arroba');
      await _enter(tester, 'Teléfono 1', '123');
      await _tapSave(tester);

      expect(find.text('Ingresá el nombre.'), findsOneWidget);
      expect(
        find.text('Ingresá un correo válido, por ejemplo nombre@ejemplo.org.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ese teléfono no parece válido'),
        findsOneWidget,
      );
      expect(h.repository.corrected, isEmpty);
    });

    testWidgets('una fecha futura se rechaza', (tester) async {
      final h = await _pump(tester, 4);

      await _enter(tester, 'Fecha de nacimiento (dd/mm/aaaa)', '01/01/2999');
      await _tapSave(tester);

      expect(
        find.text('La fecha de nacimiento no puede ser futura.'),
        findsOneWidget,
      );
      expect(h.repository.corrected, isEmpty);
    });

    testWidgets('una CI con dígito verificador incorrecto se rechaza', (
      tester,
    ) async {
      final h = await _pump(tester, 1);

      await _enter(tester, 'Cédula de identidad', '12345673');
      await _tapSave(tester);

      expect(find.textContaining('La cédula no es válida'), findsOneWidget);
      expect(h.repository.corrected, isEmpty);
    });

    testWidgets('un médico necesita al menos una especialidad', (tester) async {
      final h = await _pump(tester, 4);

      await _toggle(tester, 'Medicina General');
      await _tapSave(tester);

      expect(
        find.text('Elegí al menos una especialidad para el médico.'),
        findsOneWidget,
      );
      expect(h.repository.corrected, isEmpty);
    });
  });

  group('la CI', () {
    testWidgets('al cambiarla aparece el aviso y al volver se va', (
      tester,
    ) async {
      await _pump(tester, 1);
      final notice = find.text(
        'La CI es un dato de la persona: el cambio vale para todas sus cuentas.',
      );
      expect(notice, findsNothing);

      await _enter(tester, 'Cédula de identidad', _freeCi());
      expect(notice, findsOneWidget);

      await _enter(tester, 'Cédula de identidad', '12345672');
      expect(notice, findsNothing);
    });

    testWidgets('una CI libre se guarda y manda solo la CI', (tester) async {
      final h = await _pump(tester, 1);

      await _enter(tester, 'Cédula de identidad', _freeCi());
      await _tapSave(tester);

      expect(h.repository.corrected.single.$2, {'ci': _freeCi()});
      expect(currentLocation(h.router), kUsersPath);
    });

    testWidgets('la CI de otra persona se informa debajo del campo CI', (
      tester,
    ) async {
      final h = await _pump(tester, 1);

      await _enter(tester, 'Cédula de identidad', '45678905');
      await _tapSave(tester);

      expect(
        _keyedText(tester, 'edit-user-ci-error'),
        'Esa cédula ya pertenece a otra persona.',
      );
      expect(find.byKey(const Key('edit-user-error')), findsNothing);
      expect(currentLocation(h.router), userEditPath(1));
    });

    testWidgets('invalidCi del servidor se informa debajo del campo CI', (
      tester,
    ) async {
      final db = FakeAdminDatabase();
      final repo = _Recording(db)
        ..error = const UserCorrectionException(
          UserCorrectionFailure.invalidCi,
          'El servidor no acepta esa cédula.',
        );
      await _pump(tester, 1, repository: repo);

      await _enter(tester, 'Cédula de identidad', _freeCi());
      await _tapSave(tester);

      expect(
        _keyedText(tester, 'edit-user-ci-error'),
        'El servidor no acepta esa cédula.',
      );
    });

    testWidgets('el error de la CI se va al volver a escribirla', (
      tester,
    ) async {
      await _pump(tester, 1);
      await _enter(tester, 'Cédula de identidad', '45678905');
      await _tapSave(tester);
      expect(find.byKey(const Key('edit-user-ci-error')), findsOneWidget);

      await _enter(tester, 'Cédula de identidad', _freeCi());

      expect(find.byKey(const Key('edit-user-ci-error')), findsNothing);
    });
  });

  group('errores del servidor', () {
    testWidgets('una especialidad en uso se informa debajo de especialidades', (
      tester,
    ) async {
      final h = await _pump(tester, 4);

      await _toggle(tester, 'Medicina General');
      await _toggle(tester, 'Cardiología');
      await _tapSave(tester);

      expect(
        _keyedText(tester, 'edit-user-specialty-error'),
        'No se puede quitar una especialidad con turnos vigentes o consultas '
        'agendadas.',
      );
      expect(find.byKey(const Key('edit-user-error')), findsNothing);
      expect(currentLocation(h.router), userEditPath(4));
    });

    testWidgets('el resto de los errores va arriba del formulario', (
      tester,
    ) async {
      final db = FakeAdminDatabase();
      final repo = _Recording(db)
        ..error = const UserCorrectionException(
          UserCorrectionFailure.validation,
          'Revisá los datos cargados.',
        );
      await _pump(tester, 4, repository: repo);

      await _enter(tester, 'Teléfono 1', '091111222');
      await _tapSave(tester);

      expect(
        _keyedText(tester, 'edit-user-error'),
        'Revisá los datos cargados.',
      );
      expect(find.byKey(const Key('edit-user-ci-error')), findsNothing);
      expect(find.byKey(const Key('edit-user-specialty-error')), findsNothing);
    });
  });

  group('a 320 px con Roboto', () {
    for (final (name, id) in [('médico', 4), ('socio', 1)]) {
      testWidgets('$name sin desbordes y con el botón al alcance', (
        tester,
      ) async {
        await _pump(tester, id, size: const Size(320, 700));

        await tester.ensureVisible(_save);
        await tester.pump();

        expect(_save, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('con el aviso de la CI y un error largo no desborda', (
      tester,
    ) async {
      await _pump(tester, 1, size: const Size(320, 700));

      await _enter(tester, 'Cédula de identidad', '45678905');
      await _tapSave(tester);

      expect(find.byKey(const Key('edit-user-ci-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
