import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_test/flutter_test.dart';

// Valores escritos a mano a propósito: no se calculan con las constantes de
// tool/generar_iconos.dart, así un cambio ahí que rompa algo se nota.

const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
const _launcherSizes = [48, 72, 96, 144, 192];
const _foregroundSizes = [108, 162, 216, 324, 432];

/// Hueso de la paleta (#F4EEE2), sin alfa.
const _bone = (r: 244, g: 238, b: 226);

/// Dorado del logo (#E0A33C) y azul de Flutter (#0175C2).
const _gold = (r: 224, g: 163, b: 60);
const _flutterBlue = (r: 1, g: 117, b: 194);

/// Diferencia máxima por canal para dar un píxel por "cercano" a un color.
const _tolerance = 30;

// Android: la zona segura es un círculo de 66 dp en el lienzo de 108 dp.
const _androidSafeRadius = 33 / 108;

const _description = 'Sistema de reserva de consultas médicas.';

const _res = 'android/app/src/main/res';

String _launcherPath(String density) => '$_res/mipmap-$density/ic_launcher.png';

String _foregroundPath(String density) =>
    '$_res/mipmap-$density/ic_launcher_foreground.png';

class _Pixels {
  _Pixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  int r(int x, int y) => rgba[(y * width + x) * 4];
  int g(int x, int y) => rgba[(y * width + x) * 4 + 1];
  int b(int x, int y) => rgba[(y * width + x) * 4 + 2];
  int a(int x, int y) => rgba[(y * width + x) * 4 + 3];

  bool isBone(int x, int y) =>
      r(x, y) == _bone.r &&
      g(x, y) == _bone.g &&
      b(x, y) == _bone.b &&
      a(x, y) == 255;

  int countNear(({int r, int g, int b}) color) {
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (a(x, y) < 128) continue;
        if ((r(x, y) - color.r).abs() <= _tolerance &&
            (g(x, y) - color.g).abs() <= _tolerance &&
            (b(x, y) - color.b).abs() <= _tolerance) {
          count++;
        }
      }
    }
    return count;
  }

  /// Distancia del centro del píxel al centro de la imagen, en lados.
  double distanceInSides(int x, int y) {
    final dx = x + 0.5 - width / 2;
    final dy = y + 0.5 - height / 2;
    return math.sqrt(dx * dx + dy * dy) / width;
  }
}

/// Lee un PNG. Hay que llamarlo dentro de `tester.runAsync`.
Future<_Pixels> _load(String path) async {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'falta $path');
  final image = await decodeImageFromList(file.readAsBytesSync());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Pixels(image.width, image.height, data!.buffer.asUint8List());
}

