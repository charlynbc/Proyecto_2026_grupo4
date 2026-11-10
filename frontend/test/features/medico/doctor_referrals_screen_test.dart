import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/medico/models/issued_referral.dart';
import 'package:agenda_medica/features/medico/models/issued_referral_query.dart';
import 'package:agenda_medica/features/medico/providers/issued_referral_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/issued_referral_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_referral_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_referrals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

/// Un repositorio escrito a mano: anota cada consulta y devuelve lo que se le
/// diga, o falla con [error].
class _Repository implements IssuedReferralRepository {
  _Repository(this.result);

  List<IssuedReferral> result;
  Object? error;
  final List<Map<String, String>> queries = [];

  @override
  Future<List<IssuedReferral>> list(IssuedReferralQuery query) async {
    queries.add(query.toQueryParameters());
    if (error != null) throw error!;
    return result;
  }
}

final _lucia = IssuedReferral(
  id: 78,
  patient: const IssuedReferralPatient(
    id: 21,
    ci: '45678911',
    name: 'Lucía',
    lastName: 'Fernández',
  ),
  destination: const Specialty(
    id: 4,
    name: 'Nutrición',
    requiresReferral: true,
  ),
  issuedAt: DateTime.utc(2026, 10, 20, 12, 41),
  expiresOn: DateTime.utc(2027, 1, 18),
  status: ReferralStatus.available,
);

final _bruno = IssuedReferral(
  id: 79,
  patient: const IssuedReferralPatient(
    id: 22,
    ci: '50123456',
    name: 'Bruno',
    lastName: 'Acosta',
  ),
  destination: const Specialty(
    id: 3,
    name: 'Cardiología',
    requiresReferral: true,
  ),
  issuedAt: DateTime.utc(2026, 9, 10, 18, 5),
  expiresOn: DateTime.utc(2026, 12, 9),
  status: ReferralStatus.used,
);

