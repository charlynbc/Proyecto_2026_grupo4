import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que una barra de desplazamiento dibuja en este momento, tal como lo
/// pinta el `ScrollbarPainter`: sin tocar la pantalla ni pasar el mouse.
class DrawnScrollbar {
  const DrawnScrollbar({
    required this.track,
    required this.thumb,
    required this.trackColor,
    required this.thumbColor,
  });

  final Rect? track;
  final RRect? thumb;
  final Color? trackColor;
  final Color? thumbColor;

  /// Se dibujó el pulgar: la barra se ve.
  bool get isDrawn => thumb != null;

  /// El pulgar es más alto que ancho.
  bool get isVertical => thumb != null && thumb!.height > thumb!.width;
}

/// Una pasada de frames para que la barra aparezca sin ningún gesto: el
/// pulgar entra con una animación y se ubica recién después del primer
/// cuadro.
Future<void> settleScrollbars(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Todas las barras que hay montadas, dibujadas o no.
List<DrawnScrollbar> scrollbarsOf(WidgetTester tester) {
  final result = <DrawnScrollbar>[];
  for (final element in find.byType(CustomPaint).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderCustomPaint) continue;
    final painter = render.foregroundPainter;
    if (painter is! ScrollbarPainter) continue;
    final canvas = TestRecordingCanvas();
    painter.paint(canvas, render.size);
    Rect? track;
    RRect? thumb;
    Color? trackColor;
    Color? thumbColor;
    // El painter dibuja, en este orden: la pista (un rectángulo) con su borde
    // (una línea) y el pulgar (un rectángulo, redondeado si hay radio). Sin
    // pista, solo el pulgar.
    final calls = canvas.invocations.map((c) => c.invocation).toList();
    final hasTrack = calls.any((c) => c.memberName == #drawLine);
    final shapes = [
      for (final c in calls)
        if (c.memberName == #drawRect || c.memberName == #drawRRect) c,
    ];
    if (hasTrack && shapes.isNotEmpty) {
      track = shapes.first.positionalArguments[0] as Rect;
      trackColor = (shapes.first.positionalArguments[1] as Paint).color;
    }
    if (shapes.length > (hasTrack ? 1 : 0)) {
      final last = shapes.last;
      final shape = last.positionalArguments[0];
      thumb = shape is RRect
          ? shape
          : RRect.fromRectAndRadius(shape as Rect, Radius.zero);
      thumbColor = (last.positionalArguments[1] as Paint).color;
    }
    result.add(
      DrawnScrollbar(
        track: track,
        thumb: thumb,
        trackColor: trackColor,
        thumbColor: thumbColor,
      ),
    );
  }
  return result;
}

/// Las barras verticales que se están dibujando.
List<DrawnScrollbar> drawnVerticalScrollbars(WidgetTester tester) => [
  for (final bar in scrollbarsOf(tester))
    if (bar.isDrawn && bar.isVertical) bar,
];

/// Las barras horizontales que se están dibujando.
List<DrawnScrollbar> drawnHorizontalScrollbars(WidgetTester tester) => [
  for (final bar in scrollbarsOf(tester))
    if (bar.isDrawn && !bar.isVertical) bar,
];
