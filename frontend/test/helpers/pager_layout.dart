import 'package:flutter_test/flutter_test.dart';

/// Disposicion angosta del paginador: el texto de pagina arriba y, debajo,
/// Anterior y Siguiente lado a lado, todo dentro de [screenWidth].
void expectNarrowPager(
  WidgetTester tester, {
  required Finder label,
  required Finder previous,
  required Finder next,
  double screenWidth = 320,
}) {
  final labelRect = tester.getRect(label);
  final previousRect = tester.getRect(previous);
  final nextRect = tester.getRect(next);
  expect(
    labelRect.bottom,
    lessThanOrEqualTo(previousRect.top),
    reason: 'el texto de pagina va arriba de los botones',
  );
  expect(
    nextRect.top,
    previousRect.top,
    reason: 'Anterior y Siguiente van en la misma fila',
  );
  expect(previousRect.right, lessThan(nextRect.left));
  expect(previousRect.left, greaterThanOrEqualTo(0));
  expect(nextRect.right, lessThanOrEqualTo(screenWidth));
  expect(tester.takeException(), isNull);
}

/// Disposicion ancha: Anterior, el texto y Siguiente en una sola fila.
void expectWidePager(
  WidgetTester tester, {
  required Finder label,
  required Finder previous,
  required Finder next,
}) {
  final labelRect = tester.getRect(label);
  final previousRect = tester.getRect(previous);
  final nextRect = tester.getRect(next);
  expect(previousRect.center.dy, closeTo(labelRect.center.dy, 1));
  expect(nextRect.center.dy, closeTo(labelRect.center.dy, 1));
  expect(previousRect.right, lessThanOrEqualTo(labelRect.left));
  expect(labelRect.right, lessThanOrEqualTo(nextRect.left));
  expect(tester.takeException(), isNull);
}
