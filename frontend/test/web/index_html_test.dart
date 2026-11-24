import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Comprueba el texto de `web/index.html` (la prueba corre desde `frontend/`).
/// No ejecuta el JavaScript: eso lo hace `test_web/legacy_hash.test.mjs` con
/// Node. Acá solo se cuida que el script esté y que corra antes de Flutter.
void main() {
  final html = File('web/index.html').readAsStringSync();

  test('el script de compatibilidad con # está entre sus marcadores', () {
    final inicio = html.indexOf('<!-- legacy-hash:inicio -->');
    final fin = html.indexOf('<!-- legacy-hash:fin -->');

    expect(inicio, isNonNegative);
    expect(fin, greaterThan(inicio));
    final bloque = html.substring(inicio, fin);
    expect(bloque, contains('<script>'));
    expect(bloque, contains('history.replaceState'));
  });

  test('el script corre antes de flutter_bootstrap.js', () {
    final fin = html.indexOf('<!-- legacy-hash:fin -->');
    // La etiqueta real, no el comentario que nombra el archivo.
    final bootstrap = html.indexOf('<script src="flutter_bootstrap.js"');

    expect(fin, isNonNegative);
    expect(bootstrap, isNonNegative);
    expect(fin, lessThan(bootstrap));
  });

  test('el script es síncrono: sin async, defer ni src (va en línea)', () {
    final inicio = html.indexOf('<!-- legacy-hash:inicio -->');
    final fin = html.indexOf('<!-- legacy-hash:fin -->');
    final etiqueta = RegExp(r'<script([^>]*)>')
        .firstMatch(html.substring(inicio, fin));

    expect(etiqueta, isNotNull);
    // Una etiqueta <script> pelada: cualquier atributo la haría asíncrona o externa.
    expect(etiqueta!.group(1)!.trim(), isEmpty);
  });

  test('el <base href> sigue ahí', () {
    expect(html, contains('<base href="\$FLUTTER_BASE_HREF">'));
  });
}
