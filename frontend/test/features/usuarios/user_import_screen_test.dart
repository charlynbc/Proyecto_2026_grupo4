import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_file_picker.dart';
import 'package:agenda_medica/core/files/csv_file_saver.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/usuarios/models/user_import.dart';
import 'package:agenda_medica/features/usuarios/providers/user_import_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_import_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_import_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_import_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/user_import_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:agenda_medica/features/usuarios/screens/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../../helpers/recording_csv_saver.dart';
import '../../helpers/user_import_csv.dart';

class _FakePicker implements CsvFilePicker {
  _FakePicker(this.result);

  PickedCsvFile? result;

  @override
  Future<PickedCsvFile?> pick() async => result;
}

/// Un repositorio que siempre falla con [error].
class _FailingRepository implements UserImportRepository {
  _FailingRepository(this.error);

  final Object error;

  @override
  Future<UserImportPreview> preview(PickedCsvFile file) async => throw error;

  @override
  Future<UserImportResult> confirm(PickedCsvFile file) async => throw error;
}

/// Previsualiza con [inner] pero falla al confirmar con [error].
class _ConfirmFailingRepository implements UserImportRepository {
  _ConfirmFailingRepository(this.inner, this.error);

  final UserImportRepository inner;
  final Object error;

  @override
  Future<UserImportPreview> preview(PickedCsvFile file) => inner.preview(file);

  @override
  Future<UserImportResult> confirm(PickedCsvFile file) async => throw error;
}

/// Un repositorio que espera a que se complete [gate] antes de responder.
class _GatedRepository implements UserImportRepository {
  _GatedRepository(this.gate, this.inner);

  final Completer<void> gate;
  final UserImportRepository inner;

  @override
  Future<UserImportPreview> preview(PickedCsvFile file) async {
    await gate.future;
    return inner.preview(file);
  }

  @override
  Future<UserImportResult> confirm(PickedCsvFile file) async {
    await gate.future;
    return inner.confirm(file);
  }
}

/// Cuenta las llamadas a `confirm` y delega en [inner].
class _CountingRepository implements UserImportRepository {
  _CountingRepository(this.inner);

  final UserImportRepository inner;
  int confirmCalls = 0;

  @override
  Future<UserImportPreview> preview(PickedCsvFile file) => inner.preview(file);

  @override
  Future<UserImportResult> confirm(PickedCsvFile file) {
    confirmCalls++;
    return inner.confirm(file);
  }
}

typedef _Env = ({
  GoRouter router,
  FakeAdminDatabase db,
  _FakePicker picker,
  RecordingCsvSaver saver,
});

Future<_Env> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
  String initialLocation = kImportUsersPath,
  PickedCsvFile? file,
  RecordingCsvSaver? saver,
  UserImportRepository Function(FakeAdminDatabase db)? repository,
}) async {
  final db = FakeAdminDatabase();
  final picker = _FakePicker(file ?? userImportFile());
  final recording = saver ?? RecordingCsvSaver();
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: kUsersPath, builder: (_, _) => const UsersScreen()),
      GoRoute(
        path: kImportUsersPath,
        builder: (_, _) => const UserImportScreen(),
      ),
    ],
    overrides: [
      csvFilePickerProvider.overrideWithValue(picker),
      csvFileSaverProvider.overrideWithValue(recording),
      userRepositoryProvider.overrideWith(
        (ref) async => FakeUserRepository(db, latency: Duration.zero),
      ),
      userImportRepositoryProvider.overrideWith(
        (ref) async =>
            repository?.call(db) ??
            FakeUserImportRepository(db, latency: Duration.zero),
      ),
    ],
  );
  return (router: router, db: db, picker: picker, saver: recording);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester) => _tap(tester, 'csv-pick-button');

