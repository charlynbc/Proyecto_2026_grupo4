import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesión de prueba sin login, renovación ni bootstrap.
class _TestSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'prueba-a',
    role: UserRole.socio,
  );
}

/// Fixture independiente con los campos del contrato de detalle.
MedicalHistoryEntry _entry({
  String condition = 'gripe',
  String? treatment = 'Reposo durante tres días',
  String? observations = 'Control de evolución',
  bool withReferrals = false,
}) => MedicalHistoryEntry.fromJson({
  'idAtencion': 10,
  'fechaAtencion': '2026-09-24',
  'medicoId': 4,
  'medicoNombre': 'Diego',
  'medicoApellido': 'Viera',
  'especialidad': {
    'id': 3,
    'nombre': 'Cardiología',
    'requierePase': true,
  },
  'afeccion': condition,
  'tratamiento': treatment,
  'observaciones': observations,
  'pases': withReferrals
      ? [
          {
            'id': 7,
            'especialidad': {
              'id': 5,
              'nombre': 'Traumatología',
              'requierePase': true,
            },
            'emitidoEn': '2026-09-24T10:00:00-03:00',
            'venceEl': '2026-12-23',
          },
          {
            'id': 8,
            'especialidad': {
              'id': 6,
              'nombre': 'Dermatología',
              'requierePase': true,
            },
            'emitidoEn': '2026-09-24T10:00:00-03:00',
            'venceEl': '2026-11-01',
          },
        ]
      : <dynamic>[],
});

class _DetailRepository implements MedicalHistoryRepository {
  _DetailRepository(this.response);

  Future<MedicalHistoryEntry> Function(int) response;
  final List<int> requestedIds = [];
  int listCalls = 0;

  @override
  Future<MedicalHistoryEntry> get(int id) {
    requestedIds.add(id);
    return response(id);
  }

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) {
    listCalls++;
    throw StateError('El detalle no debe consultar el listado.');
  }
}

Future<_TestSession> _pump(
  WidgetTester tester,
  _DetailRepository repository, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final session = _TestSession();
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => session),
      medicalHistoryRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
    ],
  );

  // Inicializa el doble antes de utilizar sus métodos.
  container.listen(sessionProvider, (_, _) {});

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appTheme,
        home: const MedicalHistoryDetailScreen(id: 10),
      ),
    ),
  );

  await tester.pump(const Duration(milliseconds: 1));
  if (settle) {
    await tester.pumpAndSettle();
  }

  return session;
}

