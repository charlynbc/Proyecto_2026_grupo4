import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_correction_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_correction_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_correction_repository.dart';
import 'package:agenda_medica/features/especialidades/screens/edit_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/error_text_fit.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

// Semilla de FakeAdminDatabase: 1 Medicina General (sin pase), 2 Cardiología
// (con pase), 3 Dermatología (con pase).

typedef _Call = ({int id, String? name, bool? requiresReferral});

/// Anota cada pedido de corrección y delega en el falso de verdad.
class _Recording implements SpecialtyCorrectionRepository {
  _Recording(this._delegate);

  final SpecialtyCorrectionRepository _delegate;
  final calls = <_Call>[];
  Completer<void>? gate;
  Object? error;

  @override
  Future<Specialty> correct(
    int id, {
    String? name,
    bool? requiresReferral,
  }) async {
    calls.add((id: id, name: name, requiresReferral: requiresReferral));
    await gate?.future;
    if (error != null) throw error!;
    return _delegate.correct(
      id,
      name: name,
      requiresReferral: requiresReferral,
    );
  }
}

class _Catalog extends FakeSpecialtyRepository {
  _Catalog(super.db) : super(latency: Duration.zero);

  int listCalls = 0;

  @override
  Future<List<Specialty>> list() {
    listCalls++;
    return super.list();
  }
}

typedef _Harness = ({GoRouter router, _Recording correction, _Catalog catalog});