Future<void> _preview(WidgetTester tester) async {
  await _pick(tester);
  await _tap(tester, 'import-preview-button');
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

const _previewTitles = {
  4: 'Fila 4: CI 30000033, Sara Lima, SOCIO',
  5: 'Fila 5: CI 12345672, Ana Rodríguez, SOCIO',
  7: 'Fila 7: CI 23456783, Bruno Pereira, FUNCIONARIO',
  8: 'Fila 8: CI 34567894, Carla Gomez, MEDICO',
  9: 'Fila 9: CI 30000048, Luis Perez, MEDICO',
  10: 'Fila 10: CI 30000054, Rita Mora, SOCIO',
  11: 'Fila 11: CI 30000010, Julia Ferrari, SOCIO',
  12: 'Fila 12: CI 30000060, Pablo Rios, SOCIO',
};

const _previewErrors = {
  4: 'La CI no es valida',
  5: 'La CI ya tiene una cuenta de socio',
  7: 'La CI ya tiene una cuenta de empleado habilitada',
  8: 'La CI ya esta registrada con otros datos personales',
  9: 'Especialidad desconocida: Oncología',
  10: 'El correo no tiene un formato valido',
  11: 'Fila repetida (misma CI y rol). Primera aparición válida en fila 2',
  12: 'fecha_nacimiento debe tener formato aaaa-mm-dd',
};

const _confirmErrors = {
  4: 'La CI no es valida',
  5: 'Esa cédula ya tiene una cuenta de socio.',
  7:
      'Esa cédula ya tiene una cuenta de empleado habilitada o pendiente de '
      'activar. Para darle otro rol, inactivá primero la cuenta anterior.',
  8:
      'Esa cédula ya está registrada con otro nombre, apellido o fecha de '
      'nacimiento. Corregí primero esos datos del padrón y volvé a '
      'intentar.',
  9: 'Especialidad desconocida: Oncología',
  10: 'El correo no tiene un formato valido',
  11: 'Fila repetida (misma CI y rol). Primera aparición válida en fila 2',
  12: 'fecha_nacimiento debe tener formato aaaa-mm-dd',
};

/// Un archivo en el que ninguna fila sirve.
final _allInvalid = csvFile(
  '$kUserImportHeader\n'
  '30000033,Sara,Lima,1991-04-04,sara.lima@example.org,099121212,,,SOCIO,\n',
);

void main() {
  testWidgets('sin archivo muestra las instrucciones y no deja previsualizar', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Cargar usuarios desde CSV'), findsOneWidget);
    final instructions = _text(tester, 'import-instructions');
    expect(
      instructions,
      contains(
        'ci, nombre, apellido, fecha_nacimiento, correo, telefono_1, '
        'telefono_2, direccion, rol, especialidades',
      ),
    );
    expect(
      instructions,
      contains('separador coma o punto y coma, UTF-8, hasta 1 MB y 1000 filas'),
    );
    expect(_enabled(tester, 'import-preview-button'), isFalse);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
  });

  testWidgets('con un archivo elegido se puede previsualizar', (tester) async {
    await _pump(tester);

    await _pick(tester);

    expect(find.text('usuarios-prueba.csv'), findsOneWidget);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('previsualizar muestra los totales y las 8 filas con error', (
    tester,
  ) async {
    final env = await _pump(tester);
    final before = env.db.accounts.length;

    await _preview(tester);

    expect(_text(tester, 'import-total'), 'Total: 11');
    expect(_text(tester, 'import-valid'), 'Válidas: 3');
    expect(_text(tester, 'import-invalid'), 'Con error: 8');
    for (final entry in _previewTitles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _previewErrors[entry.key],
      );
    }
    for (final valid in [2, 3, 6]) {
      expect(find.textContaining('Fila $valid:'), findsNothing);
      expect(find.byKey(Key('import-error-row-$valid')), findsNothing);
    }
    expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(env.db.accounts.length, before);
  });

  testWidgets('confirmar muestra importadas, rechazadas y la nota', (
    tester,
  ) async {
    final env = await _pump(tester);
    final before = env.db.accounts.length;
    await _preview(tester);

    await _tap(tester, 'import-confirm-button');

    expect(_text(tester, 'import-imported'), 'Importadas: 3');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 8');
    for (final entry in _previewTitles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _confirmErrors[entry.key],
      );
    }
    expect(
      _text(tester, 'import-users-note'),
      'Las cuentas quedan pendientes de primer ingreso. No se envía ningún '
      'correo.',
    );
    expect(find.byKey(const Key('import-back-button')), findsOneWidget);
    expect(find.byKey(const Key('import-again-button')), findsOneWidget);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(env.db.accounts.length, before + 3);
    expect(env.db.accounts.skip(before).every((a) => !a.activated), isTrue);
  });

  testWidgets('"Confirmar importación" no aparece si ninguna fila sirve', (
    tester,
  ) async {
    await _pump(tester, file: _allInvalid);

    await _preview(tester);

    expect(_text(tester, 'import-valid'), 'Válidas: 0');
    expect(_text(tester, 'import-invalid'), 'Con error: 1');
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
  });

  testWidgets('cambiar de archivo borra el resultado', (tester) async {
    final env = await _pump(tester);
    await _preview(tester);
    expect(find.byKey(const Key('import-total')), findsOneWidget);

    env.picker.result = _allInvalid;
    await _pick(tester);

    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-error-row-4')), findsNothing);
    expect(find.byKey(const Key('import-error')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('cambiar de archivo después de confirmar vuelve al inicio', (
    tester,
  ) async {
    final env = await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');
    expect(find.byKey(const Key('import-imported')), findsOneWidget);

    env.picker.result = _allInvalid;
    await _pick(tester);

    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(find.byKey(const Key('import-users-note')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('"Cargar otro archivo" vuelve a empezar', (tester) async {
    await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-again-button');

    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(find.byKey(const Key('import-back-button')), findsNothing);
    expect(find.text('usuarios-prueba.csv'), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isFalse);
  });

  testWidgets('"Volver a Usuarios" lleva al padrón', (tester) async {
    final env = await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-back-button');

    expect(currentLocation(env.router), kUsersPath);
  });

  testWidgets('la flecha del AppBar vuelve a Usuarios', (tester) async {
    final env = await _pump(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(currentLocation(env.router), kUsersPath);
  });

  testWidgets('un CSV_INVALIDO del servidor se muestra en import-error', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: (_) => _FailingRepository(
        const ApiException(
          'El archivo supera el tamaño máximo permitido (1 MB)',
        ),
      ),
    );

    await _preview(tester);

    expect(
      _text(tester, 'import-error'),
      'El archivo supera el tamaño máximo permitido (1 MB)',
    );
    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('un encabezado equivocado se muestra en import-error', (
    tester,
  ) async {
    await _pump(tester, file: csvFile('ci,nombre\n1,2\n'));

    await _preview(tester);

    expect(
      _text(tester, 'import-error'),
      'El CSV debe tener exactamente las columnas: ci, nombre, apellido, '
      'fecha_nacimiento, correo, telefono_1, telefono_2, direccion, rol, '
      'especialidades',
    );
  });

  testWidgets('mientras previsualiza no se puede volver a tocar el botón', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(
      tester,
      repository: (db) => _GatedRepository(
        gate,
        FakeUserImportRepository(db, latency: Duration.zero),
      ),
    );
    await _pick(tester);

    await tester.tap(find.byKey(const Key('import-preview-button')));
    await tester.pump();

    expect(_enabled(tester, 'import-preview-button'), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-total')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('un error al confirmar se muestra y deja volver a intentar', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      repository: (db) => _ConfirmFailingRepository(
        FakeUserImportRepository(db, latency: Duration.zero),
        const ApiException('No pudimos conectarnos. Probá de nuevo.'),
      ),
    );
    final before = env.db.accounts.length;
    await _preview(tester);

    await _tap(tester, 'import-confirm-button');

    expect(
      _text(tester, 'import-error'),
      'No pudimos conectarnos. Probá de nuevo.',
    );
    expect(_text(tester, 'import-total'), 'Total: 11');
    expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(env.db.accounts.length, before);
  });

  testWidgets('el botón "Cargar desde CSV" de Usuarios lleva a importar', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      size: const Size(1300, 1800),
      initialLocation: kUsersPath,
    );
    expect(find.text('Cargar desde CSV'), findsOneWidget);
    expect(find.text('Alta de usuario'), findsOneWidget);

    await tester.tap(find.byKey(const Key('users-import-button')));
    await tester.pumpAndSettle();

    expect(currentLocation(env.router), kImportUsersPath);
    expect(find.text('Cargar usuarios desde CSV'), findsOneWidget);
  });

  // Van al final: Roboto se carga una sola vez por archivo y los tests que
  // vinieran después dejarían de usar la fuente de prueba. Con Roboto el texto
  // mide como en un celular.
  group('descarga de las filas con error', () {
    setUpAll(loadRoboto);
    const columns = [
      'ci',
      'nombre',
      'apellido',
      'fecha_nacimiento',
      'correo',
      'telefono_1',
      'telefono_2',
      'direccion',
      'rol',
      'especialidades',
      'error',
    ];

    testWidgets('la previsualización ofrece bajar las filas con error', (
      tester,
    ) async {
      final env = await _pump(tester);
      await _preview(tester);

      expect(find.text('Descargar filas con error'), findsOneWidget);
      await _tap(tester, 'import-download-button');

      expect(env.saver.saved.length, 1);
      expect(env.saver.saved.single.name, 'usuarios-prueba-errores.csv');
      final table = parseCsv(
        env.saver.saved.single.bytes,
        expectedHeader: columns,
      );
      expect(table.rows.map((r) => r[0]), [
        '30000033',
        '12345672',
        '23456783',
        '34567894',
        '30000048',
        '30000054',
        '30000010',
        '30000060',
      ]);
      expect(table.rows.every((r) => r[10].isNotEmpty), isTrue);
    });

    testWidgets('el resultado ofrece bajar las filas rechazadas', (
      tester,
    ) async {
      final env = await _pump(tester);
      await _preview(tester);
      await _tap(tester, 'import-confirm-button');

      expect(find.text('Descargar filas rechazadas'), findsOneWidget);
      await _tap(tester, 'import-download-button');

      final table = parseCsv(
        env.saver.saved.single.bytes,
        expectedHeader: columns,
      );
      expect(table.rows.length, 8);
      expect(table.rows.first.sublist(0, 3), ['30000033', 'Sara', 'Lima']);
    });

    testWidgets('con un archivo sin errores no hay botón', (tester) async {
      await _pump(
        tester,
        file: csvFile(
          'ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,telefono_2,direccion,rol,especialidades\n30000010,Julia,Ferrari,1992-03-15,julia.ferrari@example.org,099111222,,Av. Italia 1234,SOCIO,\n',
        ),
      );
      await _preview(tester);

      expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
      expect(find.byKey(const Key('import-download-button')), findsNothing);

      await _tap(tester, 'import-confirm-button');

      expect(find.byKey(const Key('import-imported')), findsOneWidget);
      expect(find.byKey(const Key('import-download-button')), findsNothing);
    });

    testWidgets('a 320 px con Roboto no desborda, ni con el aviso', (
      tester,
    ) async {
      final saver = RecordingCsvSaver()..error = StateError('falló');
      await _pump(tester, size: const Size(320, 640), saver: saver);
      await _preview(tester);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'import-download-button');

      expect(find.byKey(const Key('import-download-error')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'import-confirm-button');
      expect(find.text('Descargar filas rechazadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('la previsualización con las 8 filas de error no desborda', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 640));

      await _preview(tester);

      expect(tester.takeException(), isNull);
      for (final entry in _previewTitles.entries) {
        final finder = find.text(entry.value);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(finder, findsOneWidget, reason: 'fila ${entry.key}');
      }
      await tester.ensureVisible(
        find.byKey(const Key('import-confirm-button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el resultado final con los mensajes largos no desborda', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 640));
      await _preview(tester);

      await _tap(tester, 'import-confirm-button');

      expect(tester.takeException(), isNull);
      for (final key in ['import-error-row-7', 'import-error-row-8']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('import-again-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-back-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los dos botones de Usuarios entran en 320 px', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        initialLocation: kUsersPath,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('users-import-button')), findsOneWidget);
      expect(find.text('Alta de usuario'), findsOneWidget);
    });
  });

  testWidgets('tocar Confirmar importación dos veces en el mismo cuadro '
      'confirma una sola vez', (tester) async {
    late _CountingRepository counting;
    final env = await _pump(
      tester,
      repository: (db) => counting = _CountingRepository(
        FakeUserImportRepository(db, latency: Duration.zero),
      ),
    );
    final before = env.db.accounts.length;
    await _preview(tester);
    final confirm = find.byKey(const Key('import-confirm-button'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();

    // tester.tap no redibuja entre medio: los dos toques llegan con el
    // botón todavía encendido.
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(counting.confirmCalls, 1);
    expect(_text(tester, 'import-imported'), 'Importadas: 3');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 8');
    expect(env.db.accounts.length, before + 3);
  });

  test('confirm dos veces seguidas sin esperar llama una sola vez al '
      'repositorio', () async {
    final db = FakeAdminDatabase();
    final counting = _CountingRepository(
      FakeUserImportRepository(db, latency: Duration.zero),
    );
    final container = ProviderContainer(
      overrides: [
        userImportRepositoryProvider.overrideWith((ref) async => counting),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userImportControllerProvider, (_, _) {});
    final controller = container.read(userImportControllerProvider.notifier);
    controller.setFile(userImportFile());
    await controller.preview();
    expect(
      container.read(userImportControllerProvider).stage,
      UserImportStage.previewed,
    );

    final first = controller.confirm();
    final second = controller.confirm();
    await Future.wait([first, second]);

    expect(counting.confirmCalls, 1);
    final state = container.read(userImportControllerProvider);
    expect(state.stage, UserImportStage.done);
    expect(state.result!.imported, 3);
  });
}
