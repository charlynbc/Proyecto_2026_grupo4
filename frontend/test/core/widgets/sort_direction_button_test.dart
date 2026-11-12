import 'package:agenda_medica/core/widgets/sort_direction_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool ascending,
  required VoidCallback onPressed,
  Key? key,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SortDirectionButton(
        key: key,
        ascending: ascending,
        onPressed: onPressed,
      ),
    ),
  ),
);

void main() {
  testWidgets('ascendente muestra el texto y la flecha hacia arriba', (
    tester,
  ) async {
    await _pump(tester, ascending: true, onPressed: () {});

    expect(find.text('Ascendente'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.text('Descendente'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('descendente muestra el texto y la flecha hacia abajo', (
    tester,
  ) async {
    await _pump(tester, ascending: false, onPressed: () {});

    expect(find.text('Descendente'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('Ascendente'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
  });

  testWidgets('al tocarlo llama al callback una sola vez', (tester) async {
    var taps = 0;
    await _pump(tester, ascending: true, onPressed: () => taps++);

    await tester.tap(find.byType(TextButton));

    expect(taps, 1);
  });

  testWidgets('la key que se le pasa lo identifica y contiene un TextButton', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      ascending: true,
      onPressed: () => taps++,
      key: const Key('sort-direction'),
    );

    final byKey = find.byKey(const Key('sort-direction'));
    expect(byKey, findsOneWidget);
    expect(
      find.descendant(of: byKey, matching: find.byType(TextButton)),
      findsOneWidget,
    );

    await tester.tap(byKey);

    expect(taps, 1);
  });
}
