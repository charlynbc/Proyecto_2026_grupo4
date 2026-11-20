import 'dart:async';

import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attentions_provider.dart';
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
  // Con este reloj, hoy es el 12/11/2026 y la atención 5530 es de hoy.
  final fake = FakeDoctorAttentionRepository(
    latency: Duration.zero,
    clock: () => DateTime.utc(2026, 11, 12, 15),
  );
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
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'separa orden y acciones al menos 16 px a ${width.toInt()} px',
      (tester) async {
        await loadRoboto();
        await _pumpScreen(tester, size: Size(width, 900));

        final order = find.byKey(const Key('attentions-order'));
        final direction = find.byKey(const Key('attentions-direction'));
        final search = find.byKey(const Key('attentions-search'));
        final clear = find.byKey(const Key('attentions-clear'));
        final orderBlock = find.ancestor(
          of: order,
          matching: find.byType(Wrap),
        );
        final actionsBlock = find.ancestor(
          of: search,
          matching: find.byType(Wrap),
        );
        expect(orderBlock, findsOneWidget);
        expect(actionsBlock, findsOneWidget);
        expect(
          find.descendant(of: orderBlock, matching: direction),
          findsOneWidget,
        );
        expect(
          find.descendant(of: actionsBlock, matching: clear),
          findsOneWidget,
        );

        await tester.ensureVisible(actionsBlock);
        await tester.pumpAndSettle();
        expect(search.hitTestable(), findsOneWidget);
        expect(clear.hitTestable(), findsOneWidget);
        for (final button in [search, clear]) {
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(900));
        }
        expect(tester.takeException(), isNull);

        final gap =
            tester.getRect(actionsBlock).top -
            tester.getRect(orderBlock).bottom;
        expect(
          gap,
          greaterThanOrEqualTo(16),
          reason: 'Separación entre los bloques completos a $width px',
        );
      },
    );
  }

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

    Future<void> chooseOrder(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const Key('attentions-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('alterna al tocarlo y se aplica al instante', (tester) async {
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
      // Se aplica sin tocar "Buscar".
      expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');

      await tester.tap(direction);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
      expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
    });

    testWidgets('pasar de fecha a apellido conserva el sentido descendente', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);

      await chooseOrder(tester, 'Apellido del paciente');

      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
      expect(repo.queries.last.toQueryParameters()['orden'], 'apellido');
      expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
    });

    testWidgets('con apellido ascendente, pasar a fecha deja ascendente', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      await chooseOrder(tester, 'Apellido del paciente');
      await tester.tap(direction);
      await tester.pumpAndSettle();
      expect(repo.queries.last.toQueryParameters()['orden'], 'apellido');
      expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');

      await chooseOrder(tester, 'Fecha');

      expect(
        find.descendant(of: direction, matching: find.text('Ascendente')),
        findsOneWidget,
      );
      expect(repo.queries.last.toQueryParameters()['orden'], 'fecha');
      expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');
    });

    // Aplicado con "Buscar": paciente 4.567.891-1. Escrito sin aplicar: "otro".
    Future<RecordingRepository> pumpWithPending(WidgetTester tester) async {
      final repo = await _pumpScreen(tester);
      await tester.enterText(
        find.byKey(const Key('attentions-patient-field')),
        '4.567.891-1',
      );
      await tester.tap(find.byKey(const Key('attentions-search')));
      await tester.pumpAndSettle();
      expect(repo.queries.last.toQueryParameters()['paciente'], '45678911');
      await tester.enterText(
        find.byKey(const Key('attentions-patient-field')),
        'otro',
      );
      await tester.pumpAndSettle();
      return repo;
    }

    String patientField(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const Key('attentions-patient-field')))
        .controller!
        .text;

    testWidgets('cambiar el orden pide al instante con lo ya aplicado', (
      tester,
    ) async {
      final repo = await pumpWithPending(tester);
      final before = repo.queries.length;

      await chooseOrder(tester, 'Apellido del paciente');

      expect(repo.queries.length, before + 1);
      final params = repo.queries.last.toQueryParameters();
      expect(params['orden'], 'apellido');
      expect(params['paciente'], '45678911');
      expect(patientField(tester), 'otro');
    });

    testWidgets('tocar el sentido pide al instante con lo ya aplicado', (
      tester,
    ) async {
      final repo = await pumpWithPending(tester);
      final before = repo.queries.length;

      await tester.tap(direction);
      await tester.pumpAndSettle();

      expect(repo.queries.length, before + 1);
      final params = repo.queries.last.toQueryParameters();
      expect(params['sentido'], 'asc');
      expect(params['paciente'], '45678911');
      expect(patientField(tester), 'otro');
    });

    testWidgets('Limpiar vuelve a fecha descendente', (tester) async {
      final repo = await pumpWithPending(tester);
      await chooseOrder(tester, 'Apellido del paciente');
      await tester.tap(direction);
      await tester.pumpAndSettle();
      expect(repo.queries.last.toQueryParameters()['sentido'], 'asc');

      await tester.tap(find.byKey(const Key('attentions-clear')));
      await tester.pumpAndSettle();

      final params = repo.queries.last.toQueryParameters();
      expect(params['orden'], 'fecha');
      expect(params['sentido'], 'desc');
      expect(params.containsKey('paciente'), isFalse);
      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
    });

    testWidgets('a 320 px se ve completo y no desborda', (tester) async {
      await loadRoboto();
      await _pumpScreen(tester, size: const Size(320, 900));

      expect(find.text('Descendente'), findsOneWidget);
      for (final finder in [
        find.byKey(const Key('attentions-search')),
        find.byKey(const Key('attentions-clear')),
        find.text('Lucía Fernández · CI 45678911'),
        find.byKey(const Key('attention-5530')),
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(finder.hitTestable(), findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(900));
      }
      expect(
        tester.getRect(find.text('Descendente')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
    });
  });

  for (final width in [1200.0, 360.0, 320.0]) {
    testWidgets(
      'el indicador de carga de Especialidad es cuadrado a ${width.toInt()} px',
      (tester) async {
        await loadRoboto();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        // Las especialidades quedan cargando; la lista de atenciones responde
        // enseguida, así el único indicador en pantalla es el del filtro.
        final gate = Completer<List<Specialty>>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete(const []);
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              doctorAttentionRepositoryProvider.overrideWith(
                (ref) async => RecordingRepository(),
              ),
              specialtiesProvider.overrideWith((ref) => gate.future),
            ],
            child: const MaterialApp(home: DoctorAttentionsScreen()),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final indicator = find.byType(CircularProgressIndicator);
        expect(indicator, findsOneWidget);
        expect(tester.getSize(indicator), const Size(36, 36));
      },
    );
  }

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
    expect(find.text('Descendente'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attentions-search')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.toQueryParameters()['sentido'], 'desc');
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
    expect(find.text('12/11/2026'), findsOneWidget);
    expect(find.text('Vence el 10/02/2027'), findsOneWidget);
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

  testWidgets(
    'al buscar un paciente muestra el indicador y no los 3 resultados',
    (tester) async {
      // El 12/11/2026 el mes en curso tiene tres atenciones: 5530, 5531 y
      // 5533. La 5532 es de hace 40 días y queda fuera.
      final fake = FakeDoctorAttentionRepository(
        latency: Duration.zero,
        clock: () => DateTime.utc(2026, 11, 12, 15),
      );
      final repo = _ListingRepository(fake);
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            doctorAttentionRepositoryProvider.overrideWith((ref) async => repo),
            doctorAttentionFiltersProvider.overrideWith(_NovemberFilters.new),
            specialtiesProvider.overrideWith(
              (ref) async => const [
                Specialty(
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

      expect(find.text('3 atenciones'), findsOneWidget);
      expect(find.byKey(const Key('attention-5530')), findsOneWidget);
      expect(find.byKey(const Key('attention-5531')), findsOneWidget);
      expect(find.byKey(const Key('attention-5533')), findsOneWidget);
      expect(find.byKey(const Key('attention-5532')), findsNothing);

      final pending = Completer<List<DoctorAttention>>();
      repo.pending = pending;
      await tester.enterText(
        find.byKey(const Key('attentions-patient-field')),
        '45678911',
      );
      await tester.tap(find.byKey(const Key('attentions-search')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('3 atenciones'), findsNothing);
      expect(find.byKey(const Key('attention-5530')), findsNothing);
      expect(find.byKey(const Key('attention-5531')), findsNothing);
      expect(find.byKey(const Key('attention-5533')), findsNothing);
      expect(repo.queries.last.toQueryParameters()['paciente'], '45678911');

      final filteredFuture = fake.list(repo.queries.last);
      await tester.pump(const Duration(milliseconds: 1));
      pending.complete(await filteredFuture);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('1 atención'), findsOneWidget);
      expect(
        find.text('Lucía Fernández · CI 45678911'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('attention-5530')), findsOneWidget);
      expect(find.byKey(const Key('attention-5531')), findsNothing);
      expect(find.byKey(const Key('attention-5533')), findsNothing);
    },
  );
}

/// Del 01/11/2026 al 12/11/2026, para que el listado no dependa del día real.
class _NovemberFilters extends DoctorAttentionFiltersController {
  @override
  DoctorAttentionQuery build() => DoctorAttentionQuery(
    from: DateTime.utc(2026, 11, 1),
    to: DateTime.utc(2026, 11, 12),
  );
}

class _ListingRepository implements DoctorAttentionRepository {
  _ListingRepository(this.fake);

  final FakeDoctorAttentionRepository fake;
  final queries = <DoctorAttentionQuery>[];
  Completer<List<DoctorAttention>>? pending;

  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) {
    queries.add(query);
    final gate = pending;
    if (gate != null) return gate.future;
    return fake.list(query);
  }

  @override
  Future<DoctorAttention> get(int id) => fake.get(id);
}
