import 'package:agenda_medica/core/widgets/pagination_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pager_layout.dart';

const _label = 'Página 2 de 5';
const _longLabel = 'Página 2 de 5 · 93 cuentas';

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  String label = _label,
  bool hasPrevious = true,
  bool hasNext = true,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  Key? previousKey,
  Key? nextKey,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PaginationBar(
            label: label,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            onPrevious: onPrevious ?? () {},
            onNext: onNext ?? () {},
            previousKey: previousKey,
            nextKey: nextKey,
          ),
        ),
      ),
    ),
  );
}

final _previousOutlined = find.widgetWithText(OutlinedButton, 'Anterior');
final _nextOutlined = find.widgetWithText(OutlinedButton, 'Siguiente');

void main() {
  setUpAll(loadRoboto);

  group('disposicion', () {
    for (final width in [280.0, 300.0, 320.0]) {
      testWidgets('a $width px no entran los tres: el texto va arriba y los '
          'botones lado a lado debajo', (tester) async {
        await _pump(tester, width: width);

        expectNarrowPager(
          tester,
          label: find.text(_label),
          previous: _previousOutlined,
          next: _nextOutlined,
          screenWidth: width,
        );
      });
    }

    for (final width in [360.0, 600.0, 1300.0]) {
      testWidgets('a $width px los tres van en una fila', (tester) async {
        await _pump(tester, width: width);

        expectWidePager(
          tester,
          label: find.text(_label),
          previous: _previousOutlined,
          next: _nextOutlined,
        );
      });
    }

    for (final width in [360.0, 400.0]) {
      testWidgets('con el texto largo de Usuarios, a $width px no entran los '
          'tres: Siguiente no queda sola', (tester) async {
        await _pump(tester, width: width, label: _longLabel);

        expectNarrowPager(
          tester,
          label: find.text(_longLabel),
          previous: _previousOutlined,
          next: _nextOutlined,
          screenWidth: width,
        );
      });
    }

    for (final width in [600.0, 1300.0]) {
      testWidgets('con el texto largo de Usuarios, a $width px van los tres '
          'en una fila', (tester) async {
        await _pump(tester, width: width, label: _longLabel);

        expectWidePager(
          tester,
          label: find.text(_longLabel),
          previous: _previousOutlined,
          next: _nextOutlined,
        );
      });
    }

    testWidgets('en la disposicion ancha los controles quedan centrados', (
      tester,
    ) async {
      await _pump(tester, width: 600);

      final left = tester.getRect(_previousOutlined).left;
      final right = tester.getRect(_nextOutlined).right;
      expect((left + right) / 2, closeTo(300, 1));
    });

    testWidgets('el orden es Anterior, texto, Siguiente', (tester) async {
      await _pump(tester, width: 600);

      expect(
        tester.getRect(_previousOutlined).left,
        lessThan(tester.getRect(find.text(_label)).left),
      );
      expect(
        tester.getRect(find.text(_label)).left,
        lessThan(tester.getRect(_nextOutlined).left),
      );
    });

    testWidgets('en la disposicion angosta Anterior va a la izquierda de '
        'Siguiente', (tester) async {
      await _pump(tester, width: 300);

      expect(
        tester.getRect(_previousOutlined).left,
        lessThan(tester.getRect(_nextOutlined).left),
      );
    });

    testWidgets('con texto al doble a 600 px ya no entran: pasa a angosta', (
      tester,
    ) async {
      await _pump(tester, width: 600, scale: 2, label: _longLabel);

      expectNarrowPager(
        tester,
        label: find.text(_longLabel),
        previous: _previousOutlined,
        next: _nextOutlined,
        screenWidth: 600,
      );
    });
  });

  group('texto grande del sistema', () {
    for (final width in [280.0, 320.0, 360.0, 600.0]) {
      testWidgets('a $width px y escala 2.0 no hay excepciones y todo queda '
          'dentro de la pantalla', (tester) async {
        await _pump(tester, width: width, scale: 2);

        expect(tester.takeException(), isNull);
        for (final finder in [
          _previousOutlined,
          _nextOutlined,
          find.text(_label),
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
      });
    }
  });

  group('botones', () {
    testWidgets('en la primera pagina Anterior esta deshabilitado', (
      tester,
    ) async {
      await _pump(tester, width: 600, hasPrevious: false);

      expect(
        tester.widget<OutlinedButton>(_previousOutlined).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(_nextOutlined).onPressed, isNotNull);
    });

    testWidgets('en la ultima pagina Siguiente esta deshabilitado', (
      tester,
    ) async {
      await _pump(tester, width: 600, hasNext: false);

      expect(tester.widget<OutlinedButton>(_nextOutlined).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(_previousOutlined).onPressed,
        isNotNull,
      );
    });

    testWidgets('con una sola pagina los dos estan deshabilitados', (
      tester,
    ) async {
      await _pump(tester, width: 600, hasPrevious: false, hasNext: false);

      expect(
        tester.widget<OutlinedButton>(_previousOutlined).onPressed,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(_nextOutlined).onPressed, isNull);
    });

    testWidgets('cada boton llama a su callback', (tester) async {
      var previous = 0;
      var next = 0;
      await _pump(
        tester,
        width: 600,
        onPrevious: () => previous++,
        onNext: () => next++,
      );

      await tester.tap(_previousOutlined);
      await tester.tap(_nextOutlined);
      await tester.tap(_nextOutlined);

      expect(previous, 1);
      expect(next, 2);
    });

    testWidgets('en la disposicion angosta tambien se deshabilitan y llaman', (
      tester,
    ) async {
      var next = 0;
      await _pump(tester, width: 300, hasPrevious: false, onNext: () => next++);

      expect(
        tester.widget<OutlinedButton>(_previousOutlined).onPressed,
        isNull,
      );
      await tester.tap(_nextOutlined);
      expect(next, 1);
    });

    testWidgets('las keys de cada boton se conservan', (tester) async {
      await _pump(
        tester,
        width: 600,
        previousKey: const Key('mi-anterior'),
        nextKey: const Key('mi-siguiente'),
      );

      expect(find.byKey(const Key('mi-anterior')), findsOneWidget);
      expect(find.byKey(const Key('mi-siguiente')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mi-anterior')),
          matching: find.text('Anterior'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('las keys tambien estan en la disposicion angosta', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 300,
        previousKey: const Key('mi-anterior'),
        nextKey: const Key('mi-siguiente'),
      );

      expect(find.byKey(const Key('mi-anterior')), findsOneWidget);
      expect(find.byKey(const Key('mi-siguiente')), findsOneWidget);
    });
  });

  group('un unico aspecto', () {
    testWidgets('los dos botones tienen borde y no hay botones de texto', (
      tester,
    ) async {
      await _pump(tester, width: 600);

      expect(_previousOutlined, findsOneWidget);
      expect(_nextOutlined, findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('a ancho completo los controles quedan juntos y centrados, '
        'no en los extremos', (tester) async {
      await _pump(tester, width: 1300);

      final left = tester.getRect(_previousOutlined).left;
      final right = tester.getRect(_nextOutlined).right;
      expect(left, greaterThan(400));
      expect(right, lessThan(900));
    });
  });
}
