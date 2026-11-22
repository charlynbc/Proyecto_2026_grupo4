import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/core/widgets/sort_direction_button.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/models/issued_referral.dart';
import 'package:agenda_medica/features/medico/models/issued_referral_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/issued_referral_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/issued_referrals_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_issued_referral_repository.dart';
import 'package:agenda_medica/features/medico/repositories/issued_referral_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attention_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attentions_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_referral_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_referrals_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';

const _loadFailure = 'Fallo controlado al actualizar los pases.';

class _DoctorSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'medico-pases-estado-actual-prueba',
    role: UserRole.medico,
  );
}

class _ControlledIssuedReferralRepository implements IssuedReferralRepository {
  _ControlledIssuedReferralRepository(this._delegate);

  final FakeIssuedReferralRepository _delegate;
  final queries = <IssuedReferralQuery>[];
  bool failNextList = false;
  Completer<void>? _nextGate;
  Completer<void>? _activeGate;

  int get listCalls => queries.length;

  Completer<void> delayNextList() {
    final gate = Completer<void>();
    _nextGate = gate;
    return gate;
  }

  void releasePending() {
    final gates = [_nextGate, _activeGate];
    _nextGate = null;
    _activeGate = null;
    for (final gate in gates) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<List<IssuedReferral>> list(IssuedReferralQuery query) async {
    queries.add(query);
    final gate = _nextGate;
    _nextGate = null;
    if (gate != null) {
      _activeGate = gate;
      await gate.future;
      _activeGate = null;
    }
    if (failNextList) {
      failNextList = false;
      throw const ApiException(_loadFailure);
    }
    return _delegate.list(query);
  }
}

class _EmptyDoctorAttentionRepository implements DoctorAttentionRepository {
  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async => [];

  @override
  Future<DoctorAttention> get(int id) async {
    throw StateError('No se esperaba pedir el detalle de una atención.');
  }
}

class _Harness {
  const _Harness({
    required this.container,
    required this.router,
    required this.referrals,
    required this.repository,
  });

