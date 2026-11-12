import 'package:agenda_medica/features/medico/widgets/cancel_with_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/error_text_fit.dart';
import '../../helpers/load_roboto.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  Size size = const Size(900, 800),
  Future<String> Function(String reason)? onConfirm,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCancelWithReasonDialog<String>(
            context: context,
            title: 'Cancelar el turno',
            body: 'Se cancelan todas las consultas agendadas.',
            confirmLabel: 'Cancelar turno',
            onConfirm: onConfirm ?? (reason) async => reason,
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Finder get _confirm => find.widgetWithText(FilledButton, 'Cancelar turno');

void main() {
  setUpAll(loadRoboto);

  testWidgets('sin motivo avisa y no confirma', (tester) async {
    var confirmed = 0;
    await _openDialog(
      tester,
      onConfirm: (reason) async {
        confirmed++;
        return reason;
      },
    );

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(find.text('Escribí el motivo de la cancelación.'), findsOneWidget);
    expect(confirmed, 0);
    expect(find.text('Cancelar el turno'), findsOneWidget);
  });

  testWidgets('a 320 px el mensaje del motivo vacío se lee entero', (
    tester,
  ) async {
    await _openDialog(tester, size: const Size(320, 700));

    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expectErrorFits(tester, 'Escribí el motivo de la cancelación.');
  });
}
