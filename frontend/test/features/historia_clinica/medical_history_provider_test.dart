import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_filters_controller.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_provider.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reutiliza el estado de sesión sin ejecutar autenticación ni su bootstrap.
class _TestSession extends SessionNotifier {
  _TestSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

/// Registra pedidos y permite controlar sus respuestas, sin HTTP.
class _RecordingRepository implements MedicalHistoryRepository {
  final List<MedicalHistoryQuery> listQueries = [];
  final List<int> detailIds = [];

  Future<List<MedicalHistoryEntry>> Function(MedicalHistoryQuery)? listResponse;
  Future<MedicalHistoryEntry> Function(int)? detailResponse;

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) {
    listQueries.add(query);
    final response = listResponse;
    return response == null
        ? Future.value([_entry(12), _entry(10)])
        : response(query);
  }

  @override
  Future<MedicalHistoryEntry> get(int id) {
    detailIds.add(id);
    final response = detailResponse;
    return response == null ? Future.value(_entry(id)) : response(id);
  }
}

MedicalHistoryEntry _entry(int id, {String condition = 'gripe'}) =>
    MedicalHistoryEntry.fromJson({
      'idAtencion': id,
      'fechaAtencion': id == 12 ? '2026-10-02' : '2026-09-24',
      'medicoId': 4,
      'medicoNombre': 'Diego',
      'medicoApellido': 'Viera',
      'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
      'afeccion': condition,
      'tratamiento': null,
      'observaciones': null,
      'pases': <dynamic>[],
    });

