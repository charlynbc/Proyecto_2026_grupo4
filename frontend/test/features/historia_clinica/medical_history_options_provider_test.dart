import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_repository.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_filters_controller.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_options_provider.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// No ejecuta login, renovación ni bootstrap de autenticación.
class _TestSession extends SessionNotifier {
  _TestSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

/// Usa las cuatro atenciones propias o una respuesta controlada, sin HTTP.
class _HistoryRepository implements MedicalHistoryRepository {
  final List<MedicalHistoryQuery> queries = [];
  final _fake = FakeMedicalHistoryRepository(latency: Duration.zero);
  Future<List<MedicalHistoryEntry>> Function()? response;

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) {
    queries.add(query);
    final answer = response;
    return answer == null ? _fake.list(query) : answer();
  }

  @override
  Future<MedicalHistoryEntry> get(int id) =>
      throw StateError('Las opciones no deben consultar detalles.');
}

/// Catálogo deliberadamente distinto del fake de historia clínica.
class _SpecialtyRepository implements SpecialtyRepository {
  int listCalls = 0;

  @override
  Future<List<Specialty>> list() async {
    listCalls++;
    return const [
      Specialty(id: 20, name: 'Cardiología', requiresReferral: true),
      Specialty(id: 30, name: 'Neurología', requiresReferral: false),
    ];
  }

  @override
  Future<Specialty> create({
    required String name,
    required bool requiresReferral,
  }) => throw StateError('Las opciones no deben crear especialidades.');
}