/// Tamaño de un PNG leyendo su encabezado.
({int w, int h}) _pngSize(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'falta $path');
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  return (w: bytes.getUint32(16), h: bytes.getUint32(20));
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  // Archivo, lado esperado, y si lleva fondo hueso opaco (true) o es
  // transparente (false).
  final all = <({String path, int side, bool opaque})>[
    (path: 'web/favicon.png', side: 48, opaque: false),
    (path: 'web/icons/Icon-192.png', side: 192, opaque: true),
    (path: 'web/icons/Icon-512.png', side: 512, opaque: true),
    (path: 'web/icons/Icon-maskable-192.png', side: 192, opaque: true),
    (path: 'web/icons/Icon-maskable-512.png', side: 512, opaque: true),
    for (var i = 0; i < 5; i++)
      (
        path: _launcherPath(_densities[i]),
        side: _launcherSizes[i],
        opaque: true,
      ),
    for (var i = 0; i < 5; i++)
      (
        path: _foregroundPath(_densities[i]),
        side: _foregroundSizes[i],
        opaque: false,
      ),
  ];

  group('1. dimensiones', () {
    for (final icon in all) {
      test(icon.path, () {
        final size = _pngSize(icon.path);
        expect(size.w, icon.side);
        expect(size.h, icon.side);
      });
    }
  });

  group('2. esquina superior izquierda', () {
    for (final icon in all) {
      testWidgets(icon.path, (tester) async {
        await tester.runAsync(() async {
          final px = await _load(icon.path);
          if (icon.opaque) {
            expect(
              (px.r(0, 0), px.g(0, 0), px.b(0, 0), px.a(0, 0)),
              (244, 238, 226, 255),
            );
          } else {
            expect(px.a(0, 0), 0);
          }
        });
      });
    }
  });

  group('3. el logo está y no queda el de Flutter', () {
    for (final icon in all) {
      testWidgets(icon.path, (tester) async {
        await tester.runAsync(() async {
          final px = await _load(icon.path);
          // El dorado es el aro y los rayos, líneas finas: a 48 px casi todo
          // queda mezclado con el fondo. Medido: 6 píxeles dorados en el
          // ic_launcher de mdpi (0,26 % de 48 x 48) y 28 en el de hdpi. Por eso
          // el mínimo es 50 o el 0,1 % del área, el menor de los dos.
          final minimum = math.min(50, (px.width * px.height * 0.001).ceil());
          expect(px.countNear(_gold), greaterThanOrEqualTo(minimum));
          expect(px.countNear(_flutterBlue), 0);
        });
      });
    }
  });

  group('4. zona segura', () {
    final maskable = [
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ];
    for (final path in maskable) {
      testWidgets('$path fuera del círculo de 40 % es hueso', (tester) async {
        await tester.runAsync(() async {
          final px = await _load(path);
          var outside = 0;
          var notBone = 0;
          for (var y = 0; y < px.height; y++) {
            for (var x = 0; x < px.width; x++) {
              if (px.distanceInSides(x, y) <= 0.4) continue;
              outside++;
              if (!px.isBone(x, y)) notBone++;
            }
          }
          expect(outside, greaterThan(0));
          expect(notBone, 0);
        });
      });
    }
    for (final density in _densities) {
      final path = _foregroundPath(density);
      testWidgets('$path fuera del círculo de 66 dp es transparente', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final px = await _load(path);
          var outside = 0;
          var visible = 0;
          for (var y = 0; y < px.height; y++) {
            for (var x = 0; x < px.width; x++) {
              if (px.distanceInSides(x, y) <= _androidSafeRadius) continue;
              outside++;
              if (px.a(x, y) != 0) visible++;
            }
          }
          expect(outside, greaterThan(0));
          expect(visible, 0);
        });
      });
    }
  });

  group('5. manifest.json e index.html', () {
    test('colores, descripción e íconos del manifest', () {
      final manifest = jsonDecode(_read('web/manifest.json')) as Map;
      expect(manifest['theme_color'], '#3F6FB0');
      expect(manifest['background_color'], '#F4EEE2');
      expect(manifest['description'], _description);
      expect(manifest['description'], isNot(contains('Flutter')));
      final icons = manifest['icons'] as List;
      expect(icons, isNotEmpty);
      for (final icon in icons.cast<Map>()) {
        final src = 'web/${icon['src']}';
        final size = _pngSize(src);
        expect(icon['sizes'], '${size.w}x${size.h}', reason: src);
      }
    });

    test('meta description de index.html', () {
      final html = _read('web/index.html');
      final match = RegExp(r'<meta name="description" content="([^"]*)"')
          .firstMatch(html);
      expect(match, isNotNull);
      expect(match!.group(1), _description);
      expect(match.group(1), isNot(contains('Flutter')));
    });
  });

  group('6. Android', () {
    test('android:icon apunta a @mipmap/ic_launcher', () {
      final xml = _read('android/app/src/main/AndroidManifest.xml');
      expect(xml, contains('android:icon="@mipmap/ic_launcher"'));
    });

    test('ícono adaptativo', () {
      const path = '$_res/mipmap-anydpi-v26/ic_launcher.xml';
      expect(File(path).existsSync(), isTrue, reason: 'falta $path');
      final xml = _read(path);
      expect(xml, contains('<adaptive-icon'));
      expect(
        xml,
        contains(
          '<background android:drawable="@color/ic_launcher_background"',
        ),
      );
      expect(
        xml,
        contains(
          '<foreground android:drawable="@mipmap/ic_launcher_foreground"',
        ),
      );
    });

    test('color de fondo del ícono adaptativo es el hueso', () {
      const path = '$_res/values/ic_launcher_background.xml';
      expect(File(path).existsSync(), isTrue, reason: 'falta $path');
      expect(
        _read(path).toLowerCase(),
        contains('<color name="ic_launcher_background">#f4eee2</color>'),
      );
    });

    test('existen los 5 ic_launcher_foreground.png', () {
      for (final density in _densities) {
        expect(
          File(_foregroundPath(density)).existsSync(),
          isTrue,
          reason: 'falta ${_foregroundPath(density)}',
        );
      }
    });
  });

  test('7. index.html apunta a los íconos que existen', () {
    final html = _read('web/index.html');
    expect(
      html,
      contains('<link rel="apple-touch-icon" href="icons/Icon-192.png">'),
    );
    expect(html, contains('<link rel="icon"'));
    expect(html, contains('href="favicon.png"'));
    expect(File('web/icons/Icon-192.png').existsSync(), isTrue);
    expect(File('web/favicon.png').existsSync(), isTrue);
  });
}
