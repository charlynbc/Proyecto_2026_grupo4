import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/core/widgets/ui_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

// Los mensajes y tooltips se escriben a mano, no con constantes del código.
const String _badFormat =
    'Escribí la hora como HH:mm, de 00:00 a 23:59, por ejemplo 18:30.';
const String _pickerTooltip = 'Elegir la hora de prueba';
const String _pickerHelp = 'Elegí la hora de prueba';
const String _clearTooltip = 'Borrar la hora';

class _Case {
  _Case(this.controller, this.changes, this.formKey);
  final TextEditingController controller;
  final List<({int hour, int minute})?> changes;
  final GlobalKey<FormState> formKey;
}

Future<_Case> _pump(
  WidgetTester tester, {
  String text = '',
  FormFieldValidator<String>? validator,
  ({int hour, int minute})? initialPickerTime,
  Size size = const Size(900, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  final changes = <({int hour, int minute})?>[];
  final formKey = GlobalKey<FormState>();
  await tester.pumpWidget(
    MaterialApp(
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: UiTimeField(
              controller: controller,
              label: 'Hora de prueba',
              pickerHelpText: _pickerHelp,
              pickerTooltip: _pickerTooltip,
              initialPickerTime: initialPickerTime == null
                  ? null
                  : () => initialPickerTime,
              validator: validator,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Case(controller, changes, formKey);
}

void main() {
  testWidgets('solo acepta dígitos y dos puntos, hasta cinco caracteres', (
    tester,
  ) async {
    final c = await _pump(tester);

    await tester.enterText(find.byType(TextFormField), 'ab12:3456');

    expect(c.controller.text, '12:34');
  });

  testWidgets('una hora válida se informa como hora y minuto', (tester) async {
    final c = await _pump(tester);

    await tester.enterText(find.byType(TextFormField), '18:30');

    expect(c.changes.last, (hour: 18, minute: 30));
  });

  testWidgets('una hora a medias informa null', (tester) async {
    final c = await _pump(tester);

    await tester.enterText(find.byType(TextFormField), '18:3');

    expect(c.changes.last, isNull);
  });

  testWidgets('mientras se escribe no marca error hasta completar la hora', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.pump();

    expect(find.text(_badFormat), findsNothing);
  });

  for (final text in ['24:00', '12:60', '99:99']) {
    testWidgets('una hora completa que no existe ($text) muestra el error', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextFormField), text);
      await tester.pump();

      expect(find.text(_badFormat), findsOneWidget);
    });
  }

  testWidgets('una hora a medias al enviar el formulario es un error', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.enterText(find.byType(TextFormField), '18:3');
    // Al salir del campo la hora a medias deja de ser "todavía escribiendo".
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(c.formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text(_badFormat), findsOneWidget);
  });

  testWidgets('un campo vacío no tiene error de formato', (tester) async {
    final c = await _pump(tester);

    expect(c.formKey.currentState!.validate(), isTrue);
    await tester.pump();

    expect(find.text(_badFormat), findsNothing);
  });

  testWidgets('el validador de quien lo usa corre con el campo vacío', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      validator: (v) => (v ?? '').isEmpty ? 'Elegí la hora.' : null,
    );

    expect(c.formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Elegí la hora.'), findsOneWidget);
  });

  testWidgets('la cruz borra la hora e informa null', (tester) async {
    final c = await _pump(tester, text: '18:30');

    await tester.tap(find.byTooltip(_clearTooltip));
    await tester.pump();

    expect(c.controller.text, isEmpty);
    expect(c.changes.last, isNull);
  });

  group('el selector de hora', () {
    testWidgets('abre con el título pedido, de 24 horas y en español', (
      tester,
    ) async {
      await _pump(tester, text: '18:30');

      await tester.tap(find.byTooltip(_pickerTooltip));
      await tester.pumpAndSettle();

      expect(find.text(_pickerHelp), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      // De 12 horas diría PM a las 18:30.
      expect(find.text('PM'), findsNothing);
      expect(find.text('AM'), findsNothing);
    });

    testWidgets('con una hora escrita abre en esa hora y al aceptar la '
        'conserva', (tester) async {
      final c = await _pump(tester, text: '18:30');

      await tester.tap(find.byTooltip(_pickerTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(c.controller.text, '18:30');
      expect(c.changes.last, (hour: 18, minute: 30));
    });

    testWidgets('sin hora escrita abre en la hora sugerida', (tester) async {
      final c = await _pump(tester, initialPickerTime: (hour: 23, minute: 59));

      await tester.tap(find.byTooltip(_pickerTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(c.controller.text, '23:59');
    });

    testWidgets('sin hora escrita ni sugerida abre en 00:00', (tester) async {
      final c = await _pump(tester);

      await tester.tap(find.byTooltip(_pickerTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(c.controller.text, '00:00');
    });

    testWidgets('cancelar no cambia la hora', (tester) async {
      final c = await _pump(tester, text: '18:30');

      await tester.tap(find.byTooltip(_pickerTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c.controller.text, '18:30');
      expect(c.changes, isEmpty);
    });
  });

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('con texto al doble no desborda ni se corta la etiqueta', (
      tester,
    ) async {
      await _pump(
        tester,
        text: '18:30',
        size: const Size(320, 800),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TextFormField));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });
  });
}