Future<_Repository> _pump(
  WidgetTester tester, {
  List<IssuedReferral>? result,
  Object? error,
  Size size = const Size(900, 1800),
}) async {
  final repository = _Repository(result ?? [_lucia])..error = error;
  await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: kDoctorReferralsPath,
    routes: [
      GoRoute(
        path: kDoctorReferralsPath,
        builder: (_, _) => const DoctorReferralsScreen(),
      ),
    ],
    overrides: [
      issuedReferralRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  return repository;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

void main() {
  setUpAll(loadRoboto);

  group('la lista', () {
    testWidgets('abre pidiendo vencimiento y ascendente', (tester) async {
      final repository = await _pump(tester);

      expect(repository.queries, [
        {'orden': 'vencimiento', 'sentido': 'asc'},
      ]);
      expect(find.text('Pases emitidos'), findsOneWidget);
    });

    testWidgets('muestra los datos del pase', (tester) async {
      await _pump(tester);

      expect(find.byKey(const Key('referral-78')), findsOneWidget);
      expect(find.text('Lucía Fernández · CI 45678911'), findsOneWidget);
      expect(find.text('Especialidad de destino: Nutrición'), findsOneWidget);
      expect(find.text('Emitido el 20/10/2026 09:41'), findsOneWidget);
      expect(find.text('Vence el 18/01/2027'), findsOneWidget);
      expect(_text(tester, 'referral-status-78'), 'Disponible');
    });

    testWidgets('muestra la situación de cada pase', (tester) async {
      await _pump(tester, result: [_lucia, _bruno]);

      expect(_text(tester, 'referral-status-78'), 'Disponible');
      expect(_text(tester, 'referral-status-79'), 'Utilizado');
      expect(find.text('Emitido el 10/09/2026 15:05'), findsOneWidget);
    });
  });

  group('los filtros', () {
    testWidgets('empieza en "Todos"', (tester) async {
      await _pump(tester);

      expect(_selected(tester, 'referrals-filter-all'), isTrue);
      expect(_selected(tester, 'referrals-filter-used'), isFalse);
    });

    testWidgets('cada situación vuelve a pedir con su valor', (tester) async {
      final repository = await _pump(tester);

      await _tapKey(tester, 'referrals-filter-used');
      expect(repository.queries.last, {
        'situacion': 'UTILIZADO',
        'orden': 'vencimiento',
        'sentido': 'asc',
      });
      expect(_selected(tester, 'referrals-filter-used'), isTrue);

      await _tapKey(tester, 'referrals-filter-expired');
      expect(repository.queries.last['situacion'], 'VENCIDO');

      await _tapKey(tester, 'referrals-filter-available');
      expect(repository.queries.last['situacion'], 'DISPONIBLE');
      expect(repository.queries.length, 4);
    });

    testWidgets('"Todos" quita la situación', (tester) async {
      final repository = await _pump(tester);
      await _tapKey(tester, 'referrals-filter-used');

      await _tapKey(tester, 'referrals-filter-all');

      expect(repository.queries.last, {
        'orden': 'vencimiento',
        'sentido': 'asc',
      });
      expect(_selected(tester, 'referrals-filter-all'), isTrue);
    });

    testWidgets('el orden y el sentido vuelven a pedir', (tester) async {
      final repository = await _pump(tester);

      await _tapKey(tester, 'referrals-order');
      await tester.tap(find.text('Fecha de emisión').last);
      await tester.pumpAndSettle();
      expect(repository.queries.last, {'orden': 'emision', 'sentido': 'asc'});

      await _tapKey(tester, 'referrals-direction');
      expect(repository.queries.last, {'orden': 'emision', 'sentido': 'desc'});
      expect(find.text('Descendente'), findsOneWidget);
    });
  });

  group('los estados', () {
    testWidgets('vacío sin filtro', (tester) async {
      await _pump(tester, result: const []);

      expect(_text(tester, 'referrals-empty'), 'Todavía no emitiste pases.');
    });

    testWidgets('vacío con filtro', (tester) async {
      await _pump(tester, result: const []);

      await _tapKey(tester, 'referrals-filter-expired');

      expect(
        _text(tester, 'referrals-empty'),
        'No hay pases con esa situación.',
      );
    });

    testWidgets('el error muestra su mensaje y Reintentar vuelve a pedir', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        error: const ApiException('No pudimos cargar los pases.'),
      );

      expect(find.text('No pudimos cargar los pases.'), findsOneWidget);
      expect(find.byKey(const Key('referral-78')), findsNothing);

      repository.error = null;
      await _tapKey(tester, 'referrals-retry');

      expect(repository.queries.length, 2);
      expect(find.byKey(const Key('referral-78')), findsOneWidget);
      expect(find.text('No pudimos cargar los pases.'), findsNothing);
    });

    testWidgets('sin permiso muestra su mensaje', (tester) async {
      await _pump(
        tester,
        error: const IssuedReferralException(
          IssuedReferralFailure.forbidden,
          kIssuedReferralsForbiddenMessage,
        ),
      );

      expect(
        find.text('Tu cuenta no tiene permiso para consultar pases.'),
        findsOneWidget,
      );
    });
  });

  group('a 320 px de ancho (con Roboto)', () {
    testWidgets('la lista y los filtros no desbordan', (tester) async {
      await _pump(tester, result: [_lucia, _bruno], size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('referral-79')), findsOneWidget);

      await _tapKey(tester, 'referrals-order');
      await tester.tap(find.text('Fecha de emisión').last);
      await tester.pumpAndSettle();
      await _tapKey(tester, 'referrals-direction');
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error y el vacío no desbordan', (tester) async {
      await _pump(
        tester,
        error: const ApiException(
          'No pudimos conectarnos con el servidor. Revisá tu conexión a '
          'internet e intentá de nuevo.',
        ),
        size: const Size(320, 640),
      );

      expect(find.byKey(const Key('referrals-retry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