Future<void> _retry(WidgetTester tester) async {
  final button = find.widgetWithText(OutlinedButton, 'Reintentar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los datos completos de la atención', (tester) async {
    final repository = _DetailRepository((_) async => _entry());

    await _pump(tester, repository);

    for (final text in [
      '24/09/2026',
      'Diego Viera',
      'Cardiología',
      'Afección',
      'gripe',
      'Tratamiento',
      'Reposo durante tres días',
      'Observaciones',
      'Control de evolución',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('consulta get por ID sin solicitar el listado', (tester) async {
    final repository = _DetailRepository((_) async => _entry());

    await _pump(tester, repository);

    expect(repository.requestedIds, [10]);
    expect(repository.listCalls, 0);
    expect(find.text('gripe'), findsOneWidget);
  });

  testWidgets('omite tratamiento y observaciones nulos', (tester) async {
    final repository = _DetailRepository(
      (_) async => _entry(treatment: null, observations: null),
    );

    await _pump(tester, repository);

    expect(find.text('gripe'), findsOneWidget);
    expect(find.text('Tratamiento'), findsNothing);
    expect(find.text('Observaciones'), findsNothing);
    expect(find.text('null'), findsNothing);
  });

  testWidgets('omite tratamiento vacío y observaciones con espacios',
      (tester) async {
    final repository = _DetailRepository(
      (_) async => _entry(treatment: '', observations: '   '),
    );

    await _pump(tester, repository);

    expect(find.text('gripe'), findsOneWidget);
    expect(find.text('Tratamiento'), findsNothing);
    expect(find.text('Observaciones'), findsNothing);
  });

  testWidgets('muestra los dos pases con sus vencimientos originales',
      (tester) async {
    final repository = _DetailRepository(
      (_) async => _entry(withReferrals: true),
    );

    await _pump(tester, repository);

    final first = find.byKey(const Key('history-referral-7'));
    final second = find.byKey(const Key('history-referral-8'));

    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(
      find.descendant(
        of: first,
        matching: find.textContaining('Traumatología'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: first,
        matching: find.textContaining('23/12/2026'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: second,
        matching: find.textContaining('Dermatología'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: second,
        matching: find.textContaining('01/11/2026'),
      ),
      findsOneWidget,
    );

    expect(find.textContaining('Disponible'), findsNothing);
    expect(find.textContaining('Utilizado'), findsNothing);
  });

  testWidgets('informa cuando la atención no tiene pases', (tester) async {
    final repository = _DetailRepository((_) async => _entry());

    await _pump(tester, repository);

    expect(
      find.text('No se emitieron pases en esta atención.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra carga sin datos clínicos hasta recibir la atención',
      (tester) async {
    final pending = Completer<MedicalHistoryEntry>();
    final repository = _DetailRepository((_) => pending.future);

    await _pump(tester, repository, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('gripe'), findsNothing);
    expect(find.text('Diego Viera'), findsNothing);
    expect(find.text('Reposo durante tres días'), findsNothing);
    expect(repository.requestedIds, [10]);

    pending.complete(_entry());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('gripe'), findsOneWidget);
    expect(find.text('Diego Viera'), findsOneWidget);
  });

  testWidgets('muestra el error y permite reintentar el mismo detalle',
      (tester) async {
    final repository = _DetailRepository(
      (_) async =>
          throw const ApiException('No pudimos cargar esta atención.'),
    );

    await _pump(tester, repository);

    expect(find.text('No pudimos cargar esta atención.'), findsOneWidget);
    expect(find.text('gripe'), findsNothing);
    expect(repository.requestedIds, [10]);

    repository.response = (_) async => _entry();
    await _retry(tester);

    expect(repository.requestedIds, [10, 10]);
    expect(repository.listCalls, 0);
    expect(find.text('gripe'), findsOneWidget);
    expect(find.text('No pudimos cargar esta atención.'), findsNothing);
  });

  testWidgets('informa una atención inexistente sin exponer datos ni códigos',
      (tester) async {
    final repository = _DetailRepository(
      (_) async => throw const MedicalHistoryNotFoundException(),
    );

    await _pump(tester, repository);

    expect(
      find.text(const MedicalHistoryNotFoundException().message),
      findsOneWidget,
    );
    expect(find.textContaining('HISTORIA_NO_ENCONTRADA'), findsNothing);
    expect(find.text('gripe'), findsNothing);
    expect(find.text('Diego Viera'), findsNothing);
    expect(find.text('Reposo durante tres días'), findsNothing);
  });

  testWidgets('retira los datos anteriores mientras cambia la sesión',
      (tester) async {
    final repository = _DetailRepository((_) async => _entry());
    final session = await _pump(tester, repository);

    expect(find.text('gripe'), findsOneWidget);
    expect(find.text('Control de evolución'), findsOneWidget);

    final next = Completer<MedicalHistoryEntry>();
    repository.response = (_) => next.future;

    session.setAuthenticated(
      accessToken: 'prueba-b',
      role: UserRole.socio,
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('gripe'), findsNothing);
    expect(find.text('Control de evolución'), findsNothing);
    expect(find.text('Reposo durante tres días'), findsNothing);
    expect(repository.requestedIds, [10, 10]);

    next.complete(
      _entry(
        condition: 'Control cardiovascular',
        treatment: null,
        observations: null,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Control cardiovascular'), findsOneWidget);
    expect(find.text('gripe'), findsNothing);
    expect(find.text('Control de evolución'), findsNothing);
    expect(find.text('Reposo durante tres días'), findsNothing);
  });
}