Future<_Harness> _pump(
  WidgetTester tester, {
  String initial = kSpecialtiesPath,
  Size size = const Size(900, 1800),
}) async {
  final db = FakeAdminDatabase();
  final correction = _Recording(
    FakeSpecialtyCorrectionRepository(db, latency: Duration.zero),
  );
  final catalog = _Catalog(db);
  final router = await pumpAdminScreens(
    tester,
    initialLocation: initial,
    size: size,
    routes: [
      GoRoute(
        path: kSpecialtiesPath,
        builder: (_, _) => const SpecialtiesScreen(),
        routes: [
          GoRoute(
            path: ':id/corregir',
            builder: (_, state) => EditSpecialtyScreen(
              id: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
    ],
    overrides: [
      specialtyRepositoryProvider.overrideWith((ref) async => catalog),
      specialtySearchRepositoryProvider.overrideWith(
        (ref) async =>
            FakeSpecialtySearchRepository(db, latency: Duration.zero),
      ),
      specialtyCorrectionRepositoryProvider.overrideWith(
        (ref) async => correction,
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
  return (router: router, correction: correction, catalog: catalog);
}

Finder _edit(int id) => find.byKey(Key('specialty-edit-$id'));
final _name = find.byKey(const Key('edit-specialty-name'));
final _referral = find.byKey(const Key('edit-specialty-requires-referral'));
final _save = find.byKey(const Key('edit-specialty-save'));
final _note = find.byKey(const Key('edit-specialty-note'));
final _fieldError = find.byKey(const Key('edit-specialty-error'));
final _formError = find.byKey(const Key('edit-specialty-form-error'));

Future<void> _open(WidgetTester tester, int id) async {
  await tester.ensureVisible(_edit(id));
  await tester.tap(_edit(id));
  await tester.pumpAndSettle();
}

Future<void> _enterName(WidgetTester tester, String text) async {
  await tester.ensureVisible(_name);
  await tester.enterText(_name, text);
  await tester.pump();
}

Future<void> _toggleReferral(WidgetTester tester) async {
  await tester.ensureVisible(_referral);
  await tester.tap(_referral);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

String _nameText(WidgetTester tester) =>
    tester.widget<TextFormField>(_name).controller!.text;

bool _referralValue(WidgetTester tester) =>
    tester.widget<CheckboxListTile>(_referral).value!;

VoidCallback? _saveAction(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed;

Iterable<String> _listNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => tile.title)
    .whereType<Text>()
    .map((text) => text.data!);

/// Cuántas filas del listado dicen [label] ("Requiere pase" o "Libre"). El
/// filtro de la barra también tiene un texto "Requiere pase".
int _rows(String label) => find
    .descendant(of: find.byType(ListTile), matching: find.text(label))
    .evaluate()
    .length;

String _textOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

void main() {
  setUpAll(loadRoboto);

  testWidgets('cada fila tiene su lápiz "Corregir" y la fila no es un enlace', (
    tester,
  ) async {
    await _pump(tester);

    for (final id in [1, 2, 3]) {
      expect(_edit(id), findsOneWidget);
    }
    expect(tester.widget<IconButton>(_edit(2)).tooltip, 'Corregir');
    expect(
      tester
          .widgetList<ListTile>(find.byType(ListTile))
          .every((tile) => tile.onTap == null),
      isTrue,
    );
  });

  testWidgets('el lápiz abre el formulario con los datos de la fila', (
    tester,
  ) async {
    final h = await _pump(tester);

    await _open(tester, 2);

    expect(currentLocation(h.router), '/admin/especialidades/2/corregir');
    expect(find.text('Corregir especialidad'), findsOneWidget);
    expect(_nameText(tester), 'Cardiología');
    expect(_referralValue(tester), isTrue);
    expect(
      _textOf(tester, _note),
      'El cambio de la exigencia de pase rige para las consultas que se '
      'agenden desde ahora. Las consultas ya agendadas no cambian.',
    );
  });

  testWidgets('Medicina General abre con el pase desmarcado', (tester) async {
    await _pump(tester);

    await _open(tester, 1);

    expect(_nameText(tester), 'Medicina General');
    expect(_referralValue(tester), isFalse);
  });

  testWidgets('Guardar cambios sigue apagado mientras no haya diferencias', (
    tester,
  ) async {
    await _pump(tester);
    await _open(tester, 2);

    expect(_saveAction(tester), isNull);

    await _enterName(tester, '  Cardiología  ');
    expect(_saveAction(tester), isNull);

    await _enterName(tester, 'Cardiología clínica');
    expect(_saveAction(tester), isNotNull);

    await _enterName(tester, 'Cardiología');
    expect(_saveAction(tester), isNull);

    await _toggleReferral(tester);
    expect(_saveAction(tester), isNotNull);
    await _toggleReferral(tester);
    expect(_saveAction(tester), isNull);
  });

  testWidgets('si solo cambió el nombre, manda solo el nombre', (tester) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    await _enterName(tester, '  Cardiología clínica  ');

    await _tapSave(tester);

    expect(h.correction.calls, [
      (id: 2, name: 'Cardiología clínica', requiresReferral: null),
    ]);
  });

  testWidgets('si solo cambió el pase, manda solo el pase', (tester) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    await _toggleReferral(tester);

    await _tapSave(tester);

    expect(h.correction.calls, [(id: 2, name: null, requiresReferral: false)]);
  });

  testWidgets('si cambiaron los dos, manda los dos', (tester) async {
    final h = await _pump(tester);
    await _open(tester, 1);
    await _enterName(tester, 'Medicina Familiar');
    await _toggleReferral(tester);

    await _tapSave(tester);

    expect(h.correction.calls, [
      (id: 1, name: 'Medicina Familiar', requiresReferral: true),
    ]);
  });

  testWidgets('el éxito vuelve al listado con el aviso y el nombre nuevo', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    await _enterName(tester, 'Cardiología clínica');

    await _tapSave(tester);

    expect(currentLocation(h.router), kSpecialtiesPath);
    expect(find.text('Especialidad corregida.'), findsOneWidget);
    expect(_listNames(tester), [
      'Cardiología clínica',
      'Dermatología',
      'Medicina General',
    ]);
  });

  testWidgets('desmarcar el pase de Cardiología deja la fila en "Libre"', (
    tester,
  ) async {
    await _pump(tester);
    expect(_rows('Libre'), 1);
    expect(_rows('Requiere pase'), 2);
    await _open(tester, 2);
    await _toggleReferral(tester);

    await _tapSave(tester);

    expect(_rows('Libre'), 2);
    expect(_rows('Requiere pase'), 1);
  });

  testWidgets('tras guardar, abrir la fila otra vez muestra lo guardado', (
    tester,
  ) async {
    await _pump(tester);
    await _open(tester, 2);
    await _enterName(tester, 'Cardiología clínica');
    await _toggleReferral(tester);
    await _tapSave(tester);

    await _open(tester, 2);

    expect(_nameText(tester), 'Cardiología clínica');
    expect(_referralValue(tester), isFalse);
  });

  testWidgets('guardar conserva el filtro y el sentido del listado', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('specialty-filter-direction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('specialty-filter-name')),
      'logía',
    );
    await tester.tap(find.byKey(const Key('specialty-filter-search')));
    await tester.pumpAndSettle();
    expect(_listNames(tester), ['Dermatología', 'Cardiología']);

    await _open(tester, 2);
    await _enterName(tester, 'Cardiología clínica');
    await _tapSave(tester);

    expect(_listNames(tester), ['Dermatología', 'Cardiología clínica']);
    expect(
      find.descendant(
        of: find.byKey(const Key('specialty-filter-direction')),
        matching: find.text('Descendente'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('specialty-filter-name')))
          .controller!
          .text,
      'logía',
    );
  });

  testWidgets('un nombre duplicado se avisa bajo el campo y no vuelve', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _open(tester, 3);
    await _enterName(tester, 'MEDICINA GENERAL');

    await _tapSave(tester);

    expect(
      _textOf(tester, _fieldError),
      'Ya existe una especialidad registrada con ese nombre.',
    );
    expect(_formError, findsNothing);
    expect(currentLocation(h.router), '/admin/especialidades/3/corregir');
    expect(_nameText(tester), 'MEDICINA GENERAL');
    expect(_saveAction(tester), isNotNull);
    expect(find.text('Especialidad corregida.'), findsNothing);
  });

  testWidgets('no encontrada avisa arriba del formulario y refresca el '
      'catálogo', (tester) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    final before = h.catalog.listCalls;
    h.correction.error = const SpecialtyCorrectionException(
      SpecialtyCorrectionFailure.notFound,
      'No se encontró la especialidad.',
    );
    await _enterName(tester, 'Cardiología clínica');

    await _tapSave(tester);

    expect(_textOf(tester, _formError), 'No se encontró la especialidad.');
    expect(_fieldError, findsNothing);
    expect(h.catalog.listCalls, before + 1);
    expect(_nameText(tester), 'Cardiología clínica');
  });

  for (final failure in [
    SpecialtyCorrectionFailure.validation,
    SpecialtyCorrectionFailure.other,
  ]) {
    testWidgets('$failure muestra el mensaje del servidor arriba', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _open(tester, 2);
      h.correction.error = SpecialtyCorrectionException(
        failure,
        'Mensaje del servidor para el caso.',
      );
      await _enterName(tester, 'Cardiología clínica');

      await _tapSave(tester);

      expect(_textOf(tester, _formError), 'Mensaje del servidor para el caso.');
      expect(_fieldError, findsNothing);
      expect(_saveAction(tester), isNotNull);
    });
  }

  testWidgets('un error sin tipo muestra el mensaje genérico arriba', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    h.correction.error = StateError('no es de la API');
    await _enterName(tester, 'Cardiología clínica');

    await _tapSave(tester);

    expect(_textOf(tester, _formError), kApiGenericMessage);
  });

  testWidgets('dos toques seguidos hacen una sola llamada', (tester) async {
    final h = await _pump(tester);
    h.correction.gate = Completer<void>();
    await _open(tester, 2);
    await _enterName(tester, 'Cardiología clínica');

    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.tap(_save);
    await tester.pump();

    expect(h.correction.calls, hasLength(1));
    expect(_saveAction(tester), isNull);
    h.correction.gate!.complete();
    await tester.pumpAndSettle();
    expect(h.correction.calls, hasLength(1));
  });

  testWidgets('Cancelar vuelve al listado sin llamar', (tester) async {
    final h = await _pump(tester);
    await _open(tester, 2);
    await _enterName(tester, 'Cardiología clínica');

    final cancel = find.byKey(const Key('edit-specialty-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(currentLocation(h.router), kSpecialtiesPath);
    expect(h.correction.calls, isEmpty);
  });

  for (final location in [
    '/admin/especialidades/9999/corregir',
    '/admin/especialidades/abc/corregir',
    '/admin/especialidades/0/corregir',
  ]) {
    testWidgets('$location muestra "No encontramos esa especialidad."', (
      tester,
    ) async {
      final h = await _pump(tester, initial: location);

      expect(find.text('No encontramos esa especialidad.'), findsOneWidget);
      expect(_name, findsNothing);

      await tester.tap(find.byKey(const Key('edit-specialty-back')));
      await tester.pumpAndSettle();

      expect(currentLocation(h.router), kSpecialtiesPath);
    });
  }

  testWidgets('a 900 px la fila deja "Requiere pase" y "Libre" a la derecha', (
    tester,
  ) async {
    await _pump(tester);

    for (final (name, label) in [
      ('Dermatología', 'Requiere pase'),
      ('Medicina General', 'Libre'),
    ]) {
      final tile = find.widgetWithText(ListTile, name);
      final title = find.descendant(of: tile, matching: find.text(name));
      final text = find.descendant(of: tile, matching: find.text(label));
      expect(text, findsOneWidget, reason: name);
      expect(
        tester.getTopLeft(text).dx,
        greaterThan(tester.getTopRight(title).dx),
        reason: name,
      );
      expect(
        tester.getCenter(text).dy,
        closeTo(tester.getCenter(title).dy, 1),
        reason: name,
      );
    }
  });

  group('a 320 px con Roboto', () {
    const narrow = Size(320, 900);
    testWidgets('el nombre "Dermatología" se dibuja en una sola línea', (
      tester,
    ) async {
      await _pump(tester);
      final name = find.text('Dermatología');
      final wideHeight = tester.getSize(name).height;
      expect(wideHeight, lessThan(40));

      tester.view.physicalSize = narrow;
      await tester.pumpAndSettle();

      expect(tester.getSize(name).height, wideHeight);
      expect(tester.getSize(name).height, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('el texto del pase queda debajo del nombre y el lápiz sigue', (
      tester,
    ) async {
      await _pump(tester, size: narrow);

      for (final (id, name, label) in [
        (3, 'Dermatología', 'Requiere pase'),
        (1, 'Medicina General', 'Libre'),
      ]) {
        final tile = find.widgetWithText(ListTile, name);
        final title = find.descendant(of: tile, matching: find.text(name));
        final text = find.descendant(of: tile, matching: find.text(label));
        expect(text, findsOneWidget, reason: name);
        expect(
          tester.getTopLeft(text).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
          reason: name,
        );
        final pencil = find.descendant(of: tile, matching: _edit(id));
        expect(pencil, findsOneWidget, reason: name);
        expect(
          tester.getTopLeft(pencil).dx,
          greaterThan(tester.getTopRight(text).dx),
          reason: name,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el listado con el lápiz no desborda', (tester) async {
      await _pump(tester, size: narrow);

      expect(_edit(2), findsOneWidget);
      expect(_rows('Requiere pase'), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el formulario con el error de duplicado visible no desborda', (
      tester,
    ) async {
      await _pump(tester, size: narrow);
      await _open(tester, 3);
      await _enterName(tester, 'MEDICINA GENERAL');
      await _tapSave(tester);

      expect(_fieldError, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el formulario con un error largo arriba no desborda', (
      tester,
    ) async {
      final h = await _pump(tester, size: narrow);
      await _open(tester, 2);
      h.correction.error = SpecialtyCorrectionException(
        SpecialtyCorrectionFailure.other,
        'Este es un mensaje de error bastante largo para comprobar que el '
        'formulario no se desborda cuando el servidor explica con detalle '
        'qué fue lo que pasó con la corrección.',
      );
      await _enterName(tester, 'Cardiología clínica');
      await _tapSave(tester);

      expect(_formError, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  for (final scale in [1.0, 1.15]) {
    testWidgets('a 320 px con el texto al $scale el mensaje del nombre vacío '
        'se lee entero', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, size: const Size(320, 900));
      await _open(tester, 1);

      await _enterName(tester, '');
      await _tapSave(tester);

      expectErrorFits(tester, 'Ingresá el nombre de la especialidad.');
    });
  }
}
