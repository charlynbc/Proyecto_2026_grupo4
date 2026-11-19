import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_edit.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_support.dart';

// Las novedades de la prueba: la 1 tiene las imágenes 12, 13 y 14, vigencia,
// posición 2 y texto; la 2 tiene la imagen 99.
final _published = DateTime.utc(2026, 11, 3, 12);
final _from = DateTime.utc(2026, 11, 1, 3);
final _until = DateTime.utc(2026, 12, 1, 3);

AnnouncementImage _image(int id, int order) => AnnouncementImage(
  id: id,
  order: order,
  url: 'https://example.invalid/imagen-$id',
);

FakeAnnouncementsRepository _repository() => FakeAnnouncementsRepository(
  now: () => kAdminTestNow,
  seed: [
    adminTestEntry(
      1,
      'Campaña',
      published: _published,
      from: _from,
      until: _until,
      position: 2,
      summary: 'Resumen',
      images: [_image(12, 0), _image(13, 1), _image(14, 2)],
    ),
    adminTestEntry(
      2,
      'Otra',
      published: DateTime.utc(2026, 11, 4, 12),
      images: [_image(99, 0)],
    ),
  ],
);

AnnouncementImageUpload _jpeg(String name) => AnnouncementImageUpload(
  name: name,
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x01]),
  subtype: 'jpeg',
);

AnnouncementEdit _edit({
  String title = 'Campaña editada',
  String? summary = 'Resumen editado',
  String? text = 'Texto editado',
  List<AnnouncementImageRef>? images,
}) => AnnouncementEdit(
  title: title,
  summary: summary,
  text: text,
  images: images,
);

Future<List<int>> _imageIds(
  FakeAnnouncementsRepository repository,
  int id,
) async => [for (final i in (await repository.adminDetail(id)).images) i.id];

