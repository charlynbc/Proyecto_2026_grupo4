// Genera los íconos de la app (web y Android) a partir de
// `assets/images/logo.svg`, sin instalar nada: dibuja el SVG con `flutter_svg`
// dentro de un test de Flutter y guarda el resultado como PNG.
//
// Se corre desde frontend/:
//
//   flutter test tool/generar_iconos.dart
//
// No vive bajo test/, así que `flutter test` a secas no lo ejecuta. Dos
// corridas dejan los mismos bytes: los PNG solo se reescriben si cambian.
//
// El logo tiene unos 50 px de margen transparente por lado. El script mide
// la caja del dibujo y la escala, así el porcentaje de cada ícono se
// calcula sobre el dibujo y no sobre el lienzo del SVG.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hueso de la paleta (`_kBone` en `lib/core/theme/app_theme.dart`).
const _kBone = Color(0xFFF4EEE2);

/// Fracción del lado que ocupa el dibujo en cada tipo de ícono.
const _kFaviconFraction = 1.0;
const _kIconFraction = 0.8;
const _kMaskableFraction = 0.6;
const _kForegroundFraction = 0.6;

const _kFaviconSize = 48;
const _kWebIconSizes = [192, 512];

/// Lado de cada `ic_launcher.png` por densidad.
const _kLauncherSizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// Lado de cada `ic_launcher_foreground.png` por densidad (108 dp).
const _kForegroundSizes = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

const _kLogoPath = 'assets/images/logo.svg';
const _kRes = 'android/app/src/main/res';

/// Lado del lienzo del SVG (su `viewBox` es de 512 x 512).
const _kViewBox = 512.0;

class _ContentBox {
  const _ContentBox(this.centerX, this.centerY, this.side);

  final double centerX;
  final double centerY;
  final double side;
}

Future<ByteData> _render(
  WidgetTester tester,
  String svg, {
  required int side,
  required double fraction,
  required _ContentBox box,
  Color? background,
}) async {
  final scale = side * fraction / box.side;
  final logoSide = _kViewBox * scale;
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundaryKey,
          child: Container(
            width: side.toDouble(),
            height: side.toDouble(),
            color: background,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: side / 2 - box.centerX * scale,
                  top: side / 2 - box.centerY * scale,
                  width: logoSide,
                  height: logoSide,
                  child: SvgPicture.string(svg),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    return (await image.toByteData(format: ui.ImageByteFormat.png))!;
  }))!;
}

/// Caja de los píxeles no transparentes del logo dibujado a 512 px, que es
/// 1 px por unidad del `viewBox`.
Future<_ContentBox> _measure(WidgetTester tester, String svg) async {
  const full = _ContentBox(_kViewBox / 2, _kViewBox / 2, _kViewBox);
  final png = await _render(
    tester,
    svg,
    side: _kViewBox.toInt(),
    fraction: 1,
    box: full,
  );
  final raw = (await tester.runAsync(() async {
    final image = await decodeImageFromList(png.buffer.asUint8List());
    return (await image.toByteData())!;
  }))!;
  const width = 512;
  var minX = width, minY = width, maxX = -1, maxY = -1;
  for (var y = 0; y < width; y++) {
    for (var x = 0; x < width; x++) {
      if (raw.getUint8((y * width + x) * 4 + 3) == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  expect(maxX, greaterThan(minX), reason: 'el logo se dibujó vacío');
  final boxWidth = maxX - minX + 1;
  final boxHeight = maxY - minY + 1;
  return _ContentBox(
    (minX + maxX + 1) / 2,
    (minY + maxY + 1) / 2,
    (boxWidth > boxHeight ? boxWidth : boxHeight).toDouble(),
  );
}

/// Escribe [png] solo si cambia, para no tocar archivos que ya están bien.
void _write(String path, ByteData png) {
  final bytes = png.buffer.asUint8List();
  final file = File(path);
  if (file.existsSync() && _sameBytes(file.readAsBytesSync(), bytes)) {
    stdout.writeln('Sin cambios  $path');
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('Actualizado  $path');
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  testWidgets('genera los íconos de la app', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final svg = File(_kLogoPath).readAsStringSync();
    final box = await _measure(tester, svg);
    stdout.writeln(
      'Caja del logo: centro (${box.centerX}, ${box.centerY}), '
      'lado ${box.side}',
    );

    Future<void> generate(
      String path,
      int side,
      double fraction, {
      Color? background,
    }) async {
      final png = await _render(
        tester,
        svg,
        side: side,
        fraction: fraction,
        box: box,
        background: background,
      );
      _write(path, png);
    }

    await generate('web/favicon.png', _kFaviconSize, _kFaviconFraction);
    for (final size in _kWebIconSizes) {
      await generate(
        'web/icons/Icon-$size.png',
        size,
        _kIconFraction,
        background: _kBone,
      );
      await generate(
        'web/icons/Icon-maskable-$size.png',
        size,
        _kMaskableFraction,
        background: _kBone,
      );
    }
    for (final entry in _kLauncherSizes.entries) {
      await generate(
        '$_kRes/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        _kIconFraction,
        background: _kBone,
      );
    }
    for (final entry in _kForegroundSizes.entries) {
      await generate(
        '$_kRes/mipmap-${entry.key}/ic_launcher_foreground.png',
        entry.value,
        _kForegroundFraction,
      );
    }
  });
}
