import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/agenda/widgets/appointment_card.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

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
    // La lista de médicos pide de a 100 y no cuenta como pedido del listado.
    if (query.size == 100) {
      return AppointmentHistoryPage(
        items: items,
        page: query.page,
        size: query.size,
        total: total,
      );
    }
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

// Las tres consultas de Ana Rodríguez en los datos falsos: Dermatología con
// Florencia Acosta (médico 3), y dos de Medicina General con Carla Méndez
// (médico 1), una cancelada por el socio y una atendida.
const _general = Specialty(
  id: 1,
  name: 'Medicina General',
  requiresReferral: false,
);
const _cardio = Specialty(id: 2, name: 'Cardiología', requiresReferral: true);
const _derm = Specialty(id: 3, name: 'Dermatología', requiresReferral: true);
const _mendez = DoctorRef(id: 1, firstName: 'Carla', lastName: 'Méndez');
const _acosta = DoctorRef(id: 3, firstName: 'Florencia', lastName: 'Acosta');

Appointment _consulta(
  int id,
  String status,
  DoctorRef doctor,
  Specialty specialty,
) => Appointment(
  id: id,
  status: status,
  date: DateTime.utc(2026, 10, 20),
  number: 1,
  startMinutes: 480,
  endMinutes: 510,
  doctor: doctor,
  specialty: specialty,
  clinic: const Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 10, 1, 15),
  cancelledAt: null,
  cancellationReason: null,
);

final _ana = [
  _consulta(101, 'AGENDADA', _acosta, _derm),
  _consulta(102, 'CANCELADA_SOCIO', _mendez, _general),
  _consulta(103, 'ATENDIDA', _mendez, _general),
];

/// El historial de Ana: filtra por estado, especialidad y médico como el
/// servidor, anota cada pedido y, con [pageSize], pagina de a pocas consultas
/// (solo los pedidos de la pantalla; la lista de médicos pide de a 100).
class _AnaRepository extends _HistoryRepository {
  _AnaRepository({
    this.pageSize,
    this.failDoctors = false,
    List<Appointment>? consultas,
  }) : consultas = consultas ?? _ana;

  final int? pageSize;
  final bool failDoctors;

  /// Las consultas que responde; se puede cambiar entre dos pedidos.
  List<Appointment> consultas;
  final queries = <AppointmentHistoryQuery>[];

  /// Si está, el pedido de la lista de médicos espera a que se complete.
  Completer<void>? doctorsGate;

  /// Los pedidos que hace la lista de médicos (size 100).
  List<AppointmentHistoryQuery> get doctorRequests => [
    for (final q in queries)
      if (q.size == 100) q,
  ];

  /// Los pedidos que hace el listado de la pantalla.
  List<AppointmentHistoryQuery> get listRequests => [
    for (final q in queries)
      if (q.size != 100) q,
  ];

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    queries.add(query);
    if (query.size == 100) {
      final gate = doctorsGate;
      if (gate != null) await gate.future;
      if (failDoctors) throw const ApiException('falla de prueba');
    }
    final matches = [
      for (final a in consultas)
        if ((query.status == null || a.status == query.status) &&
            (query.specialtyId == null ||
                a.specialty.id == query.specialtyId) &&
            (query.doctorId == null || a.doctor.id == query.doctorId))
          a,
    ];
    final size = query.size == 100 ? 100 : (pageSize ?? query.size);
    return AppointmentHistoryPage(
      items: matches.skip(query.page * size).take(size).toList(),
      page: query.page,
      size: size,
      total: matches.length,
    );
  }
}

