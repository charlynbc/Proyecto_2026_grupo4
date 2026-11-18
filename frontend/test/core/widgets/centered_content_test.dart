import 'package:agenda_medica/core/widgets/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  Alignment? alignment,
  double width = 1000,
  double height = 800,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: alignment == null
            ? const CenteredContent(
                maxWidth: 400,
                padding: EdgeInsets.all(10),
                child: SizedBox(key: Key('box'), width: 400, height: 100),
              )
            : CenteredContent(
                maxWidth: 400,
                padding: const EdgeInsets.all(10),
                alignment: alignment,
                child: const SizedBox(key: Key('box'), width: 400, height: 100),
              ),
      ),
    ),
  );
}

void main() {
  const box = Key('box');

  testWidgets('por defecto centra en vertical y en horizontal, como siempre', (
    tester,
  ) async {
    await _pump(tester);

    final rect = tester.getRect(find.byKey(box));
    // Alto 800: contenido de 100 + 10 de margen arriba y abajo = 120, a 340.
    expect(rect.top, 350);
    // Ancho 1000: contenido de 400 + 10 de margen a cada lado = 420, a 290.
    expect(rect.left, 300);
    expect(rect.width, 400);
  });

  testWidgets('con topCenter queda arriba y centrado en horizontal', (
    tester,
  ) async {
    await _pump(tester, alignment: Alignment.topCenter);

    final rect = tester.getRect(find.byKey(box));
    expect(rect.top, 10);
    expect(rect.left, 300);
    expect(rect.width, 400);
  });

  testWidgets('con topCenter el contenido no se mueve si crece', (
    tester,
  ) async {
    await _pump(tester, alignment: Alignment.topCenter);
    expect(tester.getRect(find.byKey(box)).top, 10);

    tester.view.physicalSize = const Size(1000, 300);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(box)).top, 10);
  });

  testWidgets('el contenido más alto que la pantalla se desplaza', (
    tester,
  ) async {
    await _pump(tester, alignment: Alignment.topCenter, height: 80);

    expect(tester.getRect(find.byKey(box)).top, 10);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(box)).top, -30);
  });
}