  final ProviderContainer container;
  final GoRouter router;
  final List<IssuedReferral> referrals;
  final _ControlledIssuedReferralRepository repository;
}

IssuedReferral _referral78(ReferralStatus status) => IssuedReferral(
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
  issuedAt: DateTime.parse('2026-10-20T09:41:00-03:00'),
  expiresOn: DateTime.utc(2027, 1, 18),
  status: status,
);

List<IssuedReferral> _testReferrals() => [
  _referral78(ReferralStatus.available),
  IssuedReferral(
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
    issuedAt: DateTime.parse('2026-09-10T15:05:00-03:00'),
    expiresOn: DateTime.utc(2026, 12, 9),
    status: ReferralStatus.used,
  ),
  IssuedReferral(
    id: 80,
    patient: const IssuedReferralPatient(
      id: 23,
      ci: '11111111',
      name: 'Ana',
      lastName: 'Pérez',
    ),
    destination: const Specialty(
      id: 2,
      name: 'Dermatología',
      requiresReferral: true,
    ),
    issuedAt: DateTime.parse('2026-06-01T10:00:00-03:00'),
    expiresOn: DateTime.utc(2026, 8, 30),
    status: ReferralStatus.expired,
  ),
];

void _markReferral78Used(List<IssuedReferral> referrals) {
  final index = referrals.indexWhere((referral) => referral.id == 78);
  final current = referrals[index];
  referrals[index] = IssuedReferral(
    id: current.id,
    patient: current.patient,
    destination: current.destination,
    issuedAt: current.issuedAt,
    expiresOn: current.expiresOn,
    status: ReferralStatus.used,
  );
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_Harness> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final referrals = _testReferrals();
  final fake = FakeIssuedReferralRepository(
    latency: Duration.zero,
    referrals: referrals,
  );
  final repository = _ControlledIssuedReferralRepository(fake);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_DoctorSession.new),
      issuedReferralRepositoryProvider.overrideWith((ref) async => repository),
      doctorAttentionRepositoryProvider.overrideWith(
        (ref) async => _EmptyDoctorAttentionRepository(),
      ),
      specialtiesProvider.overrideWith(
        (ref) async => const [
          Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
        ],
      ),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go(kDoctorReferralsPath);
  addTearDown(() async {
    repository.releasePending();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  expect(find.byType(DoctorReferralsScreen), findsOneWidget);
  expect(_status(78), findsOneWidget);
  expect(tester.widget<Text>(_status(78)).data, 'Disponible');

  return _Harness(
    container: container,
    router: router,
    referrals: referrals,
    repository: repository,
  );
}

Finder _card(int id) => find.byKey(Key('referral-$id'));

Finder _status(int id) => find.byKey(Key('referral-status-$id'));

Future<void> _leaveAndReturn(WidgetTester tester, _Harness harness) async {
  harness.router.go(kDoctorAttentionsPath);
  await _settle(tester);
  expect(find.byType(DoctorAttentionsScreen), findsOneWidget);
  harness.router.go(kDoctorReferralsPath);
  await _settle(tester);
  expect(find.byType(DoctorReferralsScreen), findsOneWidget);
}

Future<void> _pumpUntilListCalls(
  WidgetTester tester,
  _ControlledIssuedReferralRepository repository,
  int expected,
) async {
  for (
    var attempt = 0;
    attempt < 12 && repository.listCalls < expected;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _chooseOrder(
  WidgetTester tester,
  IssuedReferralOrder order,
  String label,
) async {
  final dropdown = find.byKey(const Key('referrals-order'));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await _settle(tester);
  expect(
    tester.widget<DropdownButton<IssuedReferralOrder>>(dropdown).value,
    order,
  );
}

void main() {
  testWidgets('al volver de otra sección muestra el estado nuevo del pase 78', (
    tester,
  ) async {
    final harness = await _pump(tester);

    harness.router.go(kDoctorAttentionsPath);
    await _settle(tester);
    expect(find.byType(DoctorAttentionsScreen), findsOneWidget);
    _markReferral78Used(harness.referrals);
    harness.router.go(kDoctorReferralsPath);
    await _settle(tester);

    expect(_status(78), findsOneWidget);
    expect(tester.widget<Text>(_status(78)).data, 'Utilizado');
  });

  testWidgets('al volver del segundo plano muestra el estado nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _markReferral78Used(harness.referrals);

    backgroundAndReturn(tester);
    await _settle(tester);

    expect(_status(78), findsOneWidget);
    expect(tester.widget<Text>(_status(78)).data, 'Utilizado');
  });

  testWidgets(
    'al volver conserva filtro, orden y sentido y muestra el estado nuevo',
    (tester) async {
      final harness = await _pump(tester);

      await tester.tap(find.byKey(const Key('referrals-filter-used')));
      await _settle(tester);
      await _chooseOrder(tester, IssuedReferralOrder.issue, 'Fecha de emisión');
      await tester.tap(find.byKey(const Key('referrals-direction')));
      await _settle(tester);

      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('referrals-filter-used')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<DropdownButton<IssuedReferralOrder>>(
              find.byKey(const Key('referrals-order')),
            )
            .value,
        IssuedReferralOrder.issue,
      );
      expect(
        tester
            .widget<SortDirectionButton>(
              find.byKey(const Key('referrals-direction')),
            )
            .ascending,
        isFalse,
      );

      _markReferral78Used(harness.referrals);
      await _leaveAndReturn(tester, harness);

      expect(
        harness.container.read(issuedReferralFiltersProvider),
        const IssuedReferralQuery(
          status: ReferralStatus.used,
          order: IssuedReferralOrder.issue,
          direction: IssuedReferralDirection.descending,
        ),
      );
      expect(_card(78), findsOneWidget);
      expect(tester.widget<Text>(_status(78)).data, 'Utilizado');
    },
  );

  testWidgets('al volver hace un pedido y conserva la lista durante la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _markReferral78Used(harness.referrals);
    harness.router.go(kDoctorAttentionsPath);
    await _settle(tester);
    final gate = harness.repository.delayNextList();

    harness.router.go(kDoctorReferralsPath);
    await _pumpUntilListCalls(tester, harness.repository, 2);

    // Cuenta la carga inicial y el único pedido al volver.
    expect(harness.repository.listCalls, 2);
    // La lista anterior sigue visible mientras espera el segundo pedido.
    expect(tester.widget<Text>(_status(78)).data, 'Disponible');
    // No se muestra un indicador durante la recarga.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(tester.widget<Text>(_status(78)).data, 'Utilizado');
  });

  testWidgets('si falla al volver ofrece reintentar y carga los datos', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _markReferral78Used(harness.referrals);
    harness.router.go(kDoctorAttentionsPath);
    await _settle(tester);
    harness.repository.failNextList = true;

    harness.router.go(kDoctorReferralsPath);
    await _settle(tester);

    // Al volver debería haberse hecho un segundo pedido.
    expect(harness.repository.listCalls, 2);
    expect(
      find.text('Fallo controlado al actualizar los pases.'),
      findsOneWidget,
    );
    final retry = find.byKey(const Key('referrals-retry'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await _settle(tester);
    expect(tester.widget<Text>(_status(78)).data, 'Utilizado');
  });

  testWidgets(
    'al cambiar el filtro de estado muestra carga y oculta la lista anterior',
    (tester) async {
      final harness = await _pump(tester);
      final gate = harness.repository.delayNextList();

      await tester.tap(find.byKey(const Key('referrals-filter-used')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.repository.listCalls, 2);
      // Historia clínica y Atenciones muestran carga al cambiar el filtro.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_card(78), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(_card(79), findsOneWidget);
      expect(_card(78), findsNothing);
    },
  );
}
