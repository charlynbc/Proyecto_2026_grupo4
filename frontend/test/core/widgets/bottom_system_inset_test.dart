import 'package:agenda_medica/core/widgets/bottom_system_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _childKey = Key('child');

/// Monta [child] bajo un `MediaQuery` de 400 x 800 con el padding indicado
/// (los valores en dp, escritos a mano en cada test).
Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  // El tamaño real de la vista es el que manda en el layout.
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF123456)),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
        ),
        child: BottomSystemInset(child: child),
      ),
    ),
  );
}

void main() {
  const fill = SizedBox.expand(key: _childKey);

  testWidgets('reserva el padding inferior de 48 debajo del hijo', (
    tester,
  ) async {
    await _pump(
      tester,
      child: fill,
      padding: const EdgeInsets.only(bottom: 48),
    );

    expect(tester.getBottomLeft(find.byKey(_childKey)).dy, 752);
    expect(tester.getSize(find.byKey(_childKey)).height, 752);
  });

  testWidgets('con padding inferior 0 el hijo ocupa toda la pantalla', (
    tester,
  ) async {
    await _pump(tester, child: fill);

    expect(tester.getBottomLeft(find.byKey(_childKey)).dy, 800);
    expect(tester.getSize(find.byKey(_childKey)).height, 800);
  });

  testWidgets('con el teclado abierto no suma nada: lo maneja el Scaffold', (
    tester,
  ) async {
    await _pump(
      tester,
      child: fill,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    expect(tester.getBottomLeft(find.byKey(_childKey)).dy, 800);
  });

  testWidgets('el hijo ve padding inferior 0 y conserva los otros lados', (
    tester,
  ) async {
    late EdgeInsets inner;
    await _pump(
      tester,
      padding: const EdgeInsets.fromLTRB(5, 24, 7, 48),
      child: Builder(
        builder: (context) {
          inner = MediaQuery.paddingOf(context);
          return const SizedBox.expand();
        },
      ),
    );

    expect(inner, const EdgeInsets.fromLTRB(5, 24, 7, 0));
  });

  testWidgets('una SafeArea adentro no suma el margen otra vez', (
    tester,
  ) async {
    await _pump(
      tester,
      padding: const EdgeInsets.only(bottom: 48),
      child: const SafeArea(child: SizedBox.expand(key: _childKey)),
    );

    expect(tester.getBottomLeft(find.byKey(_childKey)).dy, 752);
  });

  testWidgets('la franja reservada se pinta con el fondo del tema', (
    tester,
  ) async {
    await _pump(
      tester,
      child: fill,
      padding: const EdgeInsets.only(bottom: 48),
    );

    final strip = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(BottomSystemInset),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(strip.color, const Color(0xFF123456));
  });
}
