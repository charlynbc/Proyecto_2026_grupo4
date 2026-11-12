import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attention_detail_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attentions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';

class RecordingRepository implements DoctorAttentionRepository {
  final queries = <DoctorAttentionQuery>[];
  final fake = FakeDoctorAttentionRepository(latency: Duration.zero);
  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async {
    queries.add(query);
    return [await fake.get(5530)];
  }

  @override
  Future<DoctorAttention> get(int id) => fake.get(id);
}

Future<RecordingRepository> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
}) async {
  final repo = RecordingRepository();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorAttentionRepositoryProvider.overrideWith((ref) async => repo),
        specialtiesProvider.overrideWith(
          (ref) async => [
            const Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
          ],
        ),
      ],
      child: const MaterialApp(home: DoctorAttentionsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('sentido del orden como botón', () {
    final direction = find.byKey(const Key('attentions-direction'));

    testWidgets('muestra el texto y el ícono del estado actual', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);

      expect(
        find.descendant(of: direction, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: direction, matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: direction,
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsOneWidget,
      );
      expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
    });

    testWidgets('alterna al tocarlo y se aplica con Buscar', (tester) async {
      final repo = await _pumpScreen(tester);

      await tester.tap(direction);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: direction, matching: find.text('Ascendente')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: direction,
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
      // Todavía no se buscó: el último pedido sigue siendo el anterior.
      expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');

      await tester.tap(find.byKey(const Key('attentions-search')));
      await tester.pumpAndSettle();
      expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');

      await tester.tap(direction);
      await tester.tap(find.byKey(const Key('attentions-search')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
      expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
    });

    testWidgets('cambiar de campo reinicia el sentido', (tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.byKey(const Key('attentions-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apellido del paciente').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: direction, matching: find.text('Ascendente')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('attentions-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fecha').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
    });

    testWidgets('a 320 px se ve completo y no desborda', (tester) async {
      await loadRoboto();
      await _pumpScreen(tester, size: const Size(320, 900));

      expect(find.text('Descendente'), findsOneWidget);
      expect(
        tester.getRect(find.text('Descendente')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('busca con CI normalizada y abre el detalle', (tester) async {
    final repo = RecordingRepository();
    final router = GoRouter(
      initialLocation: '/medico/atenciones',
      routes: [
        GoRoute(
          path: '/medico/atenciones',
          builder: (_, _) => const DoctorAttentionsScreen(),
        ),
        GoRoute(
          path: '/medico/atenciones/:id',
          builder: (_, state) => DoctorAttentionDetailScreen(
            id: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          doctorAttentionRepositoryProvider.overrideWith((ref) async => repo),
          specialtiesProvider.overrideWith(
            (ref) async => [
              const Specialty(
                id: 3,
                name: 'Cardiología',
                requiresReferral: true,
              ),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 atención'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('attentions-patient-field')),
      '4.567.891-1',
    );
    await tester.tap(find.byKey(const Key('attentions-search')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.toQueryParameters()['paciente'], '45678911');
    await tester.tap(find.byKey(const Key('attentions-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apellido del paciente').last);
    await tester.pumpAndSettle();
    expect(find.text('Ascendente'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attentions-search')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');
    await tester.tap(find.byKey(const Key('attentions-clear')));
    await tester.pumpAndSettle();
    expect(
      repo.queries.last.toQueryParameters().containsKey('paciente'),
      isFalse,
    );
    expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
    expect(find.text('Todas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attention-5530')));
    await tester.pumpAndSettle();
    expect(find.text('Lucía Fernández'), findsOneWidget);
    expect(find.text('20/10/2026'), findsOneWidget);
    expect(find.text('Vence el 18/01/2027'), findsOneWidget);
    expect(find.text('Observaciones'), findsNothing);
  });
  testWidgets('controles a 320 píxeles sin desbordes', (tester) async {
    await loadRoboto();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          doctorAttentionRepositoryProvider.overrideWith(
            (ref) async => RecordingRepository(),
          ),
          specialtiesProvider.overrideWith(
            (ref) async => [
              const Specialty(
                id: 3,
                name: 'Cardiología',
                requiresReferral: true,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: DoctorAttentionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
