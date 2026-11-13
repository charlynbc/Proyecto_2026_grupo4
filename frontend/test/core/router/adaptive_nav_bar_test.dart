import 'package:agenda_medica/core/router/adaptive_nav_bar.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

const _admin = [
  'Usuarios',
  'Especialidades',
  'Consultorios',
  'Estadísticas',
  'Cartelera',
];

const _socio = [
  'Inicio',
  'Reservar consulta',
  'Mis consultas',
  'Historia clínica',
  'Cartelera',
];

const _funcionario = ['Turnos', 'Llegada', 'Agendas', 'Cartelera'];

const _medico = ['Mis turnos', 'Atenciones', 'Pases', 'Cartelera'];

/// Palabras enteras, con el rango escrito a mano.
const _words = {
  'Usuarios': [TextSelection(baseOffset: 0, extentOffset: 8)],
  'Especialidades': [TextSelection(baseOffset: 0, extentOffset: 14)],
  'Consultorios': [TextSelection(baseOffset: 0, extentOffset: 12)],
  'Estadísticas': [TextSelection(baseOffset: 0, extentOffset: 12)],
  'Cartelera': [TextSelection(baseOffset: 0, extentOffset: 9)],
  'Inicio': [TextSelection(baseOffset: 0, extentOffset: 6)],
  'Reservar consulta': [
    TextSelection(baseOffset: 0, extentOffset: 8),
    TextSelection(baseOffset: 9, extentOffset: 17),
  ],
  'Mis consultas': [
    TextSelection(baseOffset: 0, extentOffset: 3),
    TextSelection(baseOffset: 4, extentOffset: 13),
  ],
  'Historia clínica': [
    TextSelection(baseOffset: 0, extentOffset: 8),
    TextSelection(baseOffset: 9, extentOffset: 16),
  ],
  'Turnos': [TextSelection(baseOffset: 0, extentOffset: 6)],
  'Llegada': [TextSelection(baseOffset: 0, extentOffset: 7)],
  'Agendas': [TextSelection(baseOffset: 0, extentOffset: 7)],
  'Mis turnos': [
    TextSelection(baseOffset: 0, extentOffset: 3),
    TextSelection(baseOffset: 4, extentOffset: 10),
  ],
  'Atenciones': [TextSelection(baseOffset: 0, extentOffset: 10)],
  'Pases': [TextSelection(baseOffset: 0, extentOffset: 5)],
};

Finder _slot(int index) => find.byKey(Key('adaptive-nav-slot-$index'));

List<AdaptiveNavDestination> _destinations(List<String> labels) {
  return [
    for (final label in labels)
      AdaptiveNavDestination(
        icon: Icons.circle_outlined,
        selectedIcon: Icons.circle,
        label: label,
      ),
  ];
}

