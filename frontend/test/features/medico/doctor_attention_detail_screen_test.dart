import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attention_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

DoctorAttention _attention({
  String? treatment = 'Control en siete días',
  String? observations = 'Traer los estudios anteriores',
  List<Map<String, dynamic>> referrals = const [],
}) => DoctorAttention.fromJson({
  'idAtencion': 7101,
  'fechaAtencion': '2026-11-17',
  'paciente': {
    'id': 18,
    'ci': '90000018',
    'nombre': 'Juan',
    'apellido': 'Pérez',
  },
  'especialidad': {
    'id': 1,
    'nombre': 'Medicina General',
    'requierePase': false,
  },
  'afeccion': 'Control de seguimiento',
  'tratamiento': treatment,
  'observaciones': observations,
  'pases': referrals,
});

class _DetailRepository implements DoctorAttentionRepository {
  _DetailRepository(this.attention, {this.error});

  final DoctorAttention attention;
  Object? error;
  final requestedIds = <int>[];

  @override
  Future<DoctorAttention> get(int id) async {
    requestedIds.add(id);
    if (error != null) throw error!;
    return attention;
  }

  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async =>
      throw StateError('Este recorrido solo consulta el detalle');
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _DetailRepository repo, {
  Size? size,
  double textScale = 1,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorAttentionRepositoryProvider.overrideWith((ref) async => repo),
      ],
      child: MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const DoctorAttentionDetailScreen(id: 7101),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(repo.requestedIds, [7101]);
  expect(tester.takeException(), isNull);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

const _layoutReferrals = [
  {
    'id': 81,
    'especialidad': {
      'id': 3,
      'nombre': 'Cardiología y seguimiento cardiovascular',
      'requierePase': true,
    },
    'emitidoEn': '2026-11-17T10:00:00-03:00',
    'venceEl': '2027-02-15',
  },
  {
    'id': 82,
    'especialidad': {
      'id': 4,
      'nombre': 'Nutrición y educación alimentaria',
      'requierePase': true,
    },
    'emitidoEn': '2026-11-17T10:05:00-03:00',
    'venceEl': '2027-01-16',
  },
];

// El Material mide la superficie visible de la tarjeta, sin su margen externo.
Finder _cardSurface(String text) => find.descendant(
  of: find.ancestor(of: find.text(text), matching: find.byType(Card)),
  matching: find.byType(Material),
);

void main() {
  setUpAll(loadRoboto);

  testWidgets('layout detalle corto empieza entre 16 y 32 px bajo el AppBar', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      _DetailRepository(_attention(treatment: null, observations: null)),
      size: const Size(900, 1200),
    );
    final card = _cardSurface('Control de seguimiento');
    expect(card, findsOneWidget);
    final gap =
        tester.getRect(card).top - tester.getRect(find.byType(AppBar)).bottom;
    expect(gap, inInclusiveRange(16, 32));
  });

  for (final withPasses in [true, false]) {
    testWidgets(
      'layout Pases emitidos alinea los bordes con pases $withPasses',
      (tester) async {
        await _pumpDetail(
          tester,
          _DetailRepository(
            _attention(referrals: withPasses ? _layoutReferrals : []),
          ),
          size: const Size(900, 1200),
        );
        final left = tester
            .getRect(_cardSurface('Control de seguimiento'))
            .left;
        final offsets = <String, double>{
          'título': tester.getRect(find.text('Pases emitidos')).left - left,
          if (withPasses) ...{
            'primera tarjeta':
                tester
                    .getRect(
                      _cardSurface('Cardiología y seguimiento cardiovascular'),
                    )
                    .left -
                left,
            'segunda tarjeta':
                tester
                    .getRect(_cardSurface('Nutrición y educación alimentaria'))
                    .left -
                left,
          } else
            'mensaje':
                tester
                    .getRect(
                      find.text('No se emitieron pases en esta atención.'),
                    )
                    .left -
                left,
        };
        expect(
          offsets.values,
          everyElement(inInclusiveRange(-1, 1)),
          reason: 'Diferencias horizontales en px: $offsets',
        );
      },
    );
  }

  testWidgets(
    'layout Pases emitidos mantiene espacios verticales entre bloques',
    (tester) async {
      await _pumpDetail(
        tester,
        _DetailRepository(_attention(referrals: _layoutReferrals)),
        size: const Size(900, 1200),
      );
      final main = tester.getRect(_cardSurface('Control de seguimiento'));
      final title = tester.getRect(find.text('Pases emitidos'));
      final first = tester.getRect(
        _cardSurface('Cardiología y seguimiento cardiovascular'),
      );
      final second = tester.getRect(
        _cardSurface('Nutrición y educación alimentaria'),
      );
      final gaps = {
        'detalle a título': title.top - main.bottom,
        'título a pase': first.top - title.bottom,
        'entre pases': second.top - first.bottom,
      };
      expect(
        gaps['detalle a título'],
        inInclusiveRange(16, 32),
        reason: '$gaps',
      );
      expect(gaps['título a pase'], inInclusiveRange(8, 16), reason: '$gaps');
      expect(gaps['entre pases'], inInclusiveRange(8, 16), reason: '$gaps');
    },
  );

  for (final width in [320.0, 360.0, 400.0]) {
    testWidgets(
      'layout detalle a $width px con texto x2 permite leer y desplazar el contenido',
      (tester) async {
        const treatment =
            'Mantener el tratamiento indicado y concurrir a control con los estudios solicitados.';
        const observations =
            'Consultar nuevamente si aparecen síntomas persistentes durante los próximos días.';
        await _pumpDetail(
          tester,
          _DetailRepository(
            _attention(
              treatment: treatment,
              observations: observations,
              referrals: _layoutReferrals,
            ),
          ),
          size: Size(width, 800),
          textScale: 2,
        );
        for (final label in [
          '17/11/2026',
          'Tratamiento',
          treatment,
          'Observaciones',
          observations,
          'Pases emitidos',
          'Cardiología y seguimiento cardiovascular',
          'Vence el 15/02/2027',
          'Nutrición y educación alimentaria',
          'Vence el 16/01/2027',
        ]) {
          final finder = find.text(label);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget, reason: label);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: label);
          expect(rect.right, lessThanOrEqualTo(width), reason: label);
          expect(
            rect.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
            reason: label,
          );
          expect(rect.bottom, lessThanOrEqualTo(800), reason: label);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          for (final box in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          )) {
            // Las cajas de glifos pueden exceder una fracción de píxel el ancho tipográfico.
            expect(box.left, greaterThanOrEqualTo(-1), reason: label);
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 1),
              reason: label,
            );
          }
          expect(tester.takeException(), isNull);
        }
        for (final label in [
          'Control de seguimiento',
          'Cardiología y seguimiento cardiovascular',
          'Nutrición y educación alimentaria',
        ]) {
          final surface = _cardSurface(label);
          expect(surface, findsOneWidget);
          final rect = tester.getRect(surface);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
      },
    );
  }

  testWidgets('no encontrado no ofrece Reintentar', (tester) async {
    await _pumpDetail(
      tester,
      _DetailRepository(
        _attention(),
        error: const DoctorAttentionException(
          DoctorAttentionFailure.notFound,
          attentionNotFoundMessage,
        ),
      ),
    );
    expect(
      find.text('No encontramos esta atención entre las tuyas.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('muestra Tratamiento y Observaciones con sus textos completos', (
    tester,
  ) async {
    await _pumpDetail(tester, _DetailRepository(_attention()));
    expect(find.text('Tratamiento'), findsOneWidget);
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Traer los estudios anteriores'), findsOneWidget);
  });

  for (final (name, value) in <(String, String?)>[
    ('nulos', null),
    ('vacíos', ''),
    ('solo espacios', '   '),
  ]) {
    testWidgets('omite Tratamiento y Observaciones cuando son $name', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        _DetailRepository(_attention(treatment: value, observations: value)),
      );
      expect(find.text('Control de seguimiento'), findsOneWidget);
      expect(find.text('Tratamiento'), findsNothing);
      expect(find.text('Observaciones'), findsNothing);
    });
  }

  testWidgets('sin pases muestra el mensaje exacto', (tester) async {
    await _pumpDetail(tester, _DetailRepository(_attention()));
    expect(find.text('Pases emitidos'), findsOneWidget);
    expect(
      find.text('No se emitieron pases en esta atención.'),
      findsOneWidget,
    );
  });

  testWidgets('cada pase muestra su especialidad y vencimiento en su tarjeta', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      _DetailRepository(
        _attention(
          referrals: [
            {
              'id': 81,
              'especialidad': {
                'id': 3,
                'nombre': 'Cardiología',
                'requierePase': true,
              },
              'emitidoEn': '2026-11-17T10:00:00-03:00',
              'venceEl': '2027-02-15',
            },
            {
              'id': 82,
              'especialidad': {
                'id': 4,
                'nombre': 'Nutrición',
                'requierePase': true,
              },
              'emitidoEn': '2026-11-17T10:05:00-03:00',
              'venceEl': '2027-01-16',
            },
          ],
        ),
      ),
    );
    expect(find.text('Pases emitidos'), findsOneWidget);
    expect(find.text('No se emitieron pases en esta atención.'), findsNothing);
    final cardiology = find.ancestor(
      of: find.text('Cardiología'),
      matching: find.byType(Card),
    );
    final nutrition = find.ancestor(
      of: find.text('Nutrición'),
      matching: find.byType(Card),
    );
    expect(cardiology, findsOneWidget);
    expect(nutrition, findsOneWidget);
    expect(tester.element(cardiology), isNot(same(tester.element(nutrition))));
    expect(
      find.descendant(
        of: cardiology,
        matching: find.text('Vence el 15/02/2027'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: nutrition,
        matching: find.text('Vence el 16/01/2027'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('un error temporal permite Reintentar y recuperar el detalle', (
    tester,
  ) async {
    final repo = _DetailRepository(_attention(), error: const ApiException());
    await _pumpDetail(tester, repo);
    expect(
      find.text(
        'Ocurrió un problema de nuestro lado. Intentá de nuevo en unos minutos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Control de seguimiento'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.requestedIds, [7101, 7101]);
    expect(find.text('Control de seguimiento'), findsOneWidget);
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(
      find.text(
        'Ocurrió un problema de nuestro lado. Intentá de nuevo en unos minutos.',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (name, failure, message, expected) in [
    (
      'acceso denegado',
      DoctorAttentionFailure.forbidden,
      attentionForbiddenMessage,
      'Tu cuenta no tiene permiso para consultar atenciones.',
    ),
    (
      'no encontrado',
      DoctorAttentionFailure.notFound,
      attentionNotFoundMessage,
      'No encontramos esta atención entre las tuyas.',
    ),
  ]) {
    testWidgets('muestra el mensaje exacto de $name', (tester) async {
      await _pumpDetail(
        tester,
        _DetailRepository(
          _attention(),
          error: DoctorAttentionException(failure, message),
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Control de seguimiento'), findsNothing);
    });
  }
}