void main() {
  late ProviderContainer container;
  late _HistoryRepository history;
  late _SpecialtyRepository catalog;
  late _TestSession session;
  late int catalogEvaluations;

  void mount({bool useFakes = true, SessionState? initialSession}) {
    history = _HistoryRepository();
    catalog = _SpecialtyRepository();
    catalogEvaluations = 0;
    session = _TestSession(
      initialSession ??
          const SessionState(
            status: SessionStatus.authenticated,
            accessToken: 'prueba-a',
            role: UserRole.socio,
          ),
    );
    container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(useFakes),
        sessionProvider.overrideWith(() => session),
        medicalHistoryRepositoryProvider.overrideWith((ref) async => history),
        specialtyRepositoryProvider.overrideWith((ref) async {
          catalogEvaluations++;
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);
    // Inicializa y mantiene vivo el doble antes de invocar sus métodos.
    container.listen(sessionProvider, (_, _) {});
    container.listen(
      medicalHistoryOptionsProvider,
      (_, _) {},
      onError: (_, _) {},
    );
  }

  Future<void> settleProviders() async {
    await container.pump();
    await container.pump();
  }

  test('en Fake deduplica médicos y conserva los IDs de las atenciones',
      () async {
    mount();

    final options = await container.read(medicalHistoryOptionsProvider.future);

    expect(options.doctors, {
      4: 'Diego Viera',
      8: 'Laura Pérez',
      9: 'Ana Silva',
    });
    expect(options.doctors, hasLength(3));
    expect(history.queries, hasLength(1));
  });

  test('en Fake obtiene especialidades propias sin evaluar el catálogo',
      () async {
    mount();

    final options = await container.read(medicalHistoryOptionsProvider.future);

    expect(
      {for (final specialty in options.specialties) specialty.id: specialty.name},
      {3: 'Cardiología', 5: 'Traumatología', 6: 'Dermatología'},
    );
    expect(options.specialties, hasLength(3));
    expect(catalogEvaluations, 0);
    expect(catalog.listCalls, 0);
  });

  test('en API reutiliza el catálogo y obtiene médicos desde la historia',
      () async {
    mount(useFakes: false);

    final options = await container.read(medicalHistoryOptionsProvider.future);

    expect(
      {for (final specialty in options.specialties) specialty.id: specialty.name},
      {20: 'Cardiología', 30: 'Neurología'},
    );
    expect(options.specialties, hasLength(2));
    expect(options.doctors, {
      4: 'Diego Viera',
      8: 'Laura Pérez',
      9: 'Ana Silva',
    });
    expect(catalogEvaluations, 1);
    expect(catalog.listCalls, 1);
    expect(history.queries, hasLength(1));
  });

  test('los filtros aplicados no restringen ni recargan las opciones', () async {
    mount();
    container.listen(medicalHistoryFiltersProvider, (_, _) {});
    final filters = container.read(medicalHistoryFiltersProvider.notifier);
    filters.apply(specialtyId: 5, doctorId: 8, text: 'reposo');

    final initial = await container.read(medicalHistoryOptionsProvider.future);

    expect(initial.doctors, hasLength(3));
    expect(initial.specialties, hasLength(3));
    final query = history.queries.single;
    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.specialtyId, isNull);
    expect(query.doctorId, isNull);
    expect(query.text, isNull);

    filters.apply(doctorId: 4);
    filters.sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );
    await settleProviders();
    final updated = await container.read(medicalHistoryOptionsProvider.future);

    expect(updated.doctors, {
      4: 'Diego Viera',
      8: 'Laura Pérez',
      9: 'Ana Silva',
    });
    expect(
      updated.specialties.map((specialty) => specialty.id),
      unorderedEquals([3, 5, 6]),
    );
    expect(history.queries, hasLength(1));
  });

  test('sin sesión de socio no publica opciones ni consulta repositorios',
      () async {
    for (final initial in const [
      SessionState(),
      SessionState(
        status: SessionStatus.authenticated,
        accessToken: 'prueba-empleado',
        role: UserRole.funcionario,
      ),
    ]) {
      mount(useFakes: false, initialSession: initial);

      final options = await container.read(medicalHistoryOptionsProvider.future);

      expect(options.doctors, isEmpty);
      expect(options.specialties, isEmpty);
      expect(history.queries, isEmpty);
      expect(catalogEvaluations, 0);
      expect(catalog.listCalls, 0);
    }
  });

  test('cerrar sesión retira las opciones ya cargadas', () async {
    mount();
    final initial = await container.read(medicalHistoryOptionsProvider.future);
    expect(initial.doctors, hasLength(3));

    session.clear();
    await settleProviders();

    final state = container.read(medicalHistoryOptionsProvider);
    if (state.hasValue) {
      expect(state.requireValue.doctors, isEmpty);
      expect(state.requireValue.specialties, isEmpty);
    }
    final options = await container.read(medicalHistoryOptionsProvider.future);
    expect(options.doctors, isEmpty);
    expect(options.specialties, isEmpty);
    expect(history.queries, hasLength(1));
  });

  test('cambiar token retira opciones y descarta respuestas de la sesión anterior',
      () async {
    mount();
    await container.read(medicalHistoryOptionsProvider.future);
    final oldResponse = Completer<List<MedicalHistoryEntry>>();
    history.response = () => oldResponse.future;

    session.setAuthenticated(
      accessToken: 'prueba-b',
      role: UserRole.socio,
    );
    await settleProviders();

    expect(container.read(medicalHistoryOptionsProvider).hasValue, isFalse);
    expect(history.queries, hasLength(2));

    history.response = () async => <MedicalHistoryEntry>[];
    session.setAuthenticated(
      accessToken: 'prueba-c',
      role: UserRole.socio,
    );
    await settleProviders();
    final latest = await container.read(medicalHistoryOptionsProvider.future);
    expect(latest.doctors, isEmpty);
    expect(latest.specialties, isEmpty);

    oldResponse.complete(
      await FakeMedicalHistoryRepository(latency: Duration.zero)
          .list(const MedicalHistoryQuery()),
    );
    await settleProviders();

    final current = container.read(medicalHistoryOptionsProvider).requireValue;
    expect(current.doctors, isEmpty);
    expect(current.specialties, isEmpty);
    expect(history.queries, hasLength(3));
  });
}
