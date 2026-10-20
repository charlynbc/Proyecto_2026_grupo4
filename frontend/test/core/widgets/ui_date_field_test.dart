import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/core/widgets/ui_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Los mensajes se escriben a mano, no con las constantes de `ui_date.dart`:
// así una mutación del texto se detecta.
const String _badFormat =
    'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';
const String _nonexistent =
    'Esa fecha no existe en el calendario. Revisá el día y el mes.';

const String _label = 'Fecha de prueba';
const String _pickerTooltip = 'Elegir la fecha de prueba';
// Distinto de la etiqueta y del tooltip: así se sabe que el título sale del
// diálogo y no de otro lugar de la pantalla.
const String _pickerHelp = 'Elegí la fecha de prueba';
const String _clearTooltip = 'Borrar la fecha';

final DateTime _wideFirst = DateTime.utc(2000, 1, 1);
final DateTime _wideLast = DateTime.utc(2100, 12, 31);

class _Case {
  _Case(this.controller, this.focusNode, this.changes);

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Lo que informó `onChanged`, en orden.
  final List<DateTime?> changes;
}

/// Monta el campo en un `MaterialApp` con el idioma real de la app
/// (`kAppLocale`, `kSupportedLocales` y `kLocalizationsDelegates`).
Future<_Case> _pump(
  WidgetTester tester, {
  String text = '',
  bool enabled = true,
  String? errorText,
  FormFieldValidator<String>? validator,
  DateTime? firstDate,
  DateTime? lastDate,
  ValueGetter<DateTime?>? initialPickerDate,
  DateTime Function()? today,
  double width = 300,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  final changes = <DateTime?>[];

  await tester.pumpWidget(
    MaterialApp(
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: UiDateField(
              controller: controller,
              focusNode: focusNode,
              label: _label,
              pickerHelpText: _pickerHelp,
              pickerTooltip: _pickerTooltip,
              firstDate: firstDate ?? _wideFirst,
              lastDate: lastDate ?? _wideLast,
              initialPickerDate: initialPickerDate,
              enabled: enabled,
              errorText: errorText,
              validator: validator,
              onChanged: changes.add,
              today: today ?? () => DateTime.utc(2026, 10, 20),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Case(controller, focusNode, changes);
}

Finder get _field => find.byType(TextFormField);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

Future<void> _blur(WidgetTester tester, _Case c) async {
  c.focusNode.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _openCalendar(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_pickerTooltip));
  await tester.pumpAndSettle();
}

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
}

void main() {
  group('el texto', () {
    testWidgets('muestra la etiqueta y el hint dd/mm/aaaa por defecto', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text(_label), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'dd/mm/aaaa');
    });

    testWidgets('el hint se puede cambiar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kLocalizationsDelegates,
          home: Scaffold(
            body: UiDateField(
              controller: TextEditingController(),
              label: _label,
              hint: 'Desde cuándo',
              pickerHelpText: _pickerHelp,
              pickerTooltip: _pickerTooltip,
              firstDate: _wideFirst,
              lastDate: _wideLast,
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'Desde cuándo');
    });

    testWidgets('descarta lo que no es un dígito o una barra', (tester) async {
      final c = await _pump(tester);

      await _type(tester, '20a/1-0/2026');

      expect(c.controller.text, '20/10/2026');
    });

    testWidgets('corta en 10 caracteres', (tester) async {
      final c = await _pump(tester);

      await _type(tester, '20/10/20269999');

      expect(c.controller.text, '20/10/2026');
    });

    testWidgets('no agrega las barras solo', (tester) async {
      final c = await _pump(tester);

      await _type(tester, '2010');

      expect(c.controller.text, '2010');
    });
  });

  group('el error', () {
    testWidgets('con un "2" tipeado todavía no hay error', (tester) async {
      await _pump(tester);

      await _type(tester, '2');

      expect(find.text(_badFormat), findsNothing);
      expect(find.text(_nonexistent), findsNothing);
    });

    testWidgets('con "20/10" tipeado y el foco puesto, tampoco', (
      tester,
    ) async {
      await _pump(tester);

      await _type(tester, '20/10');

      expect(find.text(_badFormat), findsNothing);
    });

    testWidgets('al salir del campo con "20/10" avisa del formato', (
      tester,
    ) async {
      final c = await _pump(tester);
      await _type(tester, '20/10');

      await _blur(tester, c);

      expect(find.text(_badFormat), findsOneWidget);
      expect(find.text(_nonexistent), findsNothing);
    });

    testWidgets('al completar los 10 caracteres de una fecha que no existe, '
        'avisa que no existe', (tester) async {
      await _pump(tester);

      await _type(tester, '31/02/2026');

      expect(find.text(_nonexistent), findsOneWidget);
      expect(find.text(_badFormat), findsNothing);
    });

    testWidgets('al completar 10 caracteres con mal formato, avisa del '
        'formato', (tester) async {
      await _pump(tester);

      await _type(tester, '2010202699');

      expect(find.text(_badFormat), findsOneWidget);
    });

    testWidgets('una fecha válida no tiene error', (tester) async {
      await _pump(tester);

      await _type(tester, '20/10/2026');

      expect(find.text(_badFormat), findsNothing);
      expect(find.text(_nonexistent), findsNothing);
    });

    testWidgets('el bisiesto 29/02/2028 es válido y el 29/02/2026, no', (
      tester,
    ) async {
      await _pump(tester);

      await _type(tester, '29/02/2028');
      expect(find.text(_nonexistent), findsNothing);

      await _type(tester, '29/02/2026');
      expect(find.text(_nonexistent), findsOneWidget);
    });

    testWidgets('un campo vacío no tiene error, ni tras salir de él', (
      tester,
    ) async {
      final c = await _pump(tester);
      await _type(tester, '2');
      await _type(tester, '');

      await _blur(tester, c);

      expect(find.text(_badFormat), findsNothing);
      expect(find.text(_nonexistent), findsNothing);
    });

    testWidgets('el error se va al corregir la fecha', (tester) async {
      await _pump(tester);
      await _type(tester, '31/02/2026');
      expect(find.text(_nonexistent), findsOneWidget);

      await _type(tester, '28/02/2026');

      expect(find.text(_nonexistent), findsNothing);
    });

    testWidgets('el validador propio corre con una fecha válida', (
      tester,
    ) async {
      await _pump(
        tester,
        validator: (value) =>
            value == '19/10/2026' ? 'Esa fecha ya pasó.' : null,
      );

      await _type(tester, '19/10/2026');

      expect(find.text('Esa fecha ya pasó.'), findsOneWidget);
    });

    testWidgets('el validador propio no corre con una fecha que no existe', (
      tester,
    ) async {
      await _pump(tester, validator: (value) => 'Esa fecha ya pasó.');

      await _type(tester, '31/02/2026');

      expect(find.text(_nonexistent), findsOneWidget);
      expect(find.text('Esa fecha ya pasó.'), findsNothing);
    });

    testWidgets('el validador propio no corre mientras se tipea', (
      tester,
    ) async {
      await _pump(tester, validator: (value) => 'Esa fecha ya pasó.');

      await _type(tester, '20/1');

      expect(find.text('Esa fecha ya pasó.'), findsNothing);
    });

    testWidgets('con errorText (modo manual) lo muestra', (tester) async {
      await _pump(tester, errorText: 'Error puesto desde afuera.');

      expect(find.text('Error puesto desde afuera.'), findsOneWidget);
    });
  });

  group('onChanged', () {
    testWidgets('al completar una fecha válida informa la fecha en UTC', (
      tester,
    ) async {
      final c = await _pump(tester);

      await _type(tester, '20/10/2026');

      expect(c.changes.last, DateTime.utc(2026, 10, 20));
      expect(c.changes.last!.isUtc, isTrue);
    });

    testWidgets('con texto inválido o incompleto informa null', (tester) async {
      final c = await _pump(tester);
      await _type(tester, '20/10/2026');
      expect(c.changes.last, isNotNull);

      await _type(tester, '20/10/20');
      expect(c.changes.last, isNull);

      await _type(tester, '20/10/2026');
      expect(c.changes.last, isNotNull);

      await _type(tester, '31/02/2026');
      expect(c.changes.last, isNull);
    });

    testWidgets('al vaciar el campo informa null', (tester) async {
      final c = await _pump(tester);
      await _type(tester, '20/10/2026');

      await _type(tester, '');

      expect(c.changes.last, isNull);
    });
  });

  group('la cruz para borrar', () {
    testWidgets('no está con el campo vacío', (tester) async {
      await _pump(tester);

      expect(find.byTooltip(_clearTooltip), findsNothing);
    });

    testWidgets('aparece cuando hay texto', (tester) async {
      await _pump(tester);

      await _type(tester, '2');

      expect(find.byTooltip(_clearTooltip), findsOneWidget);
    });

    testWidgets('con un texto inicial ya está', (tester) async {
      await _pump(tester, text: '20/10/2026');

      expect(find.byTooltip(_clearTooltip), findsOneWidget);
    });

    testWidgets('no está con el campo deshabilitado', (tester) async {
      await _pump(tester, text: '20/10/2026', enabled: false);

      expect(find.byTooltip(_clearTooltip), findsNothing);
    });

    testWidgets('al tocarla vacía el campo, informa null y desaparece', (
      tester,
    ) async {
      final c = await _pump(tester, text: '20/10/2026');

      await tester.tap(find.byTooltip(_clearTooltip));
      await tester.pumpAndSettle();

      expect(c.controller.text, isEmpty);
      expect(c.changes.last, isNull);
      expect(find.byTooltip(_clearTooltip), findsNothing);
    });

    testWidgets('al tocarla devuelve el foco al campo', (tester) async {
      final c = await _pump(tester, text: '20/10/2026');
      expect(c.focusNode.hasFocus, isFalse);

      await tester.tap(find.byTooltip(_clearTooltip));
      await tester.pumpAndSettle();

      expect(c.focusNode.hasFocus, isTrue);
    });

    testWidgets('borrar no deja un error de formato', (tester) async {
      await _pump(tester, text: '31/02/2026');
      await tester.tap(find.byTooltip(_clearTooltip));
      await tester.pumpAndSettle();

      expect(find.text(_nonexistent), findsNothing);
      expect(find.text(_badFormat), findsNothing);
    });
  });

  group('el calendario', () {
    testWidgets('sale en español, con título propio y botones explícitos', (
      tester,
    ) async {
      await _pump(tester, text: '20/10/2026');

      await _openCalendar(tester);

      final dialog = find.byType(DatePickerDialog);
      expect(dialog, findsOneWidget);
      // El título del calendario está dentro del diálogo, una sola vez.
      expect(
        find.descendant(of: dialog, matching: find.text(_pickerHelp)),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      // El "ACEPTAR" nativo de es_UY no se usa.
      expect(find.text('ACEPTAR'), findsNothing);
      expect(find.text('Selecciona una fecha'), findsNothing);
    });

    testWidgets('muestra el mes en español', (tester) async {
      await _pump(tester, text: '20/10/2026');

      await _openCalendar(tester);

      expect(find.text('octubre de 2026'), findsOneWidget);
    });

    testWidgets('empieza la semana el lunes', (tester) async {
      await _pump(tester, text: '20/10/2026');

      await _openCalendar(tester);

      final monday = tester.getCenter(find.text('L'));
      final sunday = tester.getCenter(find.text('D'));
      expect(monday.dx, lessThan(sunday.dx));
    });

    testWidgets('elegir un día y aceptar escribe dd/mm/aaaa e informa la '
        'fecha', (tester) async {
      final c = await _pump(tester, text: '20/10/2026');
      await _openCalendar(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await _accept(tester);

      expect(c.controller.text, '15/10/2026');
      expect(c.changes.last, DateTime.utc(2026, 10, 15));
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('cancelar no cambia el texto ni informa nada', (tester) async {
      final c = await _pump(tester, text: '20/10/2026');
      await _openCalendar(tester);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c.controller.text, '20/10/2026');
      expect(c.changes, isEmpty);
    });

    testWidgets('un campo deshabilitado no abre el calendario', (tester) async {
      await _pump(tester, enabled: false);

      await tester.tap(find.byTooltip(_pickerTooltip), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  group('la fecha con que abre el calendario', () {
    Future<String> openAndAccept(WidgetTester tester, _Case c) async {
      await _openCalendar(tester);
      await _accept(tester);
      return c.controller.text;
    }

    testWidgets('lo escrito, si es una fecha válida', (tester) async {
      final c = await _pump(tester, text: '12/03/2027');

      expect(await openAndAccept(tester, c), '12/03/2027');
    });

    testWidgets('lo escrito gana sobre la fecha de initialPickerDate', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        text: '12/03/2027',
        initialPickerDate: () => DateTime.utc(2026, 11, 5),
      );

      expect(await openAndAccept(tester, c), '12/03/2027');
    });

    testWidgets('con el campo vacío, la de initialPickerDate', (tester) async {
      final c = await _pump(
        tester,
        initialPickerDate: () => DateTime.utc(2026, 11, 5),
      );

      expect(await openAndAccept(tester, c), '05/11/2026');
    });

    testWidgets('con una fecha que no existe escrita, la de '
        'initialPickerDate', (tester) async {
      final c = await _pump(
        tester,
        text: '31/02/2026',
        initialPickerDate: () => DateTime.utc(2026, 11, 5),
      );

      expect(await openAndAccept(tester, c), '05/11/2026');
    });

    testWidgets('si initialPickerDate no da fecha, hoy', (tester) async {
      final c = await _pump(
        tester,
        initialPickerDate: () => null,
        today: () => DateTime.utc(2026, 10, 20),
      );

      expect(await openAndAccept(tester, c), '20/10/2026');
    });

    testWidgets('sin nada escrito ni initialPickerDate, hoy (el inyectado)', (
      tester,
    ) async {
      final c = await _pump(tester, today: () => DateTime.utc(2027, 2, 3));

      expect(await openAndAccept(tester, c), '03/02/2027');
    });

    testWidgets('initialPickerDate se evalúa al abrir, no al armar el campo', (
      tester,
    ) async {
      var current = DateTime.utc(2026, 11, 5);
      final c = await _pump(tester, initialPickerDate: () => current);
      current = DateTime.utc(2026, 12, 9);

      expect(await openAndAccept(tester, c), '09/12/2026');
    });

    testWidgets('una fecha anterior al rango se ajusta al primer día', (
      tester,
    ) async {
      final c = await _pump(tester, text: '01/01/1990');

      expect(await openAndAccept(tester, c), '01/01/2000');
    });

    testWidgets('una fecha posterior al rango se ajusta al último día', (
      tester,
    ) async {
      final c = await _pump(tester, text: '31/12/2200');

      expect(await openAndAccept(tester, c), '31/12/2100');
    });

    testWidgets('un initialPickerDate fuera del rango también se ajusta', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        initialPickerDate: () => DateTime.utc(1980, 6, 1),
      );

      expect(await openAndAccept(tester, c), '01/01/2000');
    });

    testWidgets('hoy fuera del rango también se ajusta', (tester) async {
      final c = await _pump(
        tester,
        firstDate: DateTime.utc(2030, 1, 1),
        lastDate: DateTime.utc(2030, 12, 31),
        today: () => DateTime.utc(2026, 10, 20),
      );

      expect(await openAndAccept(tester, c), '01/01/2030');
    });

    testWidgets('una fecha dentro del rango no se toca', (tester) async {
      final c = await _pump(
        tester,
        text: '15/06/2030',
        firstDate: DateTime.utc(2030, 1, 1),
        lastDate: DateTime.utc(2030, 12, 31),
      );

      expect(await openAndAccept(tester, c), '15/06/2030');
    });
  });

  group('el ancho', () {
    for (final width in [220.0, 300.0, 400.0]) {
      testWidgets(
        'con $width px no hay desbordes, con la cruz y el calendario',
        (tester) async {
          await _pump(tester, text: '20/10/2026', width: width);

          expect(tester.takeException(), isNull);
          expect(find.byTooltip(_clearTooltip), findsOneWidget);
          expect(find.byTooltip(_pickerTooltip), findsOneWidget);
        },
      );
    }

    testWidgets('con un error largo a 220 px tampoco desborda', (tester) async {
      await _pump(tester, width: 220);

      await _type(tester, '31/02/2026');

      expect(find.text(_nonexistent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
