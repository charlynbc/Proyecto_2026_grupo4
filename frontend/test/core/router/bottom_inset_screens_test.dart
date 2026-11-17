import 'package:agenda_medica/core/router/adaptive_nav_bar.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/home/widgets/home_shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/system_inset_support.dart';

void main() {
  group('Inicio del socio (sin barra inferior propia)', () {
    testWidgets(
      'angosto: el último elemento queda sobre la barra del sistema',
      (tester) async {
        await pumpAsWithInset(
          tester,
          UserRole.socio,
          size: kNarrowPhone,
          bottom: kSystemNavigationBar,
        );

        await scrollToEnd(tester);

        final bottom = bottomOf(tester, find.byType(HomeShortcuts));
        expect(bottom, lessThanOrEqualTo(600 - 48));
        // 552 dp de alto útil menos los 20 dp de padding del scroll.
        expect(bottom, closeTo(532, 0.01));
      },
    );

    testWidgets('ancho: el último elemento queda sobre la barra del sistema', (
      tester,
    ) async {
      await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kWidePhone,
        bottom: kSystemNavigationBar,
      );

      await scrollToEnd(tester);

      final bottom = bottomOf(tester, find.byType(HomeShortcuts));
      expect(bottom, lessThanOrEqualTo(600 - 48));
      // 552 dp de alto útil menos los 32 dp de padding del scroll ancho.
      expect(bottom, closeTo(520, 0.01));
    });

    testWidgets('con padding inferior 0 el layout es el de siempre (angosto)', (
      tester,
    ) async {
      await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kNarrowPhone,
        bottom: 0,
      );

      await scrollToEnd(tester);

      // 600 dp de alto menos los 20 dp de padding del scroll.
      expect(bottomOf(tester, find.byType(HomeShortcuts)), closeTo(580, 0.01));
    });

    testWidgets('con padding inferior 0 el layout es el de siempre (ancho)', (
      tester,
    ) async {
      await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kWidePhone,
        bottom: 0,
      );

      await scrollToEnd(tester);

      // 600 dp de alto menos los 32 dp de padding del scroll ancho.
      expect(bottomOf(tester, find.byType(HomeShortcuts)), closeTo(568, 0.01));
    });
  });

  group('Sección con barra inferior propia (angosto)', () {
    testWidgets('no se duplica el margen: la barra queda pegada al borde', (
      tester,
    ) async {
      final container = await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kNarrowPhone,
        bottom: kSystemNavigationBar,
      );
      await goTo(tester, container, '/socio/consultas');

      final bar = find.byType(AdaptiveNavBar);
      expect(bar, findsOneWidget);
      // La barra termina en el borde inferior de la pantalla (600 dp) y mide
      // sus 80 dp más los 48 dp que reserva ella misma con su SafeArea.
      expect(bottomOf(tester, bar), 600);
      expect(tester.getSize(bar).height, 128);
    });

    testWidgets('con padding inferior 0 la barra mide sus 80 dp de siempre', (
      tester,
    ) async {
      final container = await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kNarrowPhone,
        bottom: 0,
      );
      await goTo(tester, container, '/socio/consultas');

      final bar = find.byType(AdaptiveNavBar);
      expect(bottomOf(tester, bar), 600);
      expect(tester.getSize(bar).height, 80);
    });
  });
}
