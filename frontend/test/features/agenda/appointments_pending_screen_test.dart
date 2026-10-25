import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _appointment = Appointment(
  id: 9001,
  status: 'NO_ATENDIDA',
  date: DateTime.utc(2026, 10, 20),
  number: 2,
  startMinutes: 560,
  endMinutes: 580,
  doctor: DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
  clinic: Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.parse('2026-10-20T10:12:45-03:00'),
  cancelledAt: null,
  cancellationReason: null,
);

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository({this.items = const [], this.total = 0, this.error});

  final List<Appointment> items;
  final int total;
  final Object? error;
  int? requestedId;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    if (error != null) throw error!;
    return AppointmentHistoryPage(
      items: items,
      page: query.page,
      size: query.size,
      total: total,
    );
  }

  @override
  Future<Appointment> get(int id) async {
    requestedId = id;
    if (error != null) throw error!;
    return _appointment;
  }
}

/// Responde distinto por página: las que no figuran vienen vacías con total 0.
class _PagedHistoryRepository extends _HistoryRepository {
  _PagedHistoryRepository(this.pages);

  final Map<int, ({List<Appointment> items, int total})> pages;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    final page = pages[query.page] ?? (items: const <Appointment>[], total: 0);
    return AppointmentHistoryPage(
      items: page.items,
      page: query.page,
      size: query.size,
      total: page.total,
    );
  }
}

const _loadFailure = 'No pudimos cargar tus consultas de prueba.';

/// Falla la primera vez que se pide la [failingPage] y después responde bien.
/// Anota las páginas pedidas, en orden.
class _FlakyHistoryRepository extends _HistoryRepository {
  _FlakyHistoryRepository({
    required this.failingPage,
    super.items,
    super.total,
  });

  final int failingPage;
  bool _failed = false;
  final requestedPages = <int>[];

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    requestedPages.add(query.page);
    if (query.page == failingPage && !_failed) {
      _failed = true;
      throw const ApiException(_loadFailure);
    }
    return AppointmentHistoryPage(
      items: items,
      page: query.page,
      size: query.size,
      total: total,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _HistoryRepository repository,
) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        specialtiesProvider.overrideWith(
          (ref) async => const [
            Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
          ],
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra consultas reales, estados y acceso al detalle', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(items: [_appointment], total: 1),
    );

