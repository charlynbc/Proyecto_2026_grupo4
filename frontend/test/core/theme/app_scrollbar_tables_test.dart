import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter/material.dart' show Color, Size;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/real_app.dart';
import '../../helpers/scrollbar_probe.dart';

/// Sin cargar Roboto: con la tipografía de prueba las tres tablas son más
/// anchas que el lugar que tienen y su barra horizontal se dibuja.
void main() {
  group('las tablas con scroll horizontal siguen como estaban', () {
    // Antes del tema nuevo su barra horizontal era la de siempre: pulgar de 4
    // en Android, sin pista, con los colores por defecto de Flutter.
    for (final (role, path) in [
      (UserRole.administrador, '/admin/usuarios'),
      (UserRole.funcionario, '/funcionario/turnos'),
      (UserRole.funcionario, '/funcionario/agendas'),
    ]) {
      testWidgets('${role.name} $path', (tester) async {
        // Con 1300 de ancho las tres tablas se muestran y son más anchas que
        // el lugar que tienen.
        await pumpRealAppAs(tester, role, path, size: const Size(1300, 900));
        // Las tablas aparecen al buscar.
        await tester.tap(find.text('Buscar').first);
        await tester.pumpAndSettle();
        await settleScrollbars(tester);

        final bars = drawnHorizontalScrollbars(tester);
        for (final bar in bars) {
          expect(bar.thumb!.height, 4);
          expect(bar.trackColor?.a ?? 0, 0, reason: 'sin pista visible');
          expect(bar.thumbColor, isSameColorAs(const Color(0xFFBCBCBC)));
        }
        expect(tester.takeException(), isNull);
        expect(bars, hasLength(1), reason: '$path: la tabla tiene su barra');
      });
    }
  });
}
