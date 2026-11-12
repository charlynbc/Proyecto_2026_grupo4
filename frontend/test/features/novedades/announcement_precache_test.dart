import 'dart:async';

import 'package:agenda_medica/features/home/widgets/announcements_carousel.dart';
import 'package:agenda_medica/features/novedades/announcement_image_provider.dart';
import 'package:agenda_medica/features/novedades/announcement_images.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una precarga controlada por la prueba: anota qué se pidió, en orden, y cada
/// pedido queda pendiente hasta que la prueba lo completa o lo hace fallar.
class _Gate {
  final calls = <String>[];
  final ids = <int>[];
  final pending = <Completer<void>>[];

  Future<void> call(BuildContext context, ImageProvider provider) {
    final announcementImage = provider as AnnouncementImageProvider;
    expect(announcementImage.cacheWidth, 1280);
    calls.add(announcementImage.url);
    ids.add(announcementImage.imageId);
    final done = Completer<void>();
    pending.add(done);
    return done.future;
  }

  void complete(int index) => pending[index].complete();

  void fail(int index) => pending[index].completeError(Exception('Sin red'));
}

/// Una precarga que termina enseguida, para la galería.
class _Instant {
  final calls = <String>[];
  final ids = <int>[];

  Future<void> call(BuildContext context, ImageProvider provider) {
    final announcementImage = provider as AnnouncementImageProvider;
    expect(announcementImage.cacheWidth, 1280);
    calls.add(announcementImage.url);
    ids.add(announcementImage.imageId);
    return Future<void>.value();
  }

  List<String> take() {
    final copy = [...calls];
    calls.clear();
    ids.clear();
    return copy;
  }
}

String _url(int n) => 'https://example.invalid/portada-$n.png';

Announcement _news(int id, {bool cover = true, String? url}) => Announcement(
  id: id,
  publishedAt: DateTime.utc(2026, 11, 1),
  coverUrl: cover ? (url ?? _url(id)) : null,
  coverImageId: cover ? 100 + id : null,
);

Future<void> _pumpCarousel(
  WidgetTester tester,
  List<Announcement> items,
  AnnouncementImagePrecache precache,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnnouncementsCarousel(
          announcements: items,
          onOpen: (_) {},
          precache: precache,
        ),
      ),
    ),
  );
  // Deja correr el cuadro con la precarga y los microtasks de la cadena.
  await tester.pump();
  await tester.pump();
}

/// Termina el pedido [index] y deja que la cadena avance.
Future<void> _complete(WidgetTester tester, _Gate gate, int index) async {
  gate.complete(index);
  await tester.pump();
  await tester.pump();
}

