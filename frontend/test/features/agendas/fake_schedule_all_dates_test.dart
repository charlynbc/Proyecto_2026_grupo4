import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sin fecha, el Fake responde como el servidor (contrato, fila 28): todas las
/// fechas, ordenadas por fecha y hora (o por llegada) con el identificador
/// ascendente como desempate, y paginadas.

final _d1 = DateTime.utc(2026, 10, 25);
final _d2 = DateTime.utc(2026, 10, 26);
final _d3 = DateTime.utc(2026, 10, 27);

const _ana = ScheduleMember(
  ci: '90000046',
  firstName: 'Ana',
  lastName: 'Fernández',
);
const _luis = ScheduleMember(
  ci: '90000068',
  firstName: 'Luis',
  lastName: 'Martínez',
);

ScheduleEntry _e(
  int id,
  ScheduleMember member,
  DateTime date,
  int start, {
  String status = 'AGENDADA',
  DateTime? arrivedAt,
}) => ScheduleEntry(
  appointmentId: id,
  member: member,
  doctor: const DoctorRef(id: 4, firstName: 'Carla', lastName: 'Méndez'),
  specialty: const Specialty(
    id: 1,
    name: 'Medicina General',
    requiresReferral: false,
  ),
  date: date,
  startMinutes: start,
  endMinutes: start + 20,
  clinic: const Clinic(id: 1, name: 'Consultorio 3', location: 'Planta baja'),
  status: status,
  arrivedAt: arrivedAt,
);

// Seis consultas en tres días, escritas fuera de orden a propósito.
//   25/10: 102 Ana 09:00, 105 Luis 09:00 (cancelada)
//   26/10: 101 Ana 10:00, 106 Ana 10:00
//   27/10: 103 Luis 08:00, 104 Ana 09:00
// 102 llegó el 25/10 a las 08:30 y 104 el 27/10 a las 08:50 (Uruguay).
List<ScheduleEntry> _entries() => [
  _e(101, _ana, _d2, 600),
  _e(103, _luis, _d3, 480),
  _e(104, _ana, _d3, 540, arrivedAt: DateTime.utc(2026, 10, 27, 11, 50)),
  _e(105, _luis, _d1, 540, status: 'CANCELADA_SOCIO'),
  _e(102, _ana, _d1, 540, arrivedAt: DateTime.utc(2026, 10, 25, 11, 30)),
  _e(106, _ana, _d2, 600),
];

FakeScheduleRepository _repository() =>
    FakeScheduleRepository(latency: Duration.zero, entries: _entries());

List<int> _ids(SchedulePage page) => [
  for (final entry in page.items) entry.appointmentId,
];

ScheduleFilters _all({
  String? ci,
  String? status,
  ScheduleOrder order = ScheduleOrder.dateTime,
  bool ascending = true,
  int page = 0,
  int size = 20,
}) => ScheduleFilters(
  date: null,
  ci: ci,
  status: status,
  order: order,
  ascending: ascending,
  page: page,
  size: size,
);

void main() {
  group('sin fecha', () {
    test(
      'devuelve las consultas de todos los días, por fecha y hora',
      () async {
        final page = await _repository().search(_all());

        expect(_ids(page), [102, 105, 101, 106, 103, 104]);
        expect(page.total, 6);
      },
    );

    test('con la CI de Ana, solo las suyas de los tres días', () async {
      final page = await _repository().search(_all(ci: '9.000.004-6'));

      expect(_ids(page), [102, 101, 106, 104]);
      expect(page.total, 4);
    });

    test('con la CI de Luis, las suyas de dos días', () async {
      final page = await _repository().search(_all(ci: '90000068'));

      expect(_ids(page), [105, 103]);
    });

    test('con una fecha sigue dando solo ese día', () async {
      final page = await _repository().search(_all().copyWith(date: () => _d2));

      expect(_ids(page), [101, 106]);
      expect(page.total, 2);
    });

    test('con un estado, lo filtra en todos los días', () async {
      final page = await _repository().search(_all(status: 'CANCELADA_SOCIO'));

      expect(_ids(page), [105]);
    });

    test('descendente: lo último primero y el identificador menor primero '
        'en un empate de fecha y hora', () async {
      final page = await _repository().search(_all(ascending: false));

      expect(_ids(page), [104, 103, 101, 106, 102, 105]);
    });

    test('por hora de llegada: los que llegaron primero y los demás por '
        'fecha y hora', () async {
      final page = await _repository().search(
        _all(order: ScheduleOrder.arrivalTime),
      );

      expect(_ids(page), [102, 104, 105, 101, 106, 103]);
    });

    test('por hora de llegada descendente: la llegada más nueva primero y '
        'los demás de la fecha más nueva a la más vieja', () async {
      final page = await _repository().search(
        _all(order: ScheduleOrder.arrivalTime, ascending: false),
      );

      expect(_ids(page), [104, 102, 103, 101, 106, 105]);
    });

    test('pagina de a 2 con el total de todos los días', () async {
      final repository = _repository();

      final first = await repository.search(_all(size: 2));
      final second = await repository.search(_all(size: 2, page: 1));
      final last = await repository.search(_all(size: 2, page: 2));

      expect(_ids(first), [102, 105]);
      expect(_ids(second), [101, 106]);
      expect(_ids(last), [103, 104]);
      expect(first.total, 6);
      expect(last.total, 6);
    });

    test('una página más allá de la última viene vacía con el total', () async {
      final page = await _repository().search(_all(size: 2, page: 3));

      expect(page.items, isEmpty);
      expect(page.total, 6);
    });
  });
}
