import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un elemento del manifiesto con lo mínimo para estas pruebas.
class _Element {
  _Element(this.name, this.attributes);

  final String name;
  final Map<String, String> attributes;
  final List<_Element> children = [];

  Iterable<_Element> named(String tag) => children.where((e) => e.name == tag);

  String? attr(String key) => attributes['android:$key'];
}

/// Lee el XML con una comprobación simple de etiquetas balanceadas (el paquete
/// `xml` es solo una dependencia transitiva del proyecto, no directa). Tira
/// `FormatException` si una etiqueta se cierra mal o queda abierta.
_Element _parse(String source) {
  final text = source
      .replaceAll(RegExp(r'<\?.*?\?>', dotAll: true), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final tag = RegExp(r'<(/?)([A-Za-z][\w.:-]*)((?:[^>"]|"[^"]*")*?)(/?)>');
  final attribute = RegExp(r'([\w.:-]+)\s*=\s*"([^"]*)"');
  final root = _Element('#root', {});
  final stack = <_Element>[root];
  var last = 0;
  for (final match in tag.allMatches(text)) {
    if (text.substring(last, match.start).trim().isNotEmpty) {
      throw FormatException('Texto suelto fuera de una etiqueta', text, last);
    }
    last = match.end;
    final name = match.group(2)!;
    if (match.group(1) == '/') {
      if (stack.length == 1 || stack.last.name != name) {
        throw FormatException('Cierre mal puesto: $name', text, match.start);
      }
      stack.removeLast();
      continue;
    }
    final attributes = {
      for (final a in attribute.allMatches(match.group(3)!))
        a.group(1)!: a.group(2)!,
    };
    final element = _Element(name, attributes);
    stack.last.children.add(element);
    if (match.group(4) != '/') stack.add(element);
  }
  if (text.substring(last).trim().isNotEmpty || stack.length != 1) {
    throw FormatException('Quedó una etiqueta sin cerrar', text, last);
  }
  return root.children.single;
}

/// Comprueba el texto de `android/app/src/main/AndroidManifest.xml` (la prueba
/// corre desde `frontend/`): los enlaces de los correos abren la app en Android
/// (App Links con verificación automática).
void main() {
  final source = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  _Element manifest() => _parse(source);

  List<_Element> filters() => manifest()
      .named('application')
      .single
      .named('activity')
      .singleWhere((a) => a.attr('name') == '.MainActivity')
      .named('intent-filter')
      .toList();

  bool hasAction(_Element filter, String action) =>
      filter.named('action').any((a) => a.attr('name') == action);

  bool hasCategory(_Element filter, String category) =>
      filter.named('category').any((c) => c.attr('name') == category);

  _Element appLinksFilter() =>
      filters().singleWhere((f) => f.attr('autoVerify') == 'true');

  test('el manifiesto es XML bien formado', () {
    expect(manifest().name, 'manifest');
    expect(manifest().named('application'), hasLength(1));
  });

  test('hay un solo filtro de enlaces verificados, con autoVerify', () {
    expect(filters().where((f) => f.attr('autoVerify') != null), hasLength(1));
    expect(appLinksFilter().attr('autoVerify'), 'true');
  });

  test('el filtro de enlaces tiene la action VIEW', () {
    expect(hasAction(appLinksFilter(), 'android.intent.action.VIEW'), isTrue);
  });

  test('el filtro de enlaces tiene las categorías DEFAULT y BROWSABLE', () {
    final filter = appLinksFilter();

    expect(hasCategory(filter, 'android.intent.category.DEFAULT'), isTrue);
    expect(hasCategory(filter, 'android.intent.category.BROWSABLE'), isTrue);
  });

  test('el filtro de enlaces es https en medicaoriental.vip', () {
    final data = appLinksFilter().named('data').toList();

    expect(data.map((d) => d.attr('scheme')).whereType<String>(), ['https']);
    expect(data.map((d) => d.attr('host')).whereType<String>(), [
      'medicaoriental.vip',
    ]);
  });

  test('el filtro de enlaces cubre las tres rutas de los correos', () {
    final prefixes = appLinksFilter()
        .named('data')
        .map((d) => d.attr('pathPrefix'))
        .whereType<String>()
        .toList();

    expect(prefixes, ['/primer-ingreso', '/recuperacion', '/cambio-correo']);
  });

  test('el filtro MAIN/LAUNCHER sigue y no lleva autoVerify', () {
    final launcher = filters().singleWhere(
      (f) => hasAction(f, 'android.intent.action.MAIN'),
    );

    expect(hasCategory(launcher, 'android.intent.category.LAUNCHER'), isTrue);
    expect(launcher.attr('autoVerify'), isNull);
  });

  test('el filtro de enlaces va después del MAIN/LAUNCHER', () {
    final all = filters();

    expect(all, hasLength(2));
    expect(hasAction(all.first, 'android.intent.action.MAIN'), isTrue);
    expect(all.last.attr('autoVerify'), 'true');
  });
}