Future<void> _pumpBar(
  WidgetTester tester, {
  required double width,
  required List<String> labels,
  required int selectedIndex,
  double textScale = 1,
  bool disableAnimations = false,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AdaptiveNavBar(
            destinations: _destinations(labels),
            selectedIndex: selectedIndex,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _effectiveFontSize(WidgetTester tester, String label) {
  final text = find.text(label);
  expect(text, findsOneWidget, reason: label);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final fitted = tester.renderObject<RenderFittedBox>(
    find.ancestor(of: text, matching: find.byType(FittedBox)),
  );
  final laidOut = paragraph.text.style!.fontSize!;
  final painted = paragraph.textScaler.scale(laidOut);
  final scale = fitted.size.width / paragraph.size.width;
  return painted * (scale > 1 ? 1 : scale);
}

void _expectWordsWhole(WidgetTester tester, String label) {
  final text = find.text(label);
  expect(text, findsOneWidget, reason: label);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  for (final word in _words[label]!) {
    final boxes = paragraph.getBoxesForSelection(word);
    expect(boxes, hasLength(1), reason: '$label no debe partir una palabra');
    final rect = boxes.single.toRect();
    expect(rect.left, greaterThanOrEqualTo(-0.01), reason: label);
    expect(
      rect.right,
      lessThanOrEqualTo(paragraph.size.width + 0.01),
      reason: label,
    );
  }
  expect(paragraph.text.toPlainText().contains('…'), isFalse, reason: label);
  expect(paragraph.text.toPlainText().contains('...'), isFalse, reason: label);
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('administrador a 320 px reparte el ancho segun el rotulo', (
    tester,
  ) async {
    await _pumpBar(tester, width: 320, labels: _admin, selectedIndex: 0);

    // Reparto de 320 sobre 316,9, medido a mano con Roboto a 11 px.
    const expected = [49.7, 81.9, 69.7, 67.4, 51.3];
    // Ancho del rotulo mas 2 px por lado.
    const minimum = [49.2, 81.1, 69.0, 66.8, 50.8];
    for (var i = 0; i < _admin.length; i++) {
      final width = tester.getSize(_slot(i)).width;
      expect(width, closeTo(expected[i], 1), reason: _admin[i]);
      expect(width, greaterThanOrEqualTo(minimum[i]), reason: _admin[i]);
      _expectWordsWhole(tester, _admin[i]);
    }
    final usuarios = tester.getSize(find.text('Usuarios')).height;
    for (final label in _admin.skip(1)) {
      expect(
        tester.getSize(find.text(label)).height,
        closeTo(usuarios, 0.5),
        reason: '$label queda en una sola linea',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320, 360 y 411 ninguna palabra se corta', (tester) async {
    const cases = [_admin, _socio, _funcionario, _medico];
    for (final labels in cases) {
      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3]) {
          await _pumpBar(
            tester,
            width: width,
            labels: labels,
            selectedIndex: 0,
            textScale: scale,
          );
          for (final label in labels) {
            _expectWordsWhole(tester, label);
            expect(
              _effectiveFontSize(tester, label),
              greaterThanOrEqualTo(11),
              reason: '$label a $width px y escala $scale',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('administrador a 320 px y escala 1,3 queda entre 11 y 11,4', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      width: 320,
      labels: _admin,
      selectedIndex: 1,
      textScale: 1.3,
    );
    for (final label in _admin) {
      expect(
        _effectiveFontSize(tester, label),
        inInclusiveRange(11, 11.4),
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'con el texto al doble la barra sigue en 80 y el icono no crece',
    (tester) async {
      await _pumpBar(
        tester,
        width: 320,
        labels: _admin,
        selectedIndex: 0,
        textScale: 2,
      );
      expect(
        tester.getSize(find.byKey(const Key('adaptive-nav-bar'))).height,
        80,
      );
      expect(
        tester.getSize(find.byIcon(Icons.circle)).height,
        lessThanOrEqualTo(31.2),
      );
      for (final label in _admin) {
        expect(_effectiveFontSize(tester, label), inInclusiveRange(11, 11.4));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ninguna ranura mide menos de 48 px', (tester) async {
    await _pumpBar(tester, width: 320, labels: _socio, selectedIndex: 0);
    for (var i = 0; i < _socio.length; i++) {
      expect(
        tester.getSize(_slot(i)).width,
        greaterThanOrEqualTo(48),
        reason: _socio[i],
      );
    }
    await _pumpBar(tester, width: 320, labels: _funcionario, selectedIndex: 0);
    expect(tester.getSize(_slot(0)).width, greaterThanOrEqualTo(48));
  });

  testWidgets('el ancho de cada ranura no cambia al seleccionar otra', (
    tester,
  ) async {
    await _pumpBar(tester, width: 320, labels: _admin, selectedIndex: 0);
    final before = [
      for (var i = 0; i < _admin.length; i++) tester.getSize(_slot(i)).width,
    ];
    await _pumpBar(tester, width: 320, labels: _admin, selectedIndex: 2);
    for (var i = 0; i < _admin.length; i++) {
      expect(tester.getSize(_slot(i)).width, closeTo(before[i], 0.1));
    }
  });

  testWidgets('el destino elegido anuncia Pestaña 2 de 5 y tiene tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpBar(tester, width: 320, labels: _admin, selectedIndex: 1);
    expect(
      tester.getSemantics(_slot(1)),
      isSemantics(
        label: 'Pestaña 2 de 5',
        isSelected: true,
        isButton: true,
        role: SemanticsRole.tab,
      ),
    );
    expect(
      tester.getSemantics(_slot(0)),
      isSemantics(isSelected: false, role: SemanticsRole.tab),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('adaptive-nav-bar'))),
      isSemantics(role: SemanticsRole.tabBar),
    );
    expect(find.byTooltip('Especialidades'), findsOneWidget);
    expect(find.byTooltip('Usuarios'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tocar un destino avisa su indice', (tester) async {
    final taps = <int>[];
    await _pumpBar(
      tester,
      width: 320,
      labels: _admin,
      selectedIndex: 0,
      onSelected: taps.add,
    );
    await tester.tap(_slot(3));
    expect(taps, [3]);
  });

  testWidgets('el indicador cabe en la ranura mas angosta', (tester) async {
    await _pumpBar(tester, width: 320, labels: _admin, selectedIndex: 0);
    final slot = tester.getSize(_slot(0)).width;
    final indicator = tester.getSize(
      find.byKey(const Key('adaptive-nav-indicator')),
    );
    expect(indicator.height, closeTo(32, 0.1));
    expect(indicator.width, lessThanOrEqualTo(slot - 4 + 0.1));
    expect(indicator.width, closeTo(slot - 4, 1));
  });
}
