import 'dart:math' as math;

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
/// paginación. Con `relativeTo` las dos agendadas salen del reloj.
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

  FakeScheduleRepository._(this.latency, this._entries);

  /// Las mismas cinco consultas de hoy, pero con las dos agendadas puestas
  /// respecto de [clock] (por defecto, la hora real): la 9001 empieza dentro de
  /// una hora, así que ya no se puede cancelar (faltan menos de dos horas), y
  /// la 9004 dentro de tres, así que sí. De esa forma, a cualquier hora del día
  /// se prueban los dos caminos de la cancelación. Las horas se redondean hacia
  /// arriba a múltiplos de 5 minutos; cerca de medianoche pasan al día
  /// siguiente. Es lo que usa la app con `USE_FAKES`; las pruebas arman el
  /// repositorio con `today` o `entries`, con horas fijas.
  factory FakeScheduleRepository.relativeTo({
    Duration latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) => FakeScheduleRepository._(
    latency,
    _relativeSeed((clock ?? DateTime.now)()),
  );

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
  void markCancelled(int id, {String status = 'CANCELADA_SOCIO'}) {
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
      status: status,
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
      // Sin fecha se ven las consultas de todos los días, como en el servidor.
      if (filters.date != null && entry.date != filters.date) return false;
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

  /// El mismo orden que el servidor (contrato, fila 28): por fecha y hora de
  /// inicio, o por hora de llegada con los que no llegaron al final en
  /// cualquier sentido y, entre iguales, por fecha y hora. En los dos, el
  /// identificador ascendente desempata, también con el sentido descendente.
  Comparator<ScheduleEntry> _comparator(ScheduleFilters filters) {
    final sign = filters.ascending ? 1 : -1;
    int byDateTime(ScheduleEntry a, ScheduleEntry b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return sign * byDate;
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      if (byStart != 0) return sign * byStart;
      return a.appointmentId.compareTo(b.appointmentId);
    }

    return switch (filters.order) {
      ScheduleOrder.dateTime => byDateTime,
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
        return byDateTime(a, b);
      },
    };
  }

  static List<ScheduleEntry> _relativeSeed(DateTime now) {
    final local = UruguayTime.toUruguay(now);
    final today = DateTime.utc(local.year, local.month, local.day);

    ScheduleEntry retime(ScheduleEntry entry, Duration ahead) {
      final target = local.add(ahead);
      final hasSeconds = target.second > 0 || target.millisecond > 0;
      var minutes = target.hour * 60 + target.minute + (hasSeconds ? 1 : 0);
      minutes = ((minutes + 4) ~/ 5) * 5;
      var date = DateTime.utc(target.year, target.month, target.day);
      if (minutes >= 24 * 60) {
        date = date.add(const Duration(days: 1));
        minutes -= 24 * 60;
      }
      return ScheduleEntry(
        appointmentId: entry.appointmentId,
        member: entry.member,
        doctor: entry.doctor,
        specialty: entry.specialty,
        date: date,
        startMinutes: minutes,
        endMinutes: math.min(minutes + 20, 24 * 60 - 1),
        clinic: entry.clinic,
        status: entry.status,
        arrivedAt: null,
      );
    }

    return [
      for (final entry in _seed(today))
        switch (entry.appointmentId) {
          9001 => retime(entry, const Duration(hours: 1)),
          9004 => retime(entry, const Duration(hours: 3)),
          _ => entry,
        },
    ];
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
