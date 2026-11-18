import 'dart:async';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_edit.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/new_announcement_screen.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_visibility_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import 'admin_test_support.dart';

const _editPath = '/admin/cartelera/40/editar';

AnnouncementImage _image(int id, int order) => AnnouncementImage(
  id: id,
  order: order,
  url: 'https://example.invalid/imagen-$id',
);

List<FakeAnnouncementEntry> _seed() => [
  ...adminTestSeed(),
  // La 40 tiene las imágenes 12, 13 y 14; la 50 tiene cinco.
  adminTestEntry(
    40,
    'Con imágenes',
    published: DateTime.utc(2026, 11, 13, 12),
    until: DateTime.utc(2026, 12, 1, 3),
    summary: 'Resumen 40',
    images: [_image(12, 0), _image(13, 1), _image(14, 2)],
  ),
  adminTestEntry(
    50,
    'Con cinco',
    published: DateTime.utc(2026, 11, 11, 12),
    until: DateTime.utc(2026, 12, 1, 3),
    images: [for (var i = 0; i < 5; i++) _image(60 + i, i)],
  ),
];

/// Un Fake con las reglas reales que anota las ediciones y deja demorarlas o
/// hacerlas fallar, y cuenta los pedidos de las vistas que se invalidan.
class _Repo extends AdminTestRepo {
  _Repo() : super(seed: _seed());

  final edits = <({int id, AnnouncementEdit edit})>[];
  Completer<void>? updatePending;
  Object? updateError;
  int pageCalls = 0;
  int carouselCalls = 0;

  @override
  Future<void> update(int id, AnnouncementEdit edit) async {
    edits.add((id: id, edit: edit));
    if (updateError != null) throw updateError!;
    if (updatePending != null) await updatePending!.future;
    return super.update(id, edit);
  }

  @override
  Future<AnnouncementPage> list({int page = 0}) {
    pageCalls++;
    return super.list(page: page);
  }

  @override
  Future<List<Announcement>> carousel() {
    carouselCalls++;
    return super.carousel();
  }
}

AnnouncementImageUpload _png(String name) => AnnouncementImageUpload(
  name: name,
  bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  subtype: 'png',
);

final _titleField = find.byKey(const Key('edit-title'));
final _save = find.byKey(const Key('edit-save'));
final _error = find.byKey(const Key('edit-error'));

