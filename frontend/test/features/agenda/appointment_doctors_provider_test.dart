import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_doctor.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_doctors_provider.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _general = Specialty(
  id: 1,
  name: 'Medicina General',
  requiresReferral: false,
);
const _cardio = Specialty(id: 2, name: 'Cardiología', requiresReferral: true);
const _derm = Specialty(id: 3, name: 'Dermatología', requiresReferral: true);

const _mendez = DoctorRef(id: 1, firstName: 'Carla', lastName: 'Méndez');
const _acosta = DoctorRef(id: 3, firstName: 'Florencia', lastName: 'Acosta');
const _quiroga = DoctorRef(id: 9, firstName: 'Zoe', lastName: 'Quiroga');

Appointment _consulta(
  int id,
  DoctorRef doctor,
  Specialty specialty, {
  String status = 'ATENDIDA',
}) => Appointment(
  id: id,
  status: status,
  date: DateTime.utc(2026, 10, 20),
  number: 1,
  startMinutes: 480,
  endMinutes: 510,
  doctor: doctor,
  specialty: specialty,
  clinic: const Clinic(id: 1, name: 'Consultorio 1', location: 'Piso 1'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 10, 1, 15),
  cancelledAt: null,
  cancellationReason: null,
);

/// Responde por página con los [pages] que se le den (las que no figuran
/// vienen vacías) y el [total] que se le diga; anota cada pedido.
class _Repository implements AppointmentHistoryRepository {
  _Repository({required this.pages, required this.total, this.error});

  final Map<int, List<Appointment>> pages;
  final int total;
  final Object? error;
  final queries = <AppointmentHistoryQuery>[];

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    queries.add(query);
    if (error != null) throw error!;
    return AppointmentHistoryPage(
      items: pages[query.page] ?? const [],
      page: query.page,
      size: query.size,
      total: total,
    );
  }

  @override
  Future<Appointment> get(int id) => throw UnimplementedError();
}

Future<List<AppointmentDoctor>> _load(_Repository repository) async {
  final container = ProviderContainer(
    overrides: [
      appointmentHistoryRepositoryProvider.overrideWith(
        (ref) async => repository,
      ),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(appointmentDoctorsProvider, (_, _) {});
  addTearDown(subscription.close);
  return container.read(appointmentDoctorsProvider.future);
}

void main() {
  group('appointmentDoctorsProvider', () {
    test('pide las consultas sin filtros y con size 100', () async {
      final repository = _Repository(
        total: 3,
        pages: {
          0: [
            _consulta(1, _acosta, _derm, status: 'AGENDADA'),
            _consulta(2, _mendez, _general, status: 'CANCELADA_SOCIO'),
            _consulta(3, _mendez, _general),
          ],
        },
      );

      await _load(repository);

      expect(repository.queries, hasLength(1));
      expect(repository.queries.single.toQueryParameters(), {
        'orden': 'fecha',
        'sentido': 'desc',
        'page': 0,
        'size': 100,
      });
    });

    test('con total 20 hace una sola llamada', () async {
      final repository = _Repository(
        total: 20,
        pages: {
          0: [for (var i = 1; i <= 20; i++) _consulta(i, _mendez, _general)],
        },
      );

      await _load(repository);

      expect(repository.queries.map((q) => q.page), [0]);
    });

    test('con total 150 junta las dos páginas', () async {
      final repository = _Repository(
        total: 150,
        pages: {
          0: [for (var i = 1; i <= 100; i++) _consulta(i, _mendez, _general)],
          1: [for (var i = 101; i <= 150; i++) _consulta(i, _acosta, _derm)],
        },
      );

      final pairs = await _load(repository);

      expect(repository.queries.map((q) => q.page), [0, 1]);
      expect(repository.queries.map((q) => q.size), [100, 100]);
      expect(pairs.map((p) => (p.doctor.id, p.specialtyId)), [(1, 1), (3, 3)]);
    });

    test('se detiene a las 10 páginas aunque el total sea mayor', () async {
      final repository = _Repository(
        total: 5000,
        pages: {
          for (var page = 0; page < 20; page++)
            page: [
              for (var i = 0; i < 100; i++)
                _consulta(page * 100 + i + 1, _mendez, _general),
            ],
        },
      );

      await _load(repository);

      expect(repository.queries.map((q) => q.page), [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
    });

    test('si una página viene vacía no sigue pidiendo', () async {
      final repository = _Repository(
        total: 150,
        pages: {
          0: [for (var i = 1; i <= 100; i++) _consulta(i, _mendez, _general)],
        },
      );

      await _load(repository);

      expect(repository.queries.map((q) => q.page), [0, 1]);
    });

    test(
      'incluye al médico que solo aparece en una consulta cancelada',
      () async {
        final repository = _Repository(
          total: 2,
          pages: {
            0: [
              _consulta(1, _mendez, _general),
              _consulta(2, _quiroga, _cardio, status: 'CANCELADA_INSTITUCION'),
            ],
          },
        );

        final pairs = await _load(repository);

        expect(pairs.map((p) => (p.doctor.id, p.specialtyId)), [
          (1, 1),
          (9, 2),
        ]);
      },
    );

    test('guarda cada par médico y especialidad una sola vez', () async {
      final repository = _Repository(
        total: 4,
        pages: {
          0: [
            _consulta(1, _mendez, _general),
            _consulta(2, _mendez, _general),
            _consulta(3, _mendez, _cardio),
            _consulta(4, _acosta, _derm),
          ],
        },
      );

      final pairs = await _load(repository);

      expect(pairs.map((p) => (p.doctor.id, p.specialtyId)), [
        (1, 1),
        (1, 2),
        (3, 3),
      ]);
    });

    test('si falla el pedido, el error llega al proveedor', () async {
      final repository = _Repository(
        total: 0,
        pages: const {},
        error: const ApiException('falla de prueba'),
      );

      await expectLater(
        _load(repository),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'falla de prueba',
          ),
        ),
      );
    });
  });
}
