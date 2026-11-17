import 'package:agenda_medica/core/widgets/centered_content.dart';
import 'package:agenda_medica/features/estadisticas/screens/statistics_screen.dart';
import 'package:agenda_medica/features/estadisticas/tabs/absence_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/appointment_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/shift_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/specialty_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/time_slot_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las seis pestañas: la key de su etiqueta y el tipo del widget que muestra.
final _tabs = <(String, Type)>[
  ('stats-tab-specialties', SpecialtyStatisticsTab),
  ('stats-tab-shifts', ShiftStatisticsTab),
  ('stats-tab-appointments', AppointmentStatisticsTab),
  ('stats-tab-absences', AbsenceStatisticsTab),
  ('stats-tab-referrals', ReferralStatisticsTab),
  ('stats-tab-time-slots', TimeSlotStatisticsTab),
];

/// Todas las pestañas tienen 16 px de margen: el contenido empieza 16 px
/// debajo de las pestañas de la barra, sin hueco arriba.
const _margin = 16.0;

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: StatisticsScreen())),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// El borde superior del primer elemento de la pestaña [type], medido desde
/// el borde superior del cuerpo de pestañas.
double _contentTop(WidgetTester tester, Type type) {
  final content = find.descendant(
    of: find.byType(type),
    matching: find.byType(CenteredContent),
  );
  final firstChild = find
      .descendant(of: content, matching: find.byType(Column))
      .first;
  return tester.getTopLeft(firstChild).dy -
      tester.getTopLeft(find.byType(TabBarView)).dy;
}

void main() {
  for (final (key, type) in _tabs) {
    testWidgets('$type: el contenido queda arriba, sin hueco', (tester) async {
      await _pump(tester);
      await _openTab(tester, key);

      expect(find.byType(type), findsOneWidget);
      expect(_contentTop(tester, type), _margin);
    });

    testWidgets('$type: a 320 px con el contenido corto sigue arriba', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 800));
      await _openTab(tester, key);

      expect(tester.takeException(), isNull);
      expect(_contentTop(tester, type), _margin);
    });
  }
}
