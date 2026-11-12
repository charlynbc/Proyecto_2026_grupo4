import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprueba que el mensaje de error [message] está en pantalla, se lee
/// entero (sin puntos suspensivos) y que no hubo ningún desborde.
///
/// Hay que cargar Roboto antes (`loadRoboto`): con la fuente de los tests el
/// ancho de los textos no es el real.
void expectErrorFits(WidgetTester tester, String message) {
  final finder = find.text(message);
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '"$message" se corta con puntos suspensivos',
  );
  expect(tester.takeException(), isNull);
}