    expect(find.text('Mis consultas'), findsOneWidget);
    expect(find.text('Cardiología · No atendida'), findsOneWidget);
    expect(find.textContaining('09:20 - 09:40'), findsOneWidget);
    expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
    expect(find.byKey(const Key('history-next')), findsOneWidget);
  });

  testWidgets('muestra el estado vacío cuando no hay consultas', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(),
    );
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });

  testWidgets('presenta un error de autenticación específico', (tester) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(
        error: const AppointmentHistoryException(
          AppointmentHistoryFailure.unauthenticated,
          'No autenticado',
        ),
      ),
    );
    expect(
      find.text(
        'Tu sesión venció. Iniciá sesión nuevamente para ver tus consultas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el detalle muestra la consulta y cancelación deshabilitada', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    await _pump(tester, const AppointmentDetailScreen(id: 9001), repository);

    expect(repository.requestedId, 9001);
    expect(find.text('No atendida'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(
      find.byKey(const Key('cancel-appointment-disabled')),
      findsOneWidget,
    );
    final cancel = tester.widget<OutlinedButton>(
      find.byKey(const Key('cancel-appointment-disabled')),
    );
    expect(cancel.onPressed, isNull);
  });

  testWidgets('el detalle diferencia una consulta inexistente', (tester) async {
    await _pump(
      tester,
      const AppointmentDetailScreen(id: 9001),
      _HistoryRepository(
        error: const AppointmentHistoryException(
          AppointmentHistoryFailure.notFound,
          'No encontrada',
        ),
      ),
    );

    expect(find.text('No se encontró esta consulta.'), findsOneWidget);
  });

  group('página vacía después de la primera', () {
    const emptyPageText = 'Esta página ya no tiene consultas.';

    Future<void> goToNextPage(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('history-next')));
      await tester.pumpAndSettle();
    }

    bool isEnabled(WidgetTester tester, String key) =>
        tester.widget<TextButton>(find.byKey(Key(key))).onPressed != null;

    testWidgets('con el total real avisa y deja volver a la anterior', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _PagedHistoryRepository({
          0: (items: [_appointment], total: 25),
          1: (items: const [], total: 25),
        }),
      );
      expect(find.byKey(const Key('appointment-9001')), findsOneWidget);

      await goToNextPage(tester);

      expect(find.byKey(const Key('history-empty-page')), findsOneWidget);
      expect(find.text(emptyPageText), findsOneWidget);
      expect(find.byKey(const Key('history-empty')), findsNothing);
      expect(find.text('Página 2'), findsOneWidget);
      expect(isEnabled(tester, 'history-previous'), isTrue);
      expect(isEnabled(tester, 'history-next'), isFalse);

      await tester.tap(find.byKey(const Key('history-previous')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-empty-page')), findsNothing);
      expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
      expect(find.text('Página 1'), findsOneWidget);
    });

    testWidgets('con total 0 muestra el mismo aviso y el mismo botón', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _PagedHistoryRepository({
          0: (items: [_appointment], total: 25),
          1: (items: const [], total: 0),
        }),
      );

      await goToNextPage(tester);

      expect(find.text(emptyPageText), findsOneWidget);
      expect(find.byKey(const Key('history-empty-page')), findsOneWidget);
      expect(find.byKey(const Key('history-empty')), findsNothing);
      expect(isEnabled(tester, 'history-previous'), isTrue);
      expect(isEnabled(tester, 'history-next'), isFalse);
    });

    testWidgets('la primera página vacía no muestra la fila de paginación', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _HistoryRepository(),
      );

      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.byKey(const Key('history-empty-page')), findsNothing);
      expect(find.byKey(const Key('history-previous')), findsNothing);
      expect(find.byKey(const Key('history-next')), findsNothing);
      expect(find.textContaining('Página'), findsNothing);
    });
  });

  group('error de carga del historial', () {
    final retry = find.text('Reintentar');

    testWidgets('el mensaje va en el color de error del tema', (tester) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _FlakyHistoryRepository(failingPage: 0),
      );
      final message = find.text(_loadFailure);
      expect(message, findsOneWidget);

      final element = tester.element(message);
      final scheme = Theme.of(element).colorScheme;
      final drawn = DefaultTextStyle.of(element).style
          .merge(tester.widget<Text>(message).style)
          .color;

      expect(scheme.error, isNot(scheme.onSurface));
      expect(drawn, scheme.error);
    });

    testWidgets('"Reintentar" vuelve a pedir y muestra la lista', (
      tester,
    ) async {
      final repository = _FlakyHistoryRepository(
        failingPage: 0,
        items: [_appointment],
        total: 1,
      );
      await _pump(tester, const AppointmentsPendingScreen(), repository);
      expect(find.text(_loadFailure), findsOneWidget);
      expect(find.byKey(const Key('appointment-9001')), findsNothing);

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
      expect(find.text(_loadFailure), findsNothing);
      expect(repository.requestedPages, [0, 0]);
    });

    testWidgets('"Reintentar" pide la página en la que estaba el socio', (
      tester,
    ) async {
      final repository = _FlakyHistoryRepository(
        failingPage: 1,
        items: [_appointment],
        total: 25,
      );
      await _pump(tester, const AppointmentsPendingScreen(), repository);
      await tester.tap(find.byKey(const Key('history-next')));
      await tester.pumpAndSettle();
      expect(find.text(_loadFailure), findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repository.requestedPages, [0, 1, 1]);
      expect(find.text('Página 2'), findsOneWidget);
      expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
      expect(find.text(_loadFailure), findsNothing);
    });

    testWidgets('con el error no hay tarjetas ni fila de paginación', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _FlakyHistoryRepository(
          failingPage: 0,
          items: [_appointment],
          total: 1,
        ),
      );

      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(find.byKey(const Key('appointment-9001')), findsNothing);
      expect(find.byKey(const Key('history-previous')), findsNothing);
      expect(find.byKey(const Key('history-next')), findsNothing);
      expect(find.textContaining('Página'), findsNothing);
    });
  });
}