Matcher _fails(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

void main() {
  group('texto', () {
    test('cambia título, resumen y texto, recortados', () async {
      final repository = _repository();

      await repository.update(
        1,
        _edit(title: '  Título nuevo  ', summary: ' Resumen 2 ', text: ' T2 '),
      );

      final detail = await repository.adminDetail(1);
      expect(detail.title, 'Título nuevo');
      expect(detail.summary, 'Resumen 2');
      expect(detail.text, 'T2');
    });

    test('un resumen o un texto en blanco se guardan como nulos', () async {
      final repository = _repository();

      await repository.update(
        1,
        _edit(summary: '   ', text: '  ', images: [const ExistingImageRef(12)]),
      );

      final detail = await repository.adminDetail(1);
      expect(detail.summary, isNull);
      expect(detail.text, isNull);
    });

    test('no cambia la vigencia, la posición, la publicación ni el estado '
        'ni toca otra novedad', () async {
      final repository = _repository();

      await repository.update(1, _edit());

      final detail = await repository.adminDetail(1);
      expect(detail.visibleFrom, _from);
      expect(detail.visibleUntil, _until);
      expect(detail.position, 2);
      expect(detail.publishedAt, _published);
      expect(detail.status, AnnouncementStatus.active);
      expect((await repository.adminDetail(2)).title, 'Otra');
    });

    test('el cambio se ve en la lista de gestión', () async {
      final repository = _repository();

      await repository.update(1, _edit(title: 'Título nuevo'));

      final list = await repository.adminList();
      expect(list.firstWhere((a) => a.id == 1).title, 'Título nuevo');
    });
  });

  group('título y resumen', () {
    for (final title in ['', '   ', 'a' * 161]) {
      test(
        'un título de ${title.trim().length} caracteres es un 400',
        () async {
          final repository = _repository();

          await expectLater(
            repository.update(1, _edit(title: title)),
            _fails('El título es obligatorio y admite hasta 160 caracteres'),
          );
          expect((await repository.adminDetail(1)).title, 'Campaña');
        },
      );
    }

    test('160 caracteres de título y 300 de resumen se aceptan', () async {
      final repository = _repository();

      await repository.update(1, _edit(title: 'a' * 160, summary: 'b' * 300));

      expect((await repository.adminDetail(1)).title, 'a' * 160);
    });

    test('un resumen de 301 caracteres es un 400', () async {
      final repository = _repository();

      await expectLater(
        repository.update(1, _edit(summary: 'b' * 301)),
        _fails('El resumen admite hasta 300 caracteres'),
      );
      expect((await repository.adminDetail(1)).summary, 'Resumen');
    });
  });

  group('imágenes', () {
    test('sin lista no se tocan las imágenes', () async {
      final repository = _repository();

      await repository.update(1, _edit());

      expect(await _imageIds(repository, 1), [12, 13, 14]);
    });

    test('la lista final fija el orden, quita las que no figuran y suma las '
        'nuevas', () async {
      final repository = _repository();

      await repository.update(
        1,
        _edit(
          images: [
            const ExistingImageRef(14),
            NewImageRef(_jpeg('nueva.jpg')),
            const ExistingImageRef(12),
          ],
        ),
      );

      final images = (await repository.adminDetail(1)).images;
      expect([for (final i in images) i.id], [14, 100, 12]);
      expect([for (final i in images) i.order], [0, 1, 2]);
      expect(images[1].url, startsWith('data:image/jpeg;base64,'));
    });

    test(
      'los ids de imágenes nuevas siguen creciendo aunque se borren',
      () async {
        final repository = _repository();

        await repository.update(
          1,
          _edit(images: [NewImageRef(_jpeg('a.jpg'))]),
        );
        await repository.update(
          1,
          _edit(images: [NewImageRef(_jpeg('b.jpg'))]),
        );

        expect(await _imageIds(repository, 1), [101]);
      },
    );

    test('una lista vacía quita todas si queda texto', () async {
      final repository = _repository();

      await repository.update(1, _edit(images: const []));

      expect(await _imageIds(repository, 1), isEmpty);
    });

    test('una lista vacía sin texto es un 400 y no cambia nada', () async {
      final repository = _repository();

      await expectLater(
        repository.update(1, _edit(title: 'Otro', text: ' ', images: const [])),
        _fails('La novedad debe tener texto o al menos una imagen'),
      );
      expect(await _imageIds(repository, 1), [12, 13, 14]);
      expect((await repository.adminDetail(1)).title, 'Campaña');
    });

    test(
      'sin texto y sin tocar las imágenes alcanza con las que tiene',
      () async {
        final repository = _repository();

        await repository.update(1, _edit(text: null));

        expect((await repository.adminDetail(1)).text, isNull);
      },
    );

    test('hasta 5 imágenes en total se aceptan y 6 es un 400', () async {
      final repository = _repository();
      List<AnnouncementImageRef> ofCount(int news) => [
        const ExistingImageRef(12),
        const ExistingImageRef(13),
        const ExistingImageRef(14),
        for (var i = 0; i < news; i++) NewImageRef(_jpeg('n$i.jpg')),
      ];

      await repository.update(1, _edit(images: ofCount(2)));
      expect((await repository.adminDetail(1)).images, hasLength(5));

      await expectLater(
        repository.update(1, _edit(title: 'No', images: ofCount(3))),
        _fails('La novedad admite hasta 5 imágenes'),
      );
      expect((await repository.adminDetail(1)).title, 'Campaña editada');
    });

    test('una imagen de otra novedad es un 400 y no cambia nada (todo o '
        'nada)', () async {
      final repository = _repository();

      await expectLater(
        repository.update(
          1,
          _edit(
            title: 'No debe guardarse',
            images: [const ExistingImageRef(12), const ExistingImageRef(99)],
          ),
        ),
        _fails('La imagen 99 no pertenece a esta novedad'),
      );

      expect((await repository.adminDetail(1)).title, 'Campaña');
      expect(await _imageIds(repository, 1), [12, 13, 14]);
      expect(await _imageIds(repository, 2), [99]);
    });

    test('una imagen repetida es un 400', () async {
      final repository = _repository();

      await expectLater(
        repository.update(
          1,
          _edit(
            images: [const ExistingImageRef(12), const ExistingImageRef(12)],
          ),
        ),
        _fails('La imagen 12 figura más de una vez'),
      );
    });

    test(
      'un archivo nuevo que no es JPEG ni PNG es un 400 y no cambia nada',
      () async {
        final repository = _repository();
        final bad = AnnouncementImageUpload(
          name: 'falsa.jpg',
          bytes: Uint8List.fromList([1, 2, 3]),
          subtype: 'jpeg',
        );

        await expectLater(
          repository.update(
            1,
            _edit(
              title: 'No',
              images: [const ExistingImageRef(12), NewImageRef(bad)],
            ),
          ),
          _fails('falsa.jpg no es una imagen JPEG o PNG válida.'),
        );
        expect(await _imageIds(repository, 1), [12, 13, 14]);
        expect((await repository.adminDetail(1)).title, 'Campaña');
      },
    );
  });

  test(
    'una novedad que no existe es un 404 con el mensaje del servidor',
    () async {
      final repository = _repository();

      await expectLater(
        repository.update(77, _edit()),
        _fails('Anuncio no encontrado'),
      );
    },
  );
}