Future<void> _fail(WidgetTester tester, _Gate gate, int index) async {
  gate.fail(index);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('orden de la precarga del carrusel', () {
    // La visible, la siguiente, la anterior y las restantes de menor a mayor.
    test('con la primera visible', () {
      expect(carouselPrefetchOrder(visible: 0, count: 5), [0, 1, 2, 3, 4]);
    });

    test('con una del medio visible', () {
      expect(carouselPrefetchOrder(visible: 2, count: 5), [2, 3, 1, 0, 4]);
    });

    test('con la última visible', () {
      expect(carouselPrefetchOrder(visible: 4, count: 5), [4, 3, 0, 1, 2]);
    });

    test('con tres portadas y la del medio visible', () {
      expect(carouselPrefetchOrder(visible: 1, count: 3), [1, 2, 0]);
    });

    test('con una sola portada', () {
      expect(carouselPrefetchOrder(visible: 0, count: 1), [0]);
    });

    test('sin portadas', () {
      expect(carouselPrefetchOrder(visible: 0, count: 0), isEmpty);
    });
  });

  group('carrusel: precarga de a una', () {
    testWidgets('al llegar la lista solo se pide la portada visible', (
      tester,
    ) async {
      final gate = _Gate();

      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);

      expect(gate.calls, [_url(1)]);
      expect(gate.ids, [101]);
    });

    testWidgets('recién cuando termina una se pide la que sigue', (
      tester,
    ) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);

      await _complete(tester, gate, 0);
      expect(gate.calls, [_url(1), _url(2)]);
      expect(gate.ids, [101, 102]);

      await _complete(tester, gate, 1);
      expect(gate.calls, [_url(1), _url(2), _url(3)]);
      expect(gate.ids, [101, 102, 103]);

      await _complete(tester, gate, 2);
      expect(gate.calls, [_url(1), _url(2), _url(3)]);
    });

    testWidgets('si la visible falla igual sigue con las demás', (
      tester,
    ) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);

      await _fail(tester, gate, 0);
      expect(gate.calls, [_url(1), _url(2)]);

      await _complete(tester, gate, 1);
      expect(gate.calls, [_url(1), _url(2), _url(3)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un error en el medio no corta la cadena', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);

      await _complete(tester, gate, 0);
      await _fail(tester, gate, 1);

      expect(gate.calls, [_url(1), _url(2), _url(3)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el contexto se desmonta después de la primera no se pide '
        'ninguna más', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);
      expect(gate.calls, [_url(1)]);

      await tester.pumpWidget(const SizedBox.shrink());
      await _complete(tester, gate, 0);

      expect(gate.calls, [_url(1)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el contexto se desmonta a mitad de la cadena no se pide '
        'ninguna más', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);
      await _complete(tester, gate, 0);
      expect(gate.calls, [_url(1), _url(2)]);

      await tester.pumpWidget(const SizedBox.shrink());
      await _complete(tester, gate, 1);

      expect(gate.calls, [_url(1), _url(2)]);
    });

    testWidgets('cambiar de página mientras corre no reinicia la cadena ni '
        'pide en paralelo', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2), _news(3)], gate.call);

      await tester.tap(find.byTooltip('Novedad siguiente'));
      await tester.pumpAndSettle();
      expect(gate.calls, [_url(1)]);

      await _complete(tester, gate, 0);
      expect(gate.calls, [_url(1), _url(2)]);

      await tester.tap(find.byTooltip('Novedad siguiente'));
      await tester.pumpAndSettle();
      expect(gate.calls, [_url(1), _url(2)]);

      await _complete(tester, gate, 1);
      expect(gate.calls, [_url(1), _url(2), _url(3)]);
    });

    testWidgets('una novedad sin portada se salta', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [
        _news(1),
        _news(2, cover: false),
        _news(3),
      ], gate.call);

      await _complete(tester, gate, 0);

      expect(gate.calls, [_url(1), _url(3)]);
    });

    testWidgets('sin ninguna portada no pide nada', (tester) async {
      final gate = _Gate();

      await _pumpCarousel(tester, [
        _news(1, cover: false),
        _news(2, cover: false),
      ], gate.call);

      expect(gate.calls, isEmpty);
    });

    testWidgets('con una sola portada la pide una vez', (tester) async {
      final gate = _Gate();

      await _pumpCarousel(tester, [_news(5)], gate.call);
      await _complete(tester, gate, 0);

      expect(gate.calls, [_url(5)]);
    });

    testWidgets('si llega otra lista empieza una cadena nueva y corta la '
        'vieja', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1), _news(2)], gate.call);
      expect(gate.calls, [_url(1)]);

      await _pumpCarousel(tester, [_news(8), _news(9)], gate.call);
      expect(gate.calls, [_url(1), _url(8)]);

      // Termina la primera pedida de la lista vieja: no sigue con la 2.
      await _complete(tester, gate, 0);
      expect(gate.calls, [_url(1), _url(8)]);

      await _complete(tester, gate, 1);
      expect(gate.calls, [_url(1), _url(8), _url(9)]);
    });

    testWidgets('si la lista cambia solo de URL firmada también empieza de '
        'nuevo', (tester) async {
      final gate = _Gate();
      await _pumpCarousel(tester, [_news(1)], gate.call);
      await _complete(tester, gate, 0);

      await _pumpCarousel(tester, [
        _news(1, url: 'https://example.invalid/portada-1.png?firma=2'),
      ], gate.call);

      expect(gate.calls, [
        _url(1),
        'https://example.invalid/portada-1.png?firma=2',
      ]);
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
      _Instant recorder,
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
      final recorder = _Instant();

      await pumpGallery(tester, [image(1), image(2), image(3)], recorder);

      expect(recorder.ids, [2, 3]);
      expect(recorder.take(), [
        'https://example.invalid/imagen-2.png',
        'https://example.invalid/imagen-3.png',
      ]);
    });

    testWidgets('con una sola imagen no precarga nada', (tester) async {
      final recorder = _Instant();

      await pumpGallery(tester, [image(1)], recorder);

      expect(recorder.take(), isEmpty);
    });

    testWidgets('con cinco imágenes precarga las cuatro restantes', (
      tester,
    ) async {
      final recorder = _Instant();

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

    testWidgets('con el contexto desmontado el resultado ya está completo', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox(key: Key('a'))));
      final context = tester.element(find.byKey(const Key('a')));
      await tester.pumpWidget(const SizedBox.shrink());

      // Si se esperara algo que nunca termina, la cadena del carrusel se
      // colgaría: tiene que completarse enseguida.
      await precacheAnnouncementImage(
        context,
        announcementImageProvider(
          imageId: 1,
          url: 'https://example.invalid/x.png',
          cacheWidth: kAnnouncementImageCacheWidth,
        ),
      ).timeout(const Duration(seconds: 1));
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
