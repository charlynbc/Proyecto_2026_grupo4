import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

/// 14/10/2026 22:30 en Uruguay (es del día 15 en UTC).
final _cancelacion = AppNotification(
  id: 15002,
  type: 'CANCELACION',
  title: 'Consulta cancelada',
  consultaId: 9002,
  content: 'Tu consulta del 21/10/2026 fue cancelada a tu solicitud.',
  createdAt: DateTime.utc(2026, 10, 15, 1, 30),
);

final _sinConsulta = AppNotification(
  id: 15003,
  type: 'AGENDA',
  title: 'Consulta agendada',
  consultaId: null,
  content: 'Tu consulta quedó agendada para el 20/10/2026 a las 09:20.',
  createdAt: DateTime.utc(2026, 10, 14, 13, 12),
);

final _larga = AppNotification(
  id: 15004,
  type: 'SUSPENSION',
  title: 'Turno suspendido por una licencia del médico',
  consultaId: 9004,
  content:
      'Tu consulta del 20/10/2026 fue cancelada por la institución. '
      'Horario: 09:20 a 09:40 (número 2). Motivo: el médico no puede '
      'atender ese día por una licencia prolongada y no hay otro profesional '
      'de la misma especialidad que lo reemplace en esa fecha.',
  createdAt: DateTime.utc(2026, 10, 16, 14, 20),
);

Future<void> _pump(
  WidgetTester tester,
  AppNotification notification, {
  VoidCallback? onTap,
  Size size = const Size(900, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
          child: NotificationCard(notification: notification, onTap: onTap),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  group('semántica', () {
    testWidgets('cada aviso se lee como una sola etiqueta completa: título, '
        'contenido y fecha con hora', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _cancelacion, onTap: () {});

      final semantics = tester.getSemantics(
        find.byKey(const Key('notification-15002')),
      );

      expect(
        semantics.label,
        'Consulta cancelada. Tu consulta del 21/10/2026 fue cancelada a tu '
        'solicitud. 14/10/2026 22:30',
      );
      handle.dispose();
    });

    testWidgets('un contenido sin punto final recibe uno antes de la fecha', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final sinPunto = AppNotification(
        id: 15005,
        type: 'HISTORIA_ACTUALIZADA',
        title: 'Historia clínica actualizada',
        consultaId: 9005,
        content: 'Tu historia clínica fue actualizada',
        createdAt: DateTime.utc(2026, 10, 14, 13, 12),
      );
      await _pump(tester, sinPunto, onTap: () {});

      final label = tester
          .getSemantics(find.byKey(const Key('notification-15005')))
          .label;

      expect(
        label,
        'Historia clínica actualizada. Tu historia clínica fue actualizada. '
        '14/10/2026 10:12',
      );
      handle.dispose();
    });

    testWidgets('el ícono no se lee aparte: no hay otra etiqueta con el tipo '
        'del aviso', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _cancelacion, onTap: () {});

      expect(find.bySemanticsLabel('Consulta cancelada'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('^Consulta cancelada\\. Tu consulta')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('un aviso que se puede abrir es un botón', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _cancelacion, onTap: () {});

      final semantics = tester.getSemantics(
        find.byKey(const Key('notification-15002')),
      );

      expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('un aviso sin consulta no es un botón ni tiene acción de '
        'tocar', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _sinConsulta);

      final data = tester
          .getSemantics(find.byKey(const Key('notification-15003')))
          .getSemanticsData();

      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        data.label,
        'Consulta agendada. Tu consulta quedó agendada para el 20/10/2026 a '
        'las 09:20. 14/10/2026 10:12',
      );
      handle.dispose();
    });
  });

  group('tamaño de toque', () {
    for (final size in [const Size(900, 1800), const Size(320, 640)]) {
      testWidgets('un aviso mide al menos 48 px de alto en ${size.width} px', (
        tester,
      ) async {
        await _pump(tester, _cancelacion, onTap: () {}, size: size);

        final rect = tester.getRect(
          find.byKey(const Key('notification-15002')),
        );

        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('el toque en el borde de la tarjeta abre el aviso', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        _cancelacion,
        onTap: () => taps++,
        size: const Size(320, 640),
      );
      final rect = tester.getRect(find.byKey(const Key('notification-15002')));

      await tester.tapAt(Offset(rect.left + 2, rect.top + rect.height / 2));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('a 320 px con el texto al doble', () {
    testWidgets('el título, el contenido y la fecha no se cortan', (
      tester,
    ) async {
      await _pump(
        tester,
        _larga,
        onTap: () {},
        size: const Size(320, 1600),
        textScale: 2,
      );

      for (final text in [_larga.title, _larga.content, '16/10/2026 11:20']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('la tarjeta entra en el ancho de la pantalla', (tester) async {
      await _pump(
        tester,
        _larga,
        onTap: () {},
        size: const Size(320, 1600),
        textScale: 2,
      );

      final rect = tester.getRect(find.byKey(const Key('notification-15004')));

      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}
