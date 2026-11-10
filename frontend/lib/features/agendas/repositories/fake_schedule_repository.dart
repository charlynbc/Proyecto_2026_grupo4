import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/agenda_time.dart';
import '../../agenda/models/available_number.dart' show DoctorRef;
import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import '../models/schedule_entry.dart';
import '../models/schedule_filters.dart';
import '../models/schedule_page.dart';
import 'schedule_repository.dart';

/// Implementación en memoria de [ScheduleRepository] para `USE_FAKES=true`.
/// Tiene cinco consultas de hoy y aplica de verdad los filtros, el orden y la
/// paginación.
///
/// Los médicos, las especialidades y los consultorios son los de los datos
/// falsos que alimentan el selector de médicos (`FakeAdminDatabase`, ids 4, 6 y
/// 7 para los médicos): si cambian allá, hay que cambiarlos acá.
class FakeScheduleRepository implements ScheduleRepository {
  FakeScheduleRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime? today,
    List<ScheduleEntry>? entries,
  }) : _entries = entries != null
           ? List.of(entries)
           : _seed(today ?? UruguayTime.today());

  final Duration latency;
  final List<ScheduleEntry> _entries;

  /// Permite buscar consultas desde el fake de cancelación del funcionario.
  ScheduleEntry? findById(int id) {
    for (final entry in _entries) {
      if (entry.appointmentId == id) return entry;
    }
    return null;
  }

  /// Permite cancelar consultas desde el fake del funcionario.
  void markCancelled(int id) {
    final index = _entries.indexWhere((entry) => entry.appointmentId == id);
    if (index == -1) return;

    final entry = _entries[index];
    _entries[index] = ScheduleEntry(
      appointmentId: entry.appointmentId,
      member: entry.member,
      doctor: entry.doctor,
      specialty: entry.specialty,
      date: entry.date,
      startMinutes: entry.startMinutes,
      endMinutes: entry.endMinutes,
      clinic: entry.clinic,
      status: 'CANCELADA_SOCIO',
      arrivedAt: entry.arrivedAt,
    );
  }

  @override
  Future<SchedulePage> search(ScheduleFilters filters) async {
    await Future<void>.delayed(latency);
    // Los mismos valores que se mandarían al servidor: la cédula y el
    // identificador ya vienen solo con dígitos.
    final query = filters.toQueryParameters();
    final ci = query['ci'];
    final appointmentId = query['consultaId'];

    final matching = _entries.where((entry) {
      if (entry.date != filters.date) return false;
      if (ci != null && entry.member.ci != ci) return false;
      if (appointmentId != null && entry.appointmentId != appointmentId) {
        return false;
      }
      if (filters.doctorId != null && entry.doctor.id != filters.doctorId) {
        return false;
      }
      if (filters.status != null && entry.status != filters.status) {
        return false;
      }
      if (filters.arrived != null &&
          (entry.arrivedAt != null) != filters.arrived) {
        return false;
      }
      return true;
    }).toList()..sort(_comparator(filters));

    final start = filters.page * filters.size;
    final end = start + filters.size;
    return SchedulePage(
      items: start >= matching.length
          ? const []
          : matching.sublist(start, end.clamp(0, matching.length)),
      page: filters.page,
      size: filters.size,
      total: matching.length,
    );
  }

  /// Por fecha y hora de inicio, o por hora de llegada. En los dos, el
  /// identificador desempata. Con la llegada, los que no llegaron quedan al
  /// final en cualquier sentido.
  Comparator<ScheduleEntry> _comparator(ScheduleFilters filters) {
    final sign = filters.ascending ? 1 : -1;
    return switch (filters.order) {
      ScheduleOrder.dateTime => (a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return sign * byDate;
        final byStart = a.startMinutes.compareTo(b.startMinutes);
        if (byStart != 0) return sign * byStart;
        return sign * a.appointmentId.compareTo(b.appointmentId);
      },
      ScheduleOrder.arrivalTime => (a, b) {
        final arrivedA = a.arrivedAt;
        final arrivedB = b.arrivedAt;
        if (arrivedA != null && arrivedB != null) {
          final byArrival = arrivedA.compareTo(arrivedB);
          if (byArrival != 0) return sign * byArrival;
        } else if (arrivedA != null) {
          return -1;
        } else if (arrivedB != null) {
          return 1;
        }
        return a.appointmentId.compareTo(b.appointmentId);
      },
    };
  }

  static List<ScheduleEntry> _seed(DateTime today) {
    const mendez = DoctorRef(id: 4, firstName: 'Carla', lastName: 'Méndez');
    const silva = DoctorRef(id: 6, firstName: 'Esteban', lastName: 'Silva');
    const acosta = DoctorRef(id: 7, firstName: 'Florencia', lastName: 'Acosta');
    const general = Specialty(
      id: 1,
      name: 'Medicina General',
      requiresReferral: false,
    );
    const cardiology = Specialty(
      id: 2,
      name: 'Cardiología',
      requiresReferral: true,
    );
    const dermatology = Specialty(
      id: 3,
      name: 'Dermatología',
      requiresReferral: true,
    );
    const room3 = Clinic(id: 1, name: 'Consultorio 3', location: 'Planta baja');
    const room7 = Clinic(id: 2, name: 'Consultorio 7', location: 'Piso 1');
    const room12 = Clinic(id: 3, name: 'Consultorio 12', location: 'Piso 2');

    /// Hoy a las [time] (`HH:mm`) de Uruguay.
    DateTime arrival(String time) =>
        DateTime.parse('${formatApiDate(today)}T$time:00-03:00');

    ScheduleEntry entry(
      int id,
      ScheduleMember member,
      DoctorRef doctor,
      Specialty specialty,
      Clinic clinic,
      String start,
      String end,
      String status, {
      DateTime? arrivedAt,
    }) => ScheduleEntry(
      appointmentId: id,
      member: member,
      doctor: doctor,
      specialty: specialty,
      date: today,
      startMinutes: parseApiTime(start),
      endMinutes: parseApiTime(end),
      clinic: clinic,
      status: status,
      arrivedAt: arrivedAt,
    );

    return [
      entry(
        9001,
        const ScheduleMember(
          ci: '90000046',
          firstName: 'Ana',
          lastName: 'Fernández',
        ),
        mendez,
        general,
        room3,
        '09:00',
        '09:20',
        'AGENDADA',
        arrivedAt: arrival('08:55'),
      ),
      entry(
        9002,
        const ScheduleMember(
          ci: '90000052',
          firstName: 'Carlos',
          lastName: 'Rodríguez',
        ),
        mendez,
        general,
        room3,
        '09:20',
        '09:40',
        'NO_ATENDIDA',
        arrivedAt: arrival('08:40'),
      ),
      entry(
        9003,
        const ScheduleMember(
          ci: '90000068',
          firstName: 'Luis',
          lastName: 'Martínez',
        ),
        silva,
        cardiology,
        room7,
        '10:00',
        '10:30',
        'ATENDIDA',
      ),
      entry(
        9004,
        const ScheduleMember(
          ci: '90000074',
          firstName: 'Laura',
          lastName: 'Gómez',
        ),
        silva,
        cardiology,
        room7,
        '10:30',
        '11:00',
        'AGENDADA',
      ),
      entry(
        9005,
        const ScheduleMember(
          ci: '90000080',
          firstName: 'Pablo',
          lastName: 'Sosa',
        ),
        acosta,
        dermatology,
        room12,
        '15:00',
        '15:30',
        'CANCELADA_SOCIO',
      ),
    ];
  }
}
