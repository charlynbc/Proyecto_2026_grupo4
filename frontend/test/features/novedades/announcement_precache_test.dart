import 'package:agenda_medica/features/home/widgets/announcements_carousel.dart';
import 'package:agenda_medica/features/novedades/announcement_image_provider.dart';
import 'package:agenda_medica/features/novedades/announcement_images.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anota las URL y los ids de imagen que se mandan a precargar, en orden.
class _Recorder {
  final calls = <String>[];
  final ids = <int>[];

  void call(BuildContext context, ImageProvider provider) {
    final announcementImage = provider as AnnouncementImageProvider;
    expect(announcementImage.cacheWidth, 1280);
    calls.add(announcementImage.url);
    ids.add(announcementImage.imageId);
  }

  List<String> take() {
    final copy = [...calls];
    calls.clear();
    ids.clear();
    return copy;
  }
}

String _url(int n) => 'https://example.invalid/portada-$n.png';

Announcement _news(int id, {bool cover = true}) => Announcement(
  id: id,
  publishedAt: DateTime.utc(2026, 11, 1),
  coverUrl: cover ? _url(id) : null,
  coverImageId: cover ? 100 + id : null,
);

Future<void> _pumpCarousel(
  WidgetTester tester,
  List<Announcement> items,
  _Recorder recorder,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnnouncementsCarousel(
          announcements: items,
          onOpen: (_) {},
          precache: recorder.call,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Novedad siguiente'));
  await tester.pumpAndSettle();
}

Future<void> _previous(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Novedad anterior'));
  await tester.pumpAndSettle();
}

void main() {
  group('carrusel', () {
    testWidgets(
      'al llegar la lista precarga todas las portadas, la visible primero',
      (tester) async {
        final recorder = _Recorder();

        await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], recorder);

        // Se precarga por id de imagen, el de la portada de cada novedad.
        expect(recorder.ids, [101, 102, 103]);
        expect(recorder.take(), [_url(1), _url(2), _url(3)]);
      },
    );

    testWidgets('al cambiar de página precarga la anterior y la siguiente', (
      tester,
    ) async {
      final recorder = _Recorder();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], recorder);
      recorder.take();

      await _next(tester);
      expect(recorder.take(), [_url(1), _url(3)]);

      await _next(tester);
      expect(recorder.take(), [_url(2)]);

      await _previous(tester);
      expect(recorder.take(), [_url(1), _url(3)]);

      await _previous(tester);
      expect(recorder.take(), [_url(2)]);
    });

    testWidgets('una novedad sin portada no se precarga', (tester) async {
      final recorder = _Recorder();

      await _pumpCarousel(tester, [
        _news(1),
        _news(2, cover: false),
        _news(3),
      ], recorder);

      expect(recorder.take(), [_url(1), _url(3)]);
    });

    testWidgets('sin ninguna portada no precarga nada', (tester) async {
      final recorder = _Recorder();

      await _pumpCarousel(tester, [
        _news(1, cover: false),
        _news(2, cover: false),
      ], recorder);
      await _next(tester);

      expect(recorder.take(), isEmpty);
    });

    testWidgets('si llega otra lista precarga sus portadas', (tester) async {
      final recorder = _Recorder();
      await _pumpCarousel(tester, [_news(1), _news(2)], recorder);
      recorder.take();

      await _pumpCarousel(tester, [_news(8), _news(9)], recorder);

      expect(recorder.take(), [_url(8), _url(9)]);
    });

    testWidgets('con una sola portada la precarga una vez', (tester) async {
      final recorder = _Recorder();

      await _pumpCarousel(tester, [_news(5)], recorder);

      expect(recorder.take(), [_url(5)]);
    });
  });

  group('galería del detalle', () {
    AnnouncementImage image(int n) => AnnouncementImage(
      id: n,
      order: n - 1,
      url: 'https://example.invalid/imagen-$n.png',
    );

    Future<void> pumpGallery(
      WidgetTester tester,
      List<AnnouncementImage> images,
      _Recorder recorder,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnnouncementGallery(
                images: images,
                onReload: () {},
                precache: recorder.call,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con tres imágenes precarga las otras dos', (tester) async {
      final recorder = _Recorder();

      await pumpGallery(tester, [image(1), image(2), image(3)], recorder);

      expect(recorder.ids, [2, 3]);
      expect(recorder.take(), [
        'https://example.invalid/imagen-2.png',
        'https://example.invalid/imagen-3.png',
      ]);
    });

    testWidgets('con una sola imagen no precarga nada', (tester) async {
      final recorder = _Recorder();

      await pumpGallery(tester, [image(1)], recorder);

      expect(recorder.take(), isEmpty);
    });

    testWidgets('con cinco imágenes precarga las cuatro restantes', (
      tester,
    ) async {
      final recorder = _Recorder();

      await pumpGallery(tester, [
        for (var n = 1; n <= 5; n++) image(n),
      ], recorder);

      expect(recorder.take(), [
        for (var n = 2; n <= 5; n++) 'https://example.invalid/imagen-$n.png',
      ]);
    });
  });

  group('precacheAnnouncementImage', () {
    testWidgets('con el contexto desmontado no falla', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox(key: Key('a'))));
      final context = tester.element(find.byKey(const Key('a')));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(context.mounted, isFalse);
      precacheAnnouncementImage(
        context,
        announcementImageProvider(
          imageId: 1,
          url: 'https://example.invalid/x.png',
          cacheWidth: kAnnouncementImageCacheWidth,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un error de descarga no se informa', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox(key: Key('a'))));
      final context = tester.element(find.byKey(const Key('a')));

      precacheAnnouncementImage(context, _FailingProvider());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

/// Un proveedor cuya descarga siempre falla.
class _FailingProvider extends ImageProvider<_FailingProvider> {
  @override
  Future<_FailingProvider> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(Exception('Sin red')),
  );
}