Future<void> _pumpAna(WidgetTester tester, _AnaRepository repository) async {
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
          (ref) async => const [_general, _cardio, _derm],
        ),
      ],
      child: const MaterialApp(home: AppointmentsPendingScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

final _doctorDropdown = find.byKey(const Key('history-filter-doctor'));
final _specialtyDropdown = find.byKey(const Key('history-filter-specialty'));
final _statusDropdown = find.byKey(const Key('history-filter-status'));

DropdownButtonFormField<int?> _doctorField(WidgetTester tester) =>
    tester.widget<DropdownButtonFormField<int?>>(_doctorDropdown);

DropdownButtonFormField<int?> _specialtyField(WidgetTester tester) =>
    tester.widget<DropdownButtonFormField<int?>>(_specialtyDropdown);

/// Los textos de las opciones de un desplegable, en orden.
List<String> _labels(WidgetTester tester, Finder dropdown) => [
  for (final item
      in tester
          .widget<DropdownButton<int?>>(
            find.descendant(
              of: dropdown,
              matching: find.byType(DropdownButton<int?>),
            ),
          )
          .items!)
    (item.child as Text).data!,
];

Future<void> _choose(WidgetTester tester, Finder dropdown, String label) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

const _helpAll = 'Médicos de tus consultas';

/// Los estados con la etiqueta que muestra el desplegable, en su orden.
const _allStatusLabels = [
  'Todos',
  'Agendada',
  'Atendida',
  'Cancelada por el socio',
  'Cancelada por la institución',
  'No se presentó',
  'No asistió',
  'No atendida',
];

/// Los textos de las opciones del desplegable de Estado, en orden.
List<String> _statusLabels(WidgetTester tester) => [
  for (final item
      in tester
          .widget<DropdownButton<String?>>(
            find.descendant(
              of: _statusDropdown,
              matching: find.byType(DropdownButton<String?>),
            ),
          )
          .items!)
    (item.child as Text).data!,
];

/// Los tres desplegables de un vistazo: Estado, Especialidad y Médico.
({List<String> status, List<String> specialty, List<String> doctor}) _options(
  WidgetTester tester,
) => (
  status: _statusLabels(tester),
  specialty: _labels(tester, _specialtyDropdown),
  doctor: _labels(tester, _doctorDropdown),
);

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

  testWidgets('el detalle muestra la consulta sin acciones de cancelación', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    await _pump(tester, const AppointmentDetailScreen(id: 9001), repository);

    expect(repository.requestedId, 9001);
    expect(find.text('No atendida'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.byKey(const Key('cancel-appointment')), findsNothing);
    expect(find.byKey(const Key('cancel-appointment-disabled')), findsNothing);
    expect(find.byKey(const Key('cancellation-pending')), findsNothing);
    expect(find.text('Cancelar consulta'), findsNothing);
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

  group('filtro de médico', () {
    testWidgets('sin especialidad ofrece Todos y los médicos de las consultas, '
        'por nombre', (tester) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);

      expect(_labels(tester, _doctorDropdown), [
        'Todos',
        'Carla Méndez',
        'Florencia Acosta',
      ]);
      expect(find.text(_helpAll), findsOneWidget);
      expect(_doctorField(tester).onChanged, isNotNull);
    });

    testWidgets('con una especialidad ofrece solo los médicos de esa '
        'especialidad y lo dice', (tester) async {
      await _pumpAna(tester, _AnaRepository());

      await _choose(tester, _specialtyDropdown, 'Dermatología');

      expect(_labels(tester, _doctorDropdown), ['Todos', 'Florencia Acosta']);
      expect(
        find.text('Solo médicos de Dermatología en tus consultas'),
        findsOneWidget,
      );
      expect(find.text(_helpAll), findsNothing);

      await _choose(tester, _specialtyDropdown, 'Medicina General');

      expect(_labels(tester, _doctorDropdown), ['Todos', 'Carla Méndez']);
      expect(
        find.text('Solo médicos de Medicina General en tus consultas'),
        findsOneWidget,
      );
    });

    testWidgets('elegir un médico consulta con su id, vuelve a la página 1 y '
        'filtra el listado', (tester) async {
      final repository = _AnaRepository(pageSize: 2);
      await _pumpAna(tester, repository);
      expect(find.byKey(const Key('appointment-101')), findsOneWidget);
      expect(find.byKey(const Key('appointment-103')), findsNothing);
      await tester.tap(find.byKey(const Key('history-next')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2'), findsOneWidget);
      expect(repository.listRequests.last.page, 1);

      await _choose(tester, _doctorDropdown, 'Carla Méndez');

      expect(repository.listRequests.last.doctorId, 1);
      expect(repository.listRequests.last.specialtyId, isNull);
      expect(repository.listRequests.last.page, 0);
      expect(find.text('Página 1'), findsOneWidget);
      expect(find.text('2 consultas'), findsOneWidget);
      expect(find.byKey(const Key('appointment-102')), findsOneWidget);
      expect(find.byKey(const Key('appointment-103')), findsOneWidget);
      expect(find.byKey(const Key('appointment-101')), findsNothing);
    });

    testWidgets('si el médico sigue correspondiendo, se conserva', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      await _choose(tester, _doctorDropdown, 'Florencia Acosta');
      expect(repository.listRequests.last.doctorId, 3);

      await _choose(tester, _specialtyDropdown, 'Dermatología');

      expect(_doctorField(tester).initialValue, 3);
      expect(repository.listRequests.last.specialtyId, 3);
      expect(repository.listRequests.last.doctorId, 3);

      await _choose(tester, _specialtyDropdown, 'Todas');

      // La consulta (sin especialidad, médico 3) ya se había hecho y el
      // proveedor la tiene guardada: no hay pedido nuevo, se ve su lista.
      expect(_specialtyField(tester).initialValue, isNull);
      expect(_doctorField(tester).initialValue, 3);
      expect(find.byKey(const Key('appointment-101')), findsOneWidget);
      expect(find.byKey(const Key('appointment-102')), findsNothing);
      expect(find.byKey(const Key('appointment-103')), findsNothing);
    });

    // El desplegable de Especialidad ya no ofrece Cardiología (Ana no tiene
    // consultas de esa especialidad); se la pone llamando a onChanged.
    testWidgets('sin médicos para los filtros elegidos queda deshabilitado y '
        'lo explica', (tester) async {
      await _pumpAna(tester, _AnaRepository());

      _specialtyField(tester).onChanged!(2);
      await tester.pumpAndSettle();

      expect(_doctorField(tester).onChanged, isNull);
      expect(
        find.text('No tenés consultas con médicos para estos filtros'),
        findsOneWidget,
      );
      expect(_labels(tester, _doctorDropdown), ['Todos']);

      _specialtyField(tester).onChanged!(null);
      await tester.pumpAndSettle();

      expect(_doctorField(tester).onChanged, isNotNull);
      expect(
        find.text('No tenés consultas con médicos para estos filtros'),
        findsNothing,
      );
    });

    testWidgets('sin ninguna consulta el desplegable queda deshabilitado y '
        'lo dice', (tester) async {
      await _pumpAna(tester, _AnaRepository(consultas: const []));

      expect(_doctorField(tester).onChanged, isNull);
      expect(find.text('No tenés consultas con médicos'), findsOneWidget);
      expect(
        find.text('No tenés consultas con médicos para estos filtros'),
        findsNothing,
      );
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
    });

    testWidgets('la lista de médicos se pide una sola vez y cambiar filtros '
        'no la vuelve a pedir', (tester) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      expect(repository.doctorRequests, hasLength(1));
      expect(repository.doctorRequests.single.toQueryParameters(), {
        'orden': 'fecha',
        'sentido': 'desc',
        'page': 0,
        'size': 100,
      });

      await _choose(tester, _specialtyDropdown, 'Medicina General');
      await _choose(tester, _doctorDropdown, 'Carla Méndez');
      await _choose(tester, _statusDropdown, 'Atendida');
      await tester.tap(find.byKey(const Key('history-clear-filters')));
      await tester.pumpAndSettle();

      expect(repository.doctorRequests, hasLength(1));
      expect(repository.listRequests.length, greaterThan(3));
    });

    testWidgets('mientras carga, el desplegable está deshabilitado y avisa', (
      tester,
    ) async {
      final repository = _AnaRepository()..doctorsGate = Completer<void>();
      await _pumpAna(tester, repository);

      expect(_doctorField(tester).onChanged, isNull);
      expect(find.text('Cargando médicos'), findsOneWidget);
      expect(find.byKey(const Key('appointment-101')), findsOneWidget);

      repository.doctorsGate!.complete();
      await tester.pumpAndSettle();

      expect(_doctorField(tester).onChanged, isNotNull);
      expect(find.text('Cargando médicos'), findsNothing);
      expect(find.text(_helpAll), findsOneWidget);
    });

    testWidgets('si falla, avisa y el listado y los demás filtros siguen '
        'funcionando', (tester) async {
      final repository = _AnaRepository(failDoctors: true);
      await _pumpAna(tester, repository);

      expect(_doctorField(tester).onChanged, isNull);
      expect(find.text('No se pudieron cargar los médicos'), findsOneWidget);
      expect(find.byKey(const Key('appointment-101')), findsOneWidget);
      expect(find.byKey(const Key('appointment-103')), findsOneWidget);

      await _choose(tester, _statusDropdown, 'Atendida');

      expect(repository.listRequests.last.status, 'ATENDIDA');
      expect(find.byKey(const Key('appointment-103')), findsOneWidget);
      expect(find.byKey(const Key('appointment-101')), findsNothing);

      await _choose(tester, _specialtyDropdown, 'Medicina General');

      expect(repository.listRequests.last.specialtyId, 1);
      expect(find.text('No se pudieron cargar los médicos'), findsOneWidget);
    });

    testWidgets('ya no hay campo de ID ni botón Aplicar filtros', (
      tester,
    ) async {
      await _pumpAna(tester, _AnaRepository());

      expect(find.byType(TextField), findsNothing);
      expect(find.text('ID del médico'), findsNothing);
      expect(find.text('Aplicar filtros'), findsNothing);
      expect(find.byKey(const Key('history-apply-filters')), findsNothing);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('Médico'), findsOneWidget);
    });

    testWidgets('Limpiar vuelve el médico a Todos', (tester) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      await _choose(tester, _doctorDropdown, 'Carla Méndez');
      expect(_doctorField(tester).initialValue, 1);

      final clear = find.byKey(const Key('history-clear-filters'));
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(_doctorField(tester).initialValue, isNull);
      expect(find.byKey(const Key('appointment-101')), findsOneWidget);
      expect(find.byKey(const Key('appointment-102')), findsOneWidget);
      expect(find.byKey(const Key('appointment-103')), findsOneWidget);
    });
  });

  // Un desplegable solo ofrece valores para los que existe al menos una consulta
  // que coincida con lo elegido en los otros dos. Las opciones salen de las
  // consultas de Ana: (AGENDADA, Florencia Acosta, Dermatología),
  // (CANCELADA_SOCIO, Carla Méndez, Medicina General) y
  // (ATENDIDA, Carla Méndez, Medicina General).
  group('filtros cruzados', () {
    Future<void> refresh(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppointmentsPendingScreen)),
      );
      container.read(appointmentHistoryRefreshProvider.notifier).refresh();
      await tester.pumpAndSettle();
    }

    testWidgets('sin filtros cada desplegable ofrece todo lo que hay en las '
        'consultas', (tester) async {
      await _pumpAna(tester, _AnaRepository());

      final options = _options(tester);
      expect(options.status, [
        'Todos',
        'Agendada',
        'Atendida',
        'Cancelada por el socio',
      ]);
      expect(options.specialty, ['Todas', 'Dermatología', 'Medicina General']);
      expect(options.doctor, ['Todos', 'Carla Méndez', 'Florencia Acosta']);
    });

    testWidgets('con Carla Méndez: solo Medicina General y los estados de sus '
        'consultas', (tester) async {
      await _pumpAna(tester, _AnaRepository());

      await _choose(tester, _doctorDropdown, 'Carla Méndez');

      final options = _options(tester);
      expect(options.status, ['Todos', 'Atendida', 'Cancelada por el socio']);
      expect(options.specialty, ['Todas', 'Medicina General']);
      expect(options.doctor, ['Todos', 'Carla Méndez', 'Florencia Acosta']);
    });

    testWidgets('con Estado Agendada: solo Florencia Acosta y Dermatología', (
      tester,
    ) async {
      await _pumpAna(tester, _AnaRepository());

      await _choose(tester, _statusDropdown, 'Agendada');

      final options = _options(tester);
      expect(options.status, [
        'Todos',
        'Agendada',
        'Atendida',
        'Cancelada por el socio',
      ]);
      expect(options.specialty, ['Todas', 'Dermatología']);
      expect(options.doctor, ['Todos', 'Florencia Acosta']);
    });

    testWidgets(
      'con Dermatología: solo Florencia Acosta y el estado Agendada',
      (tester) async {
        await _pumpAna(tester, _AnaRepository());

        await _choose(tester, _specialtyDropdown, 'Dermatología');

        final options = _options(tester);
        expect(options.status, ['Todos', 'Agendada']);
        expect(options.specialty, [
          'Todas',
          'Dermatología',
          'Medicina General',
        ]);
        expect(options.doctor, ['Todos', 'Florencia Acosta']);
      },
    );

    testWidgets('con Atendida y Carla Méndez: solo Medicina General', (
      tester,
    ) async {
      await _pumpAna(tester, _AnaRepository());

      await _choose(tester, _statusDropdown, 'Atendida');
      await _choose(tester, _doctorDropdown, 'Carla Méndez');

      final options = _options(tester);
      expect(options.status, ['Todos', 'Atendida', 'Cancelada por el socio']);
      expect(options.specialty, ['Todas', 'Medicina General']);
      expect(options.doctor, ['Todos', 'Carla Méndez']);
    });

    testWidgets('después de elegir a Carla Méndez no se ofrece Dermatología ni '
        'Agendada', (tester) async {
      await _pumpAna(tester, _AnaRepository());
      expect(_labels(tester, _specialtyDropdown), contains('Dermatología'));
      expect(_statusLabels(tester), contains('Agendada'));

      await _choose(tester, _doctorDropdown, 'Carla Méndez');

      expect(
        _labels(tester, _specialtyDropdown),
        isNot(contains('Dermatología')),
      );
      expect(_statusLabels(tester), isNot(contains('Agendada')));
    });

    testWidgets('si el médico elegido deja de existir al refrescar, vuelve a '
        'Todos y se pide la página 1', (tester) async {
      final carla = [
        for (var i = 301; i <= 303; i++)
          _consulta(i, 'ATENDIDA', _mendez, _general),
      ];
      final florencia = _consulta(304, 'AGENDADA', _acosta, _derm);
      final repository = _AnaRepository(
        pageSize: 2,
        consultas: [...carla, florencia],
      );
      await _pumpAna(tester, repository);
      await _choose(tester, _doctorDropdown, 'Carla Méndez');
      await tester.tap(find.byKey(const Key('history-next')));
      await tester.pumpAndSettle();
      expect(repository.listRequests.last.doctorId, 1);
      expect(repository.listRequests.last.page, 1);
      expect(_doctorField(tester).initialValue, 1);

      repository.consultas = [florencia];
      await refresh(tester);

      expect(_doctorField(tester).initialValue, isNull);
      expect(repository.listRequests.last.doctorId, isNull);
      expect(repository.listRequests.last.page, 0);
      expect(find.text('Página 1'), findsOneWidget);
      expect(find.byKey(const Key('appointment-304')), findsOneWidget);
      expect(find.byKey(const Key('appointment-301')), findsNothing);
      expect(_labels(tester, _doctorDropdown), ['Todos', 'Florencia Acosta']);
    });

    testWidgets('si el estado elegido deja de existir al refrescar, vuelve a '
        'Todos', (tester) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      await _choose(tester, _statusDropdown, 'Agendada');
      expect(repository.listRequests.last.status, 'AGENDADA');

      repository.consultas = [_ana[1], _ana[2]];
      await refresh(tester);

      expect(find.text('Todos'), findsWidgets);
      expect(
        tester
            .widget<DropdownButtonFormField<String?>>(_statusDropdown)
            .initialValue,
        isNull,
      );
      expect(repository.listRequests.last.status, isNull);
      expect(repository.listRequests.last.page, 0);
      expect(_statusLabels(tester), [
        'Todos',
        'Atendida',
        'Cancelada por el socio',
      ]);
      expect(find.byKey(const Key('appointment-102')), findsOneWidget);
      expect(find.byKey(const Key('appointment-103')), findsOneWidget);
    });

    testWidgets('si la especialidad elegida deja de existir al refrescar, '
        'vuelve a Todas', (tester) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      await _choose(tester, _specialtyDropdown, 'Dermatología');
      expect(repository.listRequests.last.specialtyId, 3);

      repository.consultas = [_ana[1], _ana[2]];
      await refresh(tester);

      expect(_specialtyField(tester).initialValue, isNull);
      expect(repository.listRequests.last.specialtyId, isNull);
      expect(repository.listRequests.last.page, 0);
      expect(_labels(tester, _specialtyDropdown), [
        'Todas',
        'Medicina General',
      ]);
    });

    testWidgets('si lo elegido sigue existiendo al refrescar, se conserva', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      await _choose(tester, _doctorDropdown, 'Carla Méndez');

      await refresh(tester);

      expect(_doctorField(tester).initialValue, 1);
      expect(repository.listRequests.last.doctorId, 1);
    });

    testWidgets('mientras carga la lista, Estado y Especialidad ofrecen todo y '
        'Médico está deshabilitado', (tester) async {
      final repository = _AnaRepository()..doctorsGate = Completer<void>();
      await _pumpAna(tester, repository);

      expect(_statusLabels(tester), _allStatusLabels);
      expect(_labels(tester, _specialtyDropdown), [
        'Todas',
        'Medicina General',
        'Cardiología',
        'Dermatología',
      ]);
      expect(_doctorField(tester).onChanged, isNull);
      expect(find.text('Cargando médicos'), findsOneWidget);

      repository.doctorsGate!.complete();
      await tester.pumpAndSettle();

      expect(_statusLabels(tester), [
        'Todos',
        'Agendada',
        'Atendida',
        'Cancelada por el socio',
      ]);
      expect(_labels(tester, _specialtyDropdown), [
        'Todas',
        'Dermatología',
        'Medicina General',
      ]);
    });

    testWidgets('si la lista falla, Estado y Especialidad ofrecen todo y '
        'Médico está deshabilitado', (tester) async {
      await _pumpAna(tester, _AnaRepository(failDoctors: true));

      expect(_statusLabels(tester), _allStatusLabels);
      expect(_labels(tester, _specialtyDropdown), [
        'Todas',
        'Medicina General',
        'Cardiología',
        'Dermatología',
      ]);
      expect(_doctorField(tester).onChanged, isNull);
      expect(find.text('No se pudieron cargar los médicos'), findsOneWidget);
    });

    testWidgets('las fechas no cambian las opciones de los desplegables', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);
      final before = _options(tester);

      for (final key in ['history-date-from', 'history-date-to']) {
        final button = find.byKey(Key(key));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('cualquiera'), findsNothing);
      expect(repository.listRequests.last.from, isNotNull);
      expect(repository.listRequests.last.to, isNotNull);
      final after = _options(tester);
      expect(after.status, before.status);
      expect(after.specialty, before.specialty);
      expect(after.doctor, before.doctor);
      expect(after.doctor, ['Todos', 'Carla Méndez', 'Florencia Acosta']);
      expect(repository.doctorRequests, hasLength(1));
    });

    testWidgets('cambiar los tres filtros no vuelve a pedir la lista', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);

      await _choose(tester, _statusDropdown, 'Atendida');
      await _choose(tester, _specialtyDropdown, 'Medicina General');
      await _choose(tester, _doctorDropdown, 'Carla Méndez');
      await _choose(tester, _statusDropdown, 'Todos');

      expect(repository.doctorRequests, hasLength(1));
      expect(repository.listRequests.last.specialtyId, 1);
      expect(repository.listRequests.last.doctorId, 1);
    });
  });

  group('sentido del orden como botón', () {
    final direction = find.byKey(const Key('history-filter-direction'));

    testWidgets('ya no hay un desplegable "Sentido": arranca en Descendente', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);

      expect(find.text('Sentido'), findsNothing);
      expect(
        find.byType(DropdownButtonFormField<AppointmentHistoryDirection>),
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
      expect(
        repository.listRequests.last.toQueryParameters()['sentido'],
        'desc',
      );
    });

    testWidgets('al tocarlo alterna y pide asc, y vuelve a pedir desc', (
      tester,
    ) async {
      final repository = _AnaRepository();
      await _pumpAna(tester, repository);

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
      expect(
        repository.listRequests.last.toQueryParameters()['sentido'],
        'asc',
      );

      await tester.tap(direction);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: direction, matching: find.text('Descendente')),
        findsOneWidget,
      );
      // Vuelve a mostrar Descendente sin repetir el pedido: la consulta
      // descendente ya estaba guardada.
      expect(
        [
          for (final q in repository.listRequests)
            q.toQueryParameters()['sentido'],
        ],
        ['desc', 'asc'],
      );
    });
  });

  group('las tarjetas no muestran el ID de la consulta (RF-11)', () {
    testWidgets('las tres de Ana Rodríguez: Número 1 en las no canceladas y '
        'ningún ID', (tester) async {
      await _pumpAna(tester, _AnaRepository());

      expect(find.byType(AppointmentCard), findsNWidgets(3));
      // La agendada (101) y la atendida (103) muestran su número; la
      // cancelada (102), ninguno.
      expect(find.textContaining('Número 1'), findsNWidgets(2));
      expect(find.textContaining('ID '), findsNothing);
      expect(find.textContaining('000101'), findsNothing);
      expect(find.textContaining('000103'), findsNothing);
    });
  });

  // Va al final: Roboto se carga una sola vez por archivo y los tests que
  // vinieran después dejarían de usar la fuente de prueba. Con Roboto el texto
  // mide como en un celular; Ahem ensancha todo y daría desbordes que no
  // existen.
  group('filtros a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('el botón del sentido se ve completo y no desborda', (
      tester,
    ) async {
      await _pumpAna(tester, _AnaRepository());
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();

      expect(find.text('Descendente'), findsOneWidget);
      expect(
        tester.getRect(find.text('Descendente')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('los desplegables de filtros no desbordan', (tester) async {
      await _pump(
        tester,
        const AppointmentsPendingScreen(),
        _HistoryRepository(items: [_appointment], total: 1),
      );
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final key in [
        'history-filter-status',
        'history-filter-specialty',
        'history-filter-order',
        'history-filter-direction',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
    });

    testWidgets('los tres desplegables con los textos de ayuda no desbordan', (
      tester,
    ) async {
      await _pumpAna(tester, _AnaRepository());
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(find.text(_helpAll), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _choose(tester, _statusDropdown, 'Cancelada por el socio');
      await _choose(tester, _specialtyDropdown, 'Medicina General');
      expect(
        find.text('Solo médicos de Medicina General en tus consultas'),
        findsOneWidget,
      );
      await _choose(tester, _doctorDropdown, 'Carla Méndez');
      expect(tester.takeException(), isNull);

      _specialtyField(tester).onChanged!(2);
      await tester.pumpAndSettle();
      expect(
        find.text('No tenés consultas con médicos para estos filtros'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el desplegable de médico con un nombre largo no desborda', (
      tester,
    ) async {
      const long = DoctorRef(
        id: 7,
        firstName: 'María de los Ángeles Fernanda',
        lastName: 'Rodríguez de la Fuente y Hernández',
      );
      final repository = _AnaRepository(
        consultas: [
          _consulta(201, 'ATENDIDA', long, _general),
          _consulta(202, 'ATENDIDA', _mendez, _general),
        ],
      );
      await _pumpAna(tester, repository);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _choose(
        tester,
        _doctorDropdown,
        'María de los Ángeles Fernanda Rodríguez de la Fuente y Hernández',
      );

      expect(_doctorField(tester).initialValue, 7);
      expect(repository.listRequests.last.doctorId, 7);
      expect(tester.takeException(), isNull);
    });
  });
}