Finder get _textField =>
    find.widgetWithText(TextFormField, 'Texto de la novedad');

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed != null;

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Repo repo, {
  double width = 1280,
  double scale = 1,
  String location = _editPath,
  Future<List<AnnouncementImageUpload>> Function(int)? picker,
}) => pumpAdminScreen(
  tester,
  repo,
  width: width,
  scale: scale,
  location: location,
  extraOverrides: [
    if (picker != null)
      announcementImagePickerProvider.overrideWithValue(picker),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Finder _button(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(IconButton),
);

Finder _up(String label) => _button('Subir $label');
Finder _down(String label) => _button('Bajar $label');
Finder _remove(String label) => _button('Quitar $label');

List<int?> _sentIds(AnnouncementEdit edit) => [
  for (final ref in edit.images!)
    switch (ref) {
      ExistingImageRef(:final id) => id,
      NewImageRef() => null,
    },
];

void main() {
  setUpAll(loadRoboto);

  group('carga', () {
    testWidgets(
      'muestra el título y el texto actuales, sin fechas de vigencia',
      (tester) async {
        await _open(tester, _Repo());

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Editar novedad'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(_titleField).controller!.text,
          'Con imágenes',
        );
        expect(
          tester.widget<TextFormField>(_textField).controller!.text,
          'Texto 40',
        );
        expect(find.byType(AnnouncementVisibilityFields), findsNothing);
      },
    );

    testWidgets('mientras carga lo dice y no muestra el formulario', (
      tester,
    ) async {
      final repo = _Repo()..adminDetailPending = Completer<void>();
      await _open(tester, repo);

      expect(find.text('Cargando novedad…'), findsOneWidget);
      expect(_titleField, findsNothing);
      repo.adminDetailPending!.complete();
      await tester.pumpAndSettle();
      expect(_titleField, findsOneWidget);
    });

    testWidgets('si falla la carga muestra el mensaje y Reintentar la repite', (
      tester,
    ) async {
      final repo = _Repo()
        ..adminDetailError = const ApiException('No pudimos cargar de prueba.');
      await _open(tester, repo);

      expect(find.text('No pudimos cargar de prueba.'), findsOneWidget);
      expect(_titleField, findsNothing);

      repo.adminDetailError = null;
      await _tap(tester, find.text('Reintentar'));

      expect(_titleField, findsOneWidget);
      expect(repo.adminDetailIds, [40, 40]);
    });

    testWidgets('una novedad que no existe dice que no la encontramos', (
      tester,
    ) async {
      await _open(tester, _Repo(), location: '/admin/cartelera/77/editar');

      expect(find.text('No encontramos esta novedad.'), findsOneWidget);
      expect(_titleField, findsNothing);
    });

    testWidgets('avisa que si otro administrador guarda a la vez queda lo '
        'último guardado', (tester) async {
      await _open(tester, _Repo());

      expect(
        find.text(
          'Si otro administrador guarda esta novedad al mismo tiempo, queda '
          'lo último que se guardó.',
        ),
        findsOneWidget,
      );
    });
  });

  group('guardar el texto', () {
    testWidgets('sin cambios el botón está deshabilitado', (tester) async {
      await _open(tester, _Repo());

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('al cambiar el título se habilita y al volver al original se '
        'deshabilita', (tester) async {
      await _open(tester, _Repo());

      await _enter(tester, _titleField, 'Otro título');
      expect(_saveEnabled(tester), isTrue);

      await _enter(tester, _titleField, 'Con imágenes');
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('espacios de más no cuentan como un cambio', (tester) async {
      await _open(tester, _Repo());

      await _enter(tester, _titleField, '  Con imágenes  ');

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('guarda título, resumen y texto sin la lista de imágenes', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _enter(tester, _titleField, '  Título nuevo ');
      await _enter(tester, _textField, 'Texto nuevo');
      await _tap(tester, _save);

      expect(repo.edits, hasLength(1));
      final sent = repo.edits.single;
      expect(sent.id, 40);
      expect(sent.edit.title, 'Título nuevo');
      expect(sent.edit.summary, 'Resumen 40');
      expect(sent.edit.text, 'Texto nuevo');
      expect(sent.edit.images, isNull);
    });

    testWidgets('al guardar avisa, vuelve a la lista y la lista muestra el '
        'cambio', (tester) async {
      final repo = _Repo();
      await _open(tester, repo, location: '/admin/cartelera');

      await _tap(tester, find.byKey(const ValueKey('admin-edit-40')));
      expect(find.text('Editar novedad'), findsOneWidget);
      await _enter(tester, _titleField, 'Título nuevo');
      await _tap(tester, _save);

      expect(find.text('Novedad actualizada'), findsOneWidget);
      expect(find.text('Editar novedad'), findsNothing);
      expect(find.text('Título nuevo'), findsOneWidget);
      expect(find.text('Con imágenes'), findsNothing);
    });

    testWidgets('al guardar se pide de nuevo la lista de gestión, el carrusel '
        'y lo que ven los socios', (tester) async {
      final repo = _Repo();
      final container = await _open(tester, repo);
      container.listen(adminAnnouncementsProvider, (_, _) {});
      container.listen(latestAnnouncementsProvider, (_, _) {});
      container.listen(announcementsPageProvider(0), (_, _) {});
      await tester.pumpAndSettle();
      final before = (repo.listCalls, repo.carouselCalls, repo.pageCalls);

      await _enter(tester, _titleField, 'Título nuevo');
      await _tap(tester, _save);

      expect(repo.listCalls, before.$1 + 1, reason: 'lista de gestión');
      expect(repo.carouselCalls, before.$2 + 1, reason: 'carrusel del Inicio');
      expect(repo.pageCalls, before.$3 + 1, reason: 'lo que ven los socios');
    });

    testWidgets('al guardar desde el detalle, el detalle muestra el cambio', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(tester, repo, location: '/admin/cartelera/40');
      expect(find.text('Con imágenes'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('admin-detail-edit')));
      await _enter(tester, _titleField, 'Título nuevo');
      await _tap(tester, _save);

      expect(find.text('Editar novedad'), findsNothing);
      expect(find.text('Título nuevo'), findsOneWidget);
      expect(find.text('Con imágenes'), findsNothing);
      expect(repo.adminDetailIds, [40, 40]);
    });
  });

  group('validaciones del formulario', () {
    testWidgets('un título vacío no se envía y dice qué falta', (tester) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _enter(tester, _titleField, '   ');
      await _tap(tester, _save);

      expect(find.text('Ingresá el título.'), findsOneWidget);
      expect(repo.edits, isEmpty);
    });

    testWidgets('el resumen no admite más de 300 caracteres al escribir', (
      tester,
    ) async {
      await _open(tester, _Repo());

      await _enter(tester, find.byKey(const Key('edit-summary')), 'a' * 301);

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('edit-summary')))
            .controller!
            .text,
        hasLength(300),
      );
    });

    testWidgets('sin texto y sin imágenes no se envía', (tester) async {
      final repo = _Repo();
      await _open(tester, repo, location: '/admin/cartelera/30/editar');

      await _enter(tester, _textField, '  ');
      await _tap(tester, _save);

      expect(find.text('Agregá texto o al menos una imagen.'), findsOneWidget);
      expect(repo.edits, isEmpty);
    });

    testWidgets('sin texto alcanza con que queden imágenes', (tester) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _enter(tester, _textField, '');
      await _tap(tester, _save);

      expect(repo.edits, hasLength(1));
      expect(repo.edits.single.edit.text, isNull);
    });

    testWidgets('quitar todas las imágenes de una novedad sin texto no se '
        'envía', (tester) async {
      final repo = _Repo();
      await _open(tester, repo, location: '/admin/cartelera/50/editar');
      await _enter(tester, _textField, '');
      for (final n in [1, 2, 3, 4, 5]) {
        await _tap(tester, _remove('Imagen $n'));
      }

      await _tap(tester, _save);

      expect(find.text('Agregá texto o al menos una imagen.'), findsOneWidget);
      expect(repo.edits, isEmpty);
    });
  });

  group('imágenes', () {
    testWidgets('muestra las actuales en orden y marca la portada', (
      tester,
    ) async {
      await _open(tester, _Repo());

      final tops = [
        for (final n in [1, 2, 3]) tester.getTopLeft(find.text('Imagen $n')).dy,
      ];
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
      expect(find.text('Portada'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Portada')).dy, greaterThan(tops[0]));
      expect(tester.getTopLeft(find.text('Portada')).dy, lessThan(tops[1]));
    });

    testWidgets('subir la primera y bajar la última están deshabilitados', (
      tester,
    ) async {
      await _open(tester, _Repo());

      expect(tester.widget<IconButton>(_up('Imagen 1')).onPressed, isNull);
      expect(tester.widget<IconButton>(_down('Imagen 3')).onPressed, isNull);
      expect(tester.widget<IconButton>(_down('Imagen 1')).onPressed, isNotNull);
    });

    testWidgets('quitar una actual y guardar envía la lista final sin ella', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _tap(tester, _remove('Imagen 1'));
      expect(find.text('Imagen 1'), findsNothing);
      await _tap(tester, _save);

      expect(_sentIds(repo.edits.single.edit), [13, 14]);
    });

    testWidgets('bajar la primera cambia la portada y se envía en ese orden', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _tap(tester, _down('Imagen 1'));

      // Ahora la portada es la "Imagen 2", que quedó arriba.
      final portada = tester.getTopLeft(find.text('Portada')).dy;
      expect(portada, greaterThan(tester.getTopLeft(find.text('Imagen 2')).dy));
      expect(portada, lessThan(tester.getTopLeft(find.text('Imagen 1')).dy));
      expect(_saveEnabled(tester), isTrue);
      await _tap(tester, _save);

      expect(_sentIds(repo.edits.single.edit), [13, 12, 14]);
    });

    testWidgets('subir la última la lleva a la mitad', (tester) async {
      final repo = _Repo();
      await _open(tester, repo);

      await _tap(tester, _up('Imagen 3'));
      await _tap(tester, _save);

      expect(_sentIds(repo.edits.single.edit), [12, 14, 13]);
    });

    testWidgets('mover una imagen y devolverla deja el botón deshabilitado', (
      tester,
    ) async {
      await _open(tester, _Repo());

      await _tap(tester, _down('Imagen 1'));
      expect(_saveEnabled(tester), isTrue);
      await _tap(tester, _up('Imagen 1'));

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('agregar una nueva la suma al final y se envía como nueva', (
      tester,
    ) async {
      final repo = _Repo();
      final nueva = _png('nueva.png');
      await _open(tester, repo, picker: (_) async => [nueva]);

      await _tap(tester, find.byKey(const Key('edit-add-images')));
      expect(find.text('nueva.png'), findsOneWidget);
      await _tap(tester, _save);

      final refs = repo.edits.single.edit.images!;
      expect(refs, hasLength(4));
      expect(_sentIds(repo.edits.single.edit), [12, 13, 14, null]);
      expect((refs.last as NewImageRef).upload, same(nueva));
    });

    testWidgets('una nueva se puede subir a la portada', (tester) async {
      final repo = _Repo();
      await _open(tester, repo, picker: (_) async => [_png('nueva.png')]);

      await _tap(tester, find.byKey(const Key('edit-add-images')));
      await _tap(tester, _up('nueva.png'));
      await _tap(tester, _up('nueva.png'));
      await _tap(tester, _up('nueva.png'));
      await _tap(tester, _save);

      expect(_sentIds(repo.edits.single.edit), [null, 12, 13, 14]);
    });

    testWidgets('agregar una nueva y quitarla deja el botón deshabilitado', (
      tester,
    ) async {
      await _open(tester, _Repo(), picker: (_) async => [_png('nueva.png')]);

      await _tap(tester, find.byKey(const Key('edit-add-images')));
      expect(_saveEnabled(tester), isTrue);
      await _tap(tester, _remove('nueva.png'));

      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('el selector recibe cuántas imágenes hay y con cinco ya no se '
        'puede agregar más', (tester) async {
      final counts = <int>[];
      await _open(
        tester,
        _Repo(),
        picker: (count) async {
          counts.add(count);
          return [_png('a.png'), _png('b.png')];
        },
      );

      await _tap(tester, find.byKey(const Key('edit-add-images')));

      expect(counts, [3]);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-add-images')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('con cinco actuales el botón de agregar está deshabilitado', (
      tester,
    ) async {
      await _open(tester, _Repo(), location: '/admin/cartelera/50/editar');

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-add-images')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('si el selector rechaza un archivo muestra su mensaje', (
      tester,
    ) async {
      await _open(
        tester,
        _Repo(),
        picker: (_) async =>
            throw const ApiException('grande.png supera los 5 MB.'),
      );

      await _tap(tester, find.byKey(const Key('edit-add-images')));

      expect(find.text('grande.png supera los 5 MB.'), findsOneWidget);
    });
  });

  group('guardando y errores', () {
    testWidgets('mientras guarda el botón dice Guardando y no se puede '
        'volver a tocar', (tester) async {
      final repo = _Repo()..updatePending = Completer<void>();
      await _open(tester, repo);
      await _enter(tester, _titleField, 'Título nuevo');

      await tester.ensureVisible(_save);
      await tester.tap(_save);
      await tester.pump();

      expect(find.text('Guardando…'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-cancel')))
            .onPressed,
        isNull,
      );
      expect(repo.edits, hasLength(1));

      repo.updatePending!.complete();
      await tester.pumpAndSettle();
    });

    for (final (status, message) in [
      (400, 'El título es obligatorio y admite hasta 160 caracteres'),
      (404, 'Anuncio no encontrado'),
      (503, 'No pudimos guardar las imágenes. Probá de nuevo en unos minutos.'),
    ]) {
      testWidgets('un error $status muestra el mensaje del servidor y deja '
          'seguir editando', (tester) async {
        final repo = _Repo()..updateError = ApiException(message);
        await _open(tester, repo);
        await _enter(tester, _titleField, 'Título nuevo');

        await _tap(tester, _save);

        expect(tester.widget<Text>(_error).data, message);
        expect(_saveEnabled(tester), isTrue);
        expect(
          tester.widget<TextFormField>(_titleField).controller!.text,
          'Título nuevo',
        );
        expect(find.text('Novedad actualizada'), findsNothing);
      });
    }

    testWidgets('después de un error se puede volver a guardar', (
      tester,
    ) async {
      final repo = _Repo()
        ..updateError = const ApiException('Falló de prueba.');
      await _open(tester, repo);
      await _enter(tester, _titleField, 'Título nuevo');
      await _tap(tester, _save);

      repo.updateError = null;
      await _tap(tester, _save);

      expect(repo.edits, hasLength(2));
      expect(find.text('Novedad actualizada'), findsOneWidget);
    });

    testWidgets('Cancelar vuelve sin enviar nada', (tester) async {
      final repo = _Repo();
      await _open(tester, repo, location: '/admin/cartelera');
      await _tap(tester, find.byKey(const ValueKey('admin-edit-40')));
      await _enter(tester, _titleField, 'Título nuevo');

      await _tap(tester, find.byKey(const Key('edit-cancel')));

      expect(find.text('Editar novedad'), findsNothing);
      expect(repo.edits, isEmpty);
      expect(find.text('Con imágenes'), findsOneWidget);
    });
  });

  group('acciones Editar', () {
    testWidgets(
      'el detalle de una novedad programada también se puede editar',
      (tester) async {
        await _open(tester, _Repo(), location: '/admin/cartelera/20');

        await _tap(tester, find.byKey(const Key('admin-detail-edit')));

        expect(find.text('Editar novedad'), findsOneWidget);
      },
    );

    testWidgets('la lista tiene Editar en cada novedad', (tester) async {
      await _open(tester, _Repo(), location: '/admin/cartelera');

      for (final id in [10, 20, 30, 40, 50]) {
        expect(find.byKey(ValueKey('admin-edit-$id')), findsOneWidget);
      }
    });

    testWidgets('un id que no es un número vuelve a la lista', (tester) async {
      await _open(tester, _Repo(), location: '/admin/cartelera/abc/editar');

      expect(find.text('Editar novedad'), findsNothing);
      expect(find.byKey(const ValueKey('admin-edit-40')), findsOneWidget);
    });
  });

  group('320 px y texto al doble', () {
    testWidgets('el formulario con imágenes no se corta ni se desborda', (
      tester,
    ) async {
      await _open(
        tester,
        _Repo(),
        width: 320,
        scale: 2,
        picker: (_) async => [_png('una-imagen-con-un-nombre-muy-largo.png')],
      );
      await _tap(tester, find.byKey(const Key('edit-add-images')));

      for (final label in [
        'Imagen 1',
        'Imagen 2',
        'Imagen 3',
        'una-imagen-con-un-nombre-muy-largo.png',
      ]) {
        for (final prefix in ['Subir', 'Bajar', 'Quitar']) {
          final button = find.byTooltip('$prefix $label');
          await tester.ensureVisible(button);
          await tester.pump();
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$prefix $label');
          expect(rect.right, lessThanOrEqualTo(320), reason: '$prefix $label');
        }
      }
      for (final key in ['edit-save', 'edit-cancel', 'edit-add-images']) {
        final finder = find.byKey(Key(key));
        await tester.ensureVisible(finder);
        await tester.pump();
        expect(
          tester.getRect(finder).right,
          lessThanOrEqualTo(320),
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error de guardado se lee completo', (tester) async {
      final repo = _Repo()
        ..updateError = const ApiException(
          'No pudimos guardar las imágenes. Probá de nuevo en unos minutos.',
        );
      await _open(tester, repo, width: 320, scale: 2);
      await _enter(tester, _titleField, 'Título nuevo');

      await _tap(tester, _save);

      final rect = tester.getRect(_error);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}
