import 'dart:ui' as ui;

import 'package:agenda_medica/features/novedades/announcement_image_provider.dart';
import 'package:agenda_medica/features/novedades/announcement_images.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la ruedita sobre una imagen cargada desplaza la página sin ampliarla',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      // Imagen ya decodificada: probar la interacción sin descargar de la red.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 200, 100),
        ui.Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(200, 100));
      picture.dispose();
      const url = 'https://example.invalid/imagen-cargada.png';
      // La caché se indexa por la clave que devuelve `obtainKey`.
      final key = await const AnnouncementImageProvider(
        imageId: 1,
        url: url,
        cacheWidth: kAnnouncementImageCacheWidth,
      ).obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: image!)),
        ),
      );
      addTearDown(PaintingBinding.instance.imageCache.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  AnnouncementGallery(
                    images: const [
                      AnnouncementImage(id: 1, order: 0, url: url),
                    ],
                    onReload: () {},
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rawImage = find.byType(RawImage);
      final rendered = tester.renderObject<RenderImage>(rawImage);
      expect(rendered.image!.width, 200);
      final initialScale = rendered.getTransformTo(null).getMaxScaleOnAxis();
      final initialSize = rendered.size;
      final center = tester.getCenter(rawImage);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -200),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        rendered.getTransformTo(null).getMaxScaleOnAxis(),
        closeTo(initialScale, 0.001),
      );
      expect(rendered.size, initialSize);

      await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 200)),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(
        rendered.getTransformTo(null).getMaxScaleOnAxis(),
        closeTo(initialScale, 0.001),
      );
      expect(rendered.size, initialSize);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
