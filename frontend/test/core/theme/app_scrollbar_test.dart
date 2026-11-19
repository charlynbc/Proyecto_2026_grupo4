import 'dart:math' as math;

import 'package:agenda_medica/core/theme/app_scroll_behavior.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/core/widgets/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scrollbar_probe.dart';

// Los colores del diseño, escritos a mano: el hueso es el fondo de la app.
const _bone = Color(0xFFF4EEE2);
const _thumb = Color(0xFF5C6370);
const _track = Color(0xFFE3DBCB);

/// La luminancia relativa y el contraste de WCAG 2.1, calculados con la
/// fórmula y no con el helper de la app.
double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(400, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme.copyWith(platform: platform),
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(body: body),
    ),
  );
  await settleScrollbars(tester);
}

Widget _tall(double height) => SingleChildScrollView(
  child: SizedBox(height: height, width: double.infinity),
);

void main() {
  group('el tema', () {
    final theme = appTheme.scrollbarTheme;

    test('la barra y su pista están siempre visibles', () {
      expect(theme.thumbVisibility!.resolve({}), isTrue);
      expect(theme.trackVisibility!.resolve({}), isTrue);
    });

    test('mide 10 de grosor, con esquinas de 5 y se puede arrastrar', () {
      expect(theme.thickness!.resolve({}), 10);
      expect(theme.radius, const Radius.circular(5));
      expect(theme.interactive, isTrue);
    });

    test('el pulgar y la pista tienen los colores del diseño', () {
      expect(theme.thumbColor!.resolve({}), _thumb);
      expect(theme.trackColor!.resolve({}), _track);
    });

    test('el pulgar contrasta 5.23 a 1 con el fondo hueso, más que el mínimo '
        'de 3 a 1 para elementos gráficos', () {
      final ratio = _contrast(_thumb, _bone);

      expect(ratio, closeTo(5.23, 0.01));
      expect(ratio, greaterThanOrEqualTo(3));
    });

    test('la pista se distingue del fondo y el pulgar de la pista', () {
      expect(_contrast(_track, _bone), closeTo(1.19, 0.01));
      expect(_contrast(_thumb, _track), closeTo(4.39, 0.01));
      expect(_contrast(_thumb, _track), greaterThanOrEqualTo(3));
    });
  });

  group('la barra vertical, sin gestos ni mouse', () {
    for (final platform in TargetPlatform.values) {
      testWidgets('con $platform se dibuja cuando el contenido excede la '
          'altura', (tester) async {
        await _pump(tester, _tall(3000), platform: platform);

        final bars = drawnVerticalScrollbars(tester);
        expect(bars, hasLength(1));
        expect(bars.single.thumb!.width, 10);
        // En iOS Flutter usa la barra de Cupertino, con sus propios colores y
        // márgenes (iOS no es una plataforma de la app: solo se comprueba que
        // se vea).
        if (platform != TargetPlatform.iOS) {
          expect(bars.single.thumbColor, isSameColorAs(_thumb));
          expect(bars.single.trackColor, isSameColorAs(_track));
          // Alto de la pantalla 600 sobre un contenido de 3000: 600 * 600 / 3000.
          expect(bars.single.thumb!.height, closeTo(120, 0.5));
          expect(bars.single.thumb!.right, 400);
          expect(bars.single.track!.height, 600);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('con $platform no se dibuja cuando el contenido entra', (
        tester,
      ) async {
        await _pump(tester, _tall(100), platform: platform);

        expect(drawnVerticalScrollbars(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un contenido de 601 contra una pantalla de 600 ya la '
        'muestra', (tester) async {
      await _pump(tester, _tall(601));

      expect(drawnVerticalScrollbars(tester), hasLength(1));
    });

    testWidgets('un contenido de 600 contra una pantalla de 600 no', (
      tester,
    ) async {
      await _pump(tester, _tall(600));

      expect(drawnVerticalScrollbars(tester), isEmpty);
    });
  });

  group('el desplazamiento horizontal sigue como estaba', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('con $platform no se le agrega ninguna barra', (
        tester,
      ) async {
        await _pump(
          tester,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: const SizedBox(width: 3000, height: 50),
          ),
          platform: platform,
        );

        expect(drawnHorizontalScrollbars(tester), isEmpty);
        expect(drawnVerticalScrollbars(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('desplazamientos anidados', () {
    testWidgets('una lista sin desplazamiento propio dentro de una pantalla '
        'con scroll deja una sola barra y no falla', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 40,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                SizedBox(height: 40, child: Text('Fila $index')),
          ),
        ),
      );

      expect(drawnVerticalScrollbars(tester), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      testWidgets('con $platform una lista de alto fijo dentro de una pantalla '
          'con scroll tiene su propia barra y no falla', (tester) async {
        await _pump(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: 40,
                    itemBuilder: (context, index) =>
                        SizedBox(height: 40, child: Text('Fila $index')),
                  ),
                ),
                const SizedBox(height: 3000),
              ],
            ),
          ),
          platform: platform,
        );

        // Cada desplazable tiene su barra: la de la pantalla (600 de alto sobre
        // 3200: 112,5) y la de la lista (200 sobre 1600, que baja al mínimo de
        // 48).
        final bars = drawnVerticalScrollbars(tester);
        expect(bars, hasLength(2));
        expect([
          for (final bar in bars) bar.thumb!.height,
        ], unorderedMatches([closeTo(112.5, 0.5), closeTo(48, 0.5)]));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un scroll horizontal dentro de uno vertical deja solo la '
        'barra vertical', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: const SizedBox(width: 3000, height: 50),
              ),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      );

      expect(drawnVerticalScrollbars(tester), hasLength(1));
      expect(drawnHorizontalScrollbars(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('pestañas que mantienen dos pantallas con scroll a la vez', () {
    Widget tabs() => DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(key: Key('tab-a'), text: 'A'),
              Tab(key: Key('tab-b'), text: 'B'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CenteredContent(child: const SizedBox(height: 3000)),
                CenteredContent(child: const SizedBox(height: 3000)),
              ],
            ),
          ),
        ],
      ),
    );

    testWidgets('cambiar de pestaña no falla ni en medio de la animación y '
        'queda una sola barra', (tester) async {
      await _pump(tester, tabs());
      expect(drawnVerticalScrollbars(tester), hasLength(1));

      await tester.tap(find.byKey(const Key('tab-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      await settleScrollbars(tester);
      expect(tester.takeException(), isNull);
      expect(drawnVerticalScrollbars(tester), hasLength(1));

      await tester.tap(find.byKey(const Key('tab-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}
