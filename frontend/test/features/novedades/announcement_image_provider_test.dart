import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:agenda_medica/features/novedades/announcement_image_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un PNG de 1x1 píxel.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Cuenta cuántas veces se pide la imagen "a la red".
class _Network {
  int requests = 0;
  bool fail = false;
}

/// Un origen que no usa la red: devuelve el PNG de 1x1 y cuenta las peticiones.
class _FakeSource extends ImageProvider<_FakeSource> {
  _FakeSource(this.url, this.network);

  final String url;
  final _Network network;

  @override
  Future<_FakeSource> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_FakeSource key, ImageDecoderCallback decode) {
    network.requests++;
    if (network.fail) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(Exception('Sin red')),
      );
    }
    return MultiFrameImageStreamCompleter(
      codec: ui.ImmutableBuffer.fromUint8List(_png).then(decode),
      scale: 1,
    );
  }

  @override
  bool operator ==(Object other) => other is _FakeSource && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

AnnouncementImageProvider _provider(
  int imageId,
  String url,
  _Network network, {
  int? cacheWidth = 1280,
}) => AnnouncementImageProvider(
  imageId: imageId,
  url: url,
  cacheWidth: cacheWidth,
  sourceBuilder: (url) => _FakeSource(url, network),
);

/// Carga [provider] por la caché global de imágenes y espera el resultado.
Future<ImageInfo> _load(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info);
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  group('igualdad', () {
    test('el mismo id y ancho son iguales aunque cambie la URL firmada', () {
      final network = _Network();
      final a = _provider(5, 'https://example.invalid/a?firma=1', network);
      final b = _provider(5, 'https://example.invalid/a?firma=2', network);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('con otro id de imagen no son iguales', () {
      final network = _Network();
      final a = _provider(5, 'https://example.invalid/a', network);
      final b = _provider(6, 'https://example.invalid/a', network);

      expect(a == b, isFalse);
    });

    test(
      'dos imágenes de la misma novedad con ids distintos no son iguales',
      () {
        final network = _Network();
        // Una novedad puede tener hasta cinco imágenes: cada una tiene su id.
        final first = _provider(11, 'https://example.invalid/n/1', network);
        final second = _provider(12, 'https://example.invalid/n/2', network);

        expect(first == second, isFalse);
      },
    );

    test('con otro ancho de decodificación no son iguales', () {
      final network = _Network();
      final a = _provider(5, 'https://example.invalid/a', network);
      final b = _provider(
        5,
        'https://example.invalid/a',
        network,
        cacheWidth: 640,
      );

      expect(a == b, isFalse);
    });

    test('con y sin ancho de decodificación no son iguales', () {
      final network = _Network();
      final a = _provider(5, 'https://example.invalid/a', network);
      final b = _provider(
        5,
        'https://example.invalid/a',
        network,
        cacheWidth: null,
      );

      expect(a == b, isFalse);
    });
  });

  group('caché de imágenes', () {
    setUp(() {
      imageCache.clear();
      imageCache.clearLiveImages();
    });
    tearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
    });

    testWidgets('el mismo id con otra URL deja una sola entrada y una sola '
        'petición', (tester) async {
      final network = _Network();

      await tester.runAsync(() async {
        await _load(_provider(5, 'https://example.invalid/a?firma=1', network));
        await _load(_provider(5, 'https://example.invalid/a?firma=2', network));
      });

      expect(imageCache.currentSize, 1);
      expect(network.requests, 1);
    });

    testWidgets('otro id es otra entrada y otra petición', (tester) async {
      final network = _Network();

      await tester.runAsync(() async {
        await _load(_provider(5, 'https://example.invalid/a', network));
        await _load(_provider(6, 'https://example.invalid/a', network));
      });

      expect(imageCache.currentSize, 2);
      expect(network.requests, 2);
    });

    testWidgets('otro ancho es otra entrada y otra petición', (tester) async {
      final network = _Network();

      await tester.runAsync(() async {
        await _load(_provider(5, 'https://example.invalid/a', network));
        await _load(
          _provider(5, 'https://example.invalid/a', network, cacheWidth: 640),
        );
      });

      expect(imageCache.currentSize, 2);
      expect(network.requests, 2);
    });

    testWidgets(
      'una descarga fallida no queda en la caché: se vuelve a pedir',
      (tester) async {
        final network = _Network()..fail = true;

        await tester.runAsync(() async {
          await expectLater(
            _load(_provider(5, 'https://example.invalid/a', network)),
            throwsException,
          );
          await Future<void>.delayed(Duration.zero);
          network.fail = false;
          final info = await _load(
            _provider(5, 'https://example.invalid/a?firma=2', network),
          );
          expect(info.image.width, 1);
        });

        expect(network.requests, 2);
        expect(imageCache.currentSize, 1);
      },
    );

    testWidgets('no agranda una imagen más chica que el ancho pedido', (
      tester,
    ) async {
      final network = _Network();

      final info = await tester.runAsync(
        () => _load(_provider(5, 'https://example.invalid/a', network)),
      );

      expect(info!.image.width, 1);
      expect(info.image.height, 1);
    });
  });
}
