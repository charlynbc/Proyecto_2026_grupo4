import '../../../core/fakes/fake_database.dart';
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import 'appointment_history_repository.dart';

/// Implementación en memoria de [AppointmentHistoryRepository] para
/// `USE_FAKES=true`. Lee la misma lista que llena `FakeAgendaRepository.book`
/// (`FakeDatabase.appointments`), así que lo que se agenda aparece en Mis
/// consultas. Filtra, ordena y pagina como el contrato del historial; no
/// calcula los estados `NO_ASISTIO` y `NO_ATENDIDA`.
class FakeAppointmentHistoryRepository implements AppointmentHistoryRepository {
  FakeAppointmentHistoryRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeDatabase _db;
  final Duration latency;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    await Future<void>.delayed(latency);
    final from = query.from;
    final to = query.to;
    final matches = [
      for (final a in _db.appointments)
        if ((query.status == null || a.status == query.status) &&
            (query.specialtyId == null ||
                a.specialty.id == query.specialtyId) &&
            (query.doctorId == null || a.doctor.id == query.doctorId) &&
            (from == null || !a.date.isBefore(from)) &&
            (to == null || !a.date.isAfter(to)))
          a,
    ];

    int byDate(Appointment a, Appointment b) {
      final byDay = a.date.compareTo(b.date);
      if (byDay != 0) return byDay;
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    }

    matches.sort(
      query.order == AppointmentHistoryOrder.date
          ? byDate
          : (a, b) {
              final bySpecialty = a.specialty.name.compareTo(b.specialty.name);
              return bySpecialty != 0 ? bySpecialty : byDate(a, b);
            },
    );
    final ordered = query.direction == AppointmentHistoryDirection.ascending
        ? matches
        : matches.reversed.toList();

    return AppointmentHistoryPage(
      items: ordered.skip(query.page * query.size).take(query.size).toList(),
      page: query.page,
      size: query.size,
      total: ordered.length,
    );
  }

  @override
  Future<Appointment> get(int id) async {
    await Future<void>.delayed(latency);
    for (final appointment in _db.appointments) {
      if (appointment.id == id) return appointment;
    }
    throw const AppointmentHistoryException(
      AppointmentHistoryFailure.notFound,
      'No se encontró la consulta.',
    );
  }
}