void main() {
  late ProviderContainer container;
  late _RecordingRepository repository;
  late _TestSession session;

  void mount({SessionState? initialSession}) {
    repository = _RecordingRepository();
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
        sessionProvider.overrideWith(() => session),
        medicalHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  void watchList() {
    container.listen(medicalHistoryProvider, (_, _) {}, onError: (_, _) {});
  }

  void watchDetail(int id) {
    container.listen(
      medicalHistoryDetailProvider(id),
      (_, _) {},
      onError: (_, _) {},
    );
  }

  MedicalHistoryFiltersController filters() =>
      container.read(medicalHistoryFiltersProvider.notifier);

  Future<void> settleProviders() async {
    await container.pump();
    await container.pump();
  }

  void expectNoClinicalData() {
    final listState = container.read(medicalHistoryProvider);
    if (listState.hasValue) {
      expect(listState.requireValue, isEmpty);
    }
    expect(container.read(medicalHistoryDetailProvider(10)).hasValue, isFalse);
  }

  test('carga el listado con la consulta predeterminada', () async {
    mount();
    watchList();

    final entries = await container.read(medicalHistoryProvider.future);

    expect(entries.map((entry) => entry.id), [12, 10]);
    expect(repository.listQueries, hasLength(1));
    final query = repository.listQueries.single;
    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.specialtyId, isNull);
    expect(query.doctorId, isNull);
    expect(query.text, isNull);
    expect(query.order, MedicalHistoryOrder.date);
    expect(query.direction, MedicalHistoryDirection.descending);
  });

  test('actualiza la consulta al aplicar filtros y cambiar orden', () async {
    mount();
    watchList();
    await container.read(medicalHistoryProvider.future);

    filters().apply(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 10, 2),
      specialtyId: 3,
      doctorId: 4,
      text: 'reposo',
    );
    await settleProviders();
    await container.read(medicalHistoryProvider.future);

    expect(repository.listQueries, hasLength(2));
    final applied = repository.listQueries.last;
    expect(applied.from, DateTime.utc(2026, 9, 1));
    expect(applied.to, DateTime.utc(2026, 10, 2));
    expect(applied.specialtyId, 3);
    expect(applied.doctorId, 4);
    expect(applied.text, 'reposo');
    expect(applied.order, MedicalHistoryOrder.date);
    expect(applied.direction, MedicalHistoryDirection.descending);

    filters().sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );
    await settleProviders();
    await container.read(medicalHistoryProvider.future);

    expect(repository.listQueries, hasLength(3));
    final sorted = repository.listQueries.last;
    expect(sorted.from, DateTime.utc(2026, 9, 1));
    expect(sorted.to, DateTime.utc(2026, 10, 2));
    expect(sorted.specialtyId, 3);
    expect(sorted.doctorId, 4);
    expect(sorted.text, 'reposo');
    expect(sorted.order, MedicalHistoryOrder.specialty);
    expect(sorted.direction, MedicalHistoryDirection.ascending);
  });

  test('publica carga mientras espera y datos al completarse', () async {
    mount();
    final pending = Completer<List<MedicalHistoryEntry>>();
    repository.listResponse = (_) => pending.future;
    watchList();
    await settleProviders();

    final loading = container.read(medicalHistoryProvider);
    expect(loading.isLoading, isTrue);
    expect(loading.hasValue, isFalse);
    expect(repository.listQueries, hasLength(1));

    pending.complete([_entry(12)]);
    final entries = await container.read(medicalHistoryProvider.future);

    expect(entries.map((entry) => entry.id), [12]);
    expect(container.read(medicalHistoryProvider).isLoading, isFalse);
  });

  testWidgets('publica el error sin reintentar y permite reintento explícito', (
    tester,
  ) async {
    // Este caso dispone el contenedor dentro del reloj simulado, sin registrar
    // además la limpieza tardía que utiliza mount en los tests comunes.
    repository = _RecordingRepository();
    session = _TestSession(
      const SessionState(
        status: SessionStatus.authenticated,
        accessToken: 'prueba-a',
        role: UserRole.socio,
      ),
    );
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => session),
        medicalHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    try {
      const failure = ApiException('No pudimos cargar la historia clínica.');
      repository.listResponse = (_) async => throw failure;
      watchList();

      await expectLater(
        container.read(medicalHistoryProvider.future),
        throwsA(same(failure)),
      );
      await tester.pump(const Duration(seconds: 2));

      final failed = container.read(medicalHistoryProvider);
      expect(failed.hasError, isTrue);
      expect(failed.error, same(failure));
      expect(failed.hasValue, isFalse);
      expect(failed.isLoading, isFalse);
      expect(failed.retrying, isFalse);
      expect(repository.listQueries, hasLength(1));

      repository.listResponse = (_) async => [_entry(12)];
      container.invalidate(medicalHistoryProvider);
      await tester.pump(const Duration(milliseconds: 1));
      final entries = await container.read(medicalHistoryProvider.future);

      expect(repository.listQueries, hasLength(2));
      expect(entries.map((entry) => entry.id), [12]);
      expect(container.read(medicalHistoryProvider).hasError, isFalse);
    } finally {
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  test('carga el detalle mediante get sin consultar el listado', () async {
    mount();
    watchDetail(10);

    final entry = await container.read(medicalHistoryDetailProvider(10).future);

    expect(entry.id, 10);
    expect(repository.detailIds, [10]);
    expect(repository.listQueries, isEmpty);
  });

  test('conserva el error tipado de atención inexistente', () async {
    mount();
    repository.detailResponse = (_) async =>
        throw const MedicalHistoryNotFoundException();
    watchDetail(999);

    await expectLater(
      container.read(medicalHistoryDetailProvider(999).future),
      throwsA(isA<MedicalHistoryNotFoundException>()),
    );

    final failed = container.read(medicalHistoryDetailProvider(999));
    expect(failed.error, isA<MedicalHistoryNotFoundException>());
    expect(failed.hasValue, isFalse);
    expect(repository.detailIds, [999]);
    expect(repository.listQueries, isEmpty);
  });

  test(
    'sin sesión de socio válida no consulta ni publica datos clínicos',
    () async {
      const deniedSessions = [
        SessionState(),
        SessionState(status: SessionStatus.checking),
        SessionState(
          status: SessionStatus.authenticated,
          accessToken: 'prueba-empleado',
          role: UserRole.funcionario,
        ),
        SessionState(status: SessionStatus.authenticated, role: UserRole.socio),
        SessionState(
          status: SessionStatus.authenticated,
          accessToken: '',
          role: UserRole.socio,
        ),
      ];

      for (final initial in deniedSessions) {
        mount(initialSession: initial);
        watchList();
        watchDetail(10);

        await expectLater(
          container.read(medicalHistoryDetailProvider(10).future),
          throwsA(isA<ApiException>()),
        );
        final entries = await container.read(medicalHistoryProvider.future);

        expect(entries, isEmpty);
        expectNoClinicalData();
        expect(repository.listQueries, isEmpty);
        expect(repository.detailIds, isEmpty);
      }
    },
  );

  test('cerrar sesión retira los datos previamente cargados', () async {
    mount();
    watchList();
    watchDetail(10);
    await container.read(medicalHistoryProvider.future);
    await container.read(medicalHistoryDetailProvider(10).future);

    session.clear();
    await settleProviders();

    expectNoClinicalData();
    expect(repository.listQueries, hasLength(1));
    expect(repository.detailIds, [10]);
  });

  test(
    'cambiar token retira los datos anteriores y carga los nuevos',
    () async {
      mount();
      watchList();
      watchDetail(10);
      await container.read(medicalHistoryProvider.future);
      await container.read(medicalHistoryDetailProvider(10).future);

      final nextList = Completer<List<MedicalHistoryEntry>>();
      final nextDetail = Completer<MedicalHistoryEntry>();
      repository.listResponse = (_) => nextList.future;
      repository.detailResponse = (_) => nextDetail.future;

      session.setAuthenticated(accessToken: 'prueba-b', role: UserRole.socio);
      await settleProviders();

      expect(container.read(medicalHistoryProvider).hasValue, isFalse);
      expect(
        container.read(medicalHistoryDetailProvider(10)).hasValue,
        isFalse,
      );
      expect(repository.listQueries, hasLength(2));
      expect(repository.detailIds, [10, 10]);

      nextList.complete([_entry(12)]);
      nextDetail.complete(_entry(10, condition: 'Control cardiovascular'));
      final entries = await container.read(medicalHistoryProvider.future);
      final detail = await container.read(
        medicalHistoryDetailProvider(10).future,
      );

      expect(entries.map((entry) => entry.id), [12]);
      expect(detail.condition, 'Control cardiovascular');
    },
  );

  test(
    'respuestas antiguas no publican datos tras cambiar de sesión',
    () async {
      mount();
      final oldList = Completer<List<MedicalHistoryEntry>>();
      final oldDetail = Completer<MedicalHistoryEntry>();
      repository.listResponse = (_) => oldList.future;
      repository.detailResponse = (_) => oldDetail.future;
      watchList();
      watchDetail(10);
      await settleProviders();

      expect(repository.listQueries, hasLength(1));
      expect(repository.detailIds, [10]);

      session.clear();
      await settleProviders();
      expectNoClinicalData();
      expect(repository.listQueries, hasLength(1));
      expect(repository.detailIds, [10]);

      repository.listResponse = (_) async => [_entry(12)];
      repository.detailResponse = (_) async =>
          _entry(10, condition: 'Control cardiovascular');
      session.setAuthenticated(accessToken: 'prueba-b', role: UserRole.socio);
      await settleProviders();
      await container.read(medicalHistoryProvider.future);
      await container.read(medicalHistoryDetailProvider(10).future);

      oldList.complete([_entry(10)]);
      oldDetail.complete(_entry(10));
      await settleProviders();

      expect(
        container
            .read(medicalHistoryProvider)
            .requireValue
            .map((entry) => entry.id),
        [12],
      );
      expect(
        container.read(medicalHistoryDetailProvider(10)).requireValue.condition,
        'Control cardiovascular',
      );
      expect(repository.listQueries, hasLength(2));
      expect(repository.detailIds, [10, 10]);
    },
  );
}
