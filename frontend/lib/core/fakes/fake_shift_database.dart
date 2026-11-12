import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/auth/models/user_role.dart';
import '../../features/consultorios/models/clinic.dart';
import '../../features/especialidades/models/specialty.dart';
import '../../features/turnos/models/doctor.dart';
import '../../features/turnos/models/clinic_change_preview.dart';
import '../../features/turnos/models/new_weekly_shift.dart';
import '../../features/turnos/models/shift.dart';
import '../../features/turnos/models/shift_filters.dart';
import '../../features/turnos/models/shift_page.dart';
import '../../features/turnos/models/shift_number.dart';
import '../../features/turnos/models/shift_numbers_rules.dart';
import '../../features/turnos/models/shift_state.dart';
import '../../features/turnos/models/weekday_names.dart';
import '../../features/turnos/models/weekly_shift.dart';
import '../../features/turnos/repositories/shift_repository.dart';
import '../../features/turnos/repositories/shift_reinstatement_repository.dart';
import '../../features/turnos/repositories/weekly_shift_clinic_repository.dart';
import '../../features/usuarios/models/user_account.dart';
import '../utils/text_fold.dart';
import '../utils/uruguay_time.dart';
import 'fake_admin_database.dart';

/// Una fecha concreta de un turno semanal, como la guarda el servidor falso.
/// Además de lo que muestra el listado (`TurnoDTO`) guarda sus [numbers], que
/// hacen falta para detectar cruces.
class FakeShift {
  FakeShift({
    required this.id,
    required this.weeklyShiftId,
    required this.date,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.numbers,
    required this.doctorId,
    required this.specialtyId,
    required this.clinicId,
  });

  final int id;
  final int weeklyShiftId;

  /// Clave de día en UTC.
  final DateTime date;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final List<ShiftNumber> numbers;
  final int doctorId;
  final int specialtyId;
  int clinicId;

  ShiftState _state = ShiftState.active;
  ShiftState get state => _state;
}

/// Estado en memoria de los turnos del funcionario. Lee médicos,
/// especialidades y consultorios de [FakeAdminDatabase] pero no la modifica.
/// Se pierde al recargar la app.
class FakeShiftDatabase {
  FakeShiftDatabase(this.admin, {bool seed = true}) {
    if (seed) _seed();
  }

  final FakeAdminDatabase admin;

  final List<WeeklyShift> weeklyShifts = [];
  final List<FakeShift> shifts = [];

  /// Consultas agendadas por configuración, escrito a mano. La clave es el
  /// id de la configuración y el valor, la cantidad.
  final Map<int, int> agendadasPorTurnoSemanal = {};

  /// Para la vista previa parcial, las reservas se asocian a una fecha concreta.
  final Map<int, int> agendadasPorTurno = {};

  int _nextWeeklyShiftId = 1;
  int _nextShiftId = 1;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Suspende una fecha concreta. Los turnos suspendidos no generan cruces.
  void suspendShift(int shiftId) {
    shifts.firstWhere((s) => s.id == shiftId)._state = ShiftState.suspended;
  }

  /// Los médicos activos (cuenta de médico en estado activo), con sus
  /// especialidades.
  List<Doctor> activeDoctors() => [
    for (final account in admin.accounts)
      if (account.role == UserRole.medico &&
          account.status == AccountStatus.active)
        Doctor(
          id: account.id,
          firstName: account.firstName,
          lastName: account.lastName,
          specialties: [
            for (final id in account.specialtyIds)
              ...admin.specialties.where((s) => s.id == id),
          ],
        ),
  ];

  /// Las reglas de RF-13, en este orden: médico existe, médico activo,
  /// especialidad del médico, consultorio existe, fechas, reglas de los
  /// números y, al final, cruces. Si algo falla no se crea nada.
  WeeklyShift createWeeklyShift(NewWeeklyShift data) {
    final doctor = admin.accounts.where(
      (a) => a.id == data.doctorId && a.role == UserRole.medico,
    );
    if (doctor.isEmpty) throw const ShiftNotFoundException();
    final account = doctor.first;
    if (account.status != AccountStatus.active) {
      throw const InactiveDoctorException();
    }
    if (!account.specialtyIds.contains(data.specialtyId)) {
      throw const SpecialtyNotOfDoctorException();
    }
    final clinics = admin.clinics.where((c) => c.id == data.clinicId);
    if (clinics.isEmpty) throw const ShiftNotFoundException();
    final Specialty specialty = admin.specialties.firstWhere(
      (s) => s.id == data.specialtyId,
    );
    final Clinic clinic = clinics.first;

    if (data.weekday < 1 || data.weekday > 7) {
      throw const ShiftValidationException('Elegí un día de la semana.');
    }
    if (data.endDate.isBefore(data.startDate)) {
      throw const ShiftValidationException(
        'La fecha de fin tiene que ser igual o posterior a la de inicio.',
      );
    }
    final dates = weekdayDatesOf(data.startDate, data.endDate, data.weekday);
    if (dates.isEmpty) {
      throw ShiftValidationException(
        'Entre el ${_format(data.startDate)} y el ${_format(data.endDate)} '
        'no hay ningún ${weekdayName(data.weekday)}. Elegí otro día o '
        'ampliá las fechas.',
      );
    }
    final numberErrors = validateNumbers(data.numbers);
    if (numberErrors.isNotEmpty) {
      throw ShiftValidationException(numberErrors.join(' '));
    }

    _checkOverlaps(data, dates);

    final weeklyShiftId = _nextWeeklyShiftId++;
    final firstStart = data.numbers
        .map((n) => n.startMinutes)
        .reduce((a, b) => a < b ? a : b);
    final lastEnd = data.numbers
        .map((n) => n.endMinutes)
        .reduce((a, b) => a > b ? a : b);
    for (final date in dates) {
      shifts.add(
        FakeShift(
          id: _nextShiftId++,
          weeklyShiftId: weeklyShiftId,
          date: date,
          weekday: data.weekday,
          startMinutes: firstStart,
          endMinutes: lastEnd,
          numbers: List.unmodifiable(data.numbers),
          doctorId: account.id,
          specialtyId: data.specialtyId,
          clinicId: data.clinicId,
        ),
      );
    }
    final weeklyShift = WeeklyShift(
      id: weeklyShiftId,
      doctor: DoctorRef(
        id: account.id,
        firstName: account.firstName,
        lastName: account.lastName,
      ),
      specialty: specialty,
      clinic: clinic,
      weekday: data.weekday,
      startDate: data.startDate,
      endDate: data.endDate,
      numbers: List.unmodifiable(data.numbers),
      shiftCount: dates.length,
    );
    weeklyShifts.add(weeklyShift);
    return weeklyShift;
  }

  /// Lo que muestra el listado de una fecha concreta (`TurnoDTO`): los datos
  /// del médico, la especialidad y el consultorio salen de [admin].
  Shift toShift(FakeShift shift) {
    final doctor = admin.accounts.firstWhere((a) => a.id == shift.doctorId);
    return Shift(
      id: shift.id,
      weeklyShiftId: shift.weeklyShiftId,
      date: shift.date,
      weekday: shift.weekday,
      startMinutes: shift.startMinutes,
      endMinutes: shift.endMinutes,
      doctor: DoctorRef(
        id: doctor.id,
        firstName: doctor.firstName,
        lastName: doctor.lastName,
      ),
      specialty: admin.specialties.firstWhere((s) => s.id == shift.specialtyId),
      clinic: admin.clinics.firstWhere((c) => c.id == shift.clinicId),
      numberCount: shift.numbers.length,
      state: shift.state,
    );
  }

  /// Filtra, ordena y pagina como lo hará el servidor (contrato #15).
  ///
  /// `size` fuera de 1 a 100, `page` negativa y un "desde" posterior al
  /// "hasta" son `VALIDACION`. Por `medico` se ordena por apellido y nombre;
  /// por `especialidad`, por su nombre: sin distinguir mayúsculas ni tildes.
  /// `sentido` invierte ese criterio principal; los empates se desempatan
  /// siempre por fecha y horario ascendentes.
  ShiftPage listShifts(ShiftFilters filters) {
    if (filters.size < 1 || filters.size > 100) {
      throw const ShiftValidationException(
        'El tamaño de la página tiene que estar entre 1 y 100.',
      );
    }
    if (filters.page < 0) {
      throw const ShiftValidationException(
        'El número de página no puede ser negativo.',
      );
    }
    final from = filters.fromDate;
    final to = filters.toDate;
    if (from != null && to != null && from.isAfter(to)) {
      throw const ShiftValidationException(
        'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
      );
    }

    final matching = [
      for (final shift in shifts)
        if ((filters.doctorId == null || shift.doctorId == filters.doctorId) &&
            (filters.specialtyId == null ||
                shift.specialtyId == filters.specialtyId) &&
            (filters.weekday == null || shift.weekday == filters.weekday) &&
            (from == null || !shift.date.isBefore(from)) &&
            (to == null || !shift.date.isAfter(to)) &&
            (filters.state == null || shift.state == filters.state))
          toShift(shift),
    ];

    int byDateAndTime(Shift a, Shift b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    }

    int primary(Shift a, Shift b) => switch (filters.order) {
      ShiftOrder.date => byDateAndTime(a, b),
      ShiftOrder.doctor => _compareDoctors(a.doctor, b.doctor),
      ShiftOrder.specialty => foldForSort(
        a.specialty.name,
      ).compareTo(foldForSort(b.specialty.name)),
    };

    matching.sort((a, b) {
      final order = primary(a, b);
      if (order != 0) return filters.ascending ? order : -order;
      return byDateAndTime(a, b);
    });

    final start = filters.page * filters.size;
    final items = start >= matching.length
        ? <Shift>[]
        : matching.sublist(
            start,
            (start + filters.size).clamp(0, matching.length),
          );
    return ShiftPage(
      items: items,
      page: filters.page,
      size: filters.size,
      total: matching.length,
    );
  }

  static int _compareDoctors(DoctorRef a, DoctorRef b) {
    final byLastName = foldForSort(a.lastName)
        .compareTo(foldForSort(b.lastName));
    return byLastName != 0
        ? byLastName
        : foldForSort(a.firstName).compareTo(foldForSort(b.firstName));
  }

  WeeklyShift? weeklyShiftById(int id) {
    for (final weeklyShift in weeklyShifts) {
      if (weeklyShift.id == id) return weeklyShift;
    }
    return null;
  }

  /// Busca cruces de los números nuevos con los de los turnos activos del
  /// mismo médico o del mismo consultorio, en cada fecha del período.
  void _checkOverlaps(NewWeeklyShift data, List<DateTime> dates) {
    final conflictDates = <DateTime>{};
    final conflictNumbers = <int>{};
    var byDoctor = false;
    var byClinic = false;

    for (final existing in shifts) {
      if (existing.state != ShiftState.active) continue;
      if (!dates.contains(existing.date)) continue;
      final sameDoctor = existing.doctorId == data.doctorId;
      final sameClinic = existing.clinicId == data.clinicId;
      if (!sameDoctor && !sameClinic) continue;
      for (final mine in data.numbers) {
        final crosses = existing.numbers.any(
          (other) =>
              mine.startMinutes < other.endMinutes &&
              other.startMinutes < mine.endMinutes,
        );
        if (!crosses) continue;
        conflictDates.add(existing.date);
        conflictNumbers.add(mine.number);
        byDoctor = byDoctor || sameDoctor;
        byClinic = byClinic || sameClinic;
      }
    }
    if (conflictDates.isEmpty) return;

    final sortedDates = conflictDates.toList()..sort();
    final sortedNumbers = conflictNumbers.toList()..sort();
    final owner = byDoctor && byClinic
        ? 'del médico y del consultorio'
        : byDoctor
        ? 'del médico'
        : 'del consultorio';
    final numbersLabel = sortedNumbers.length == 1
        ? 'número ${sortedNumbers.single}'
        : 'números ${_joinWithAnd(sortedNumbers.map((n) => '$n').toList())}';
    throw OverlappingShiftException(
      'No se pudo guardar: los horarios se cruzan con turnos activos $owner '
      'el ${_joinWithAnd(sortedDates.map(_format).toList())} '
      '($numbersLabel). Cambiá los horarios o las fechas y volvé a guardar.',
    );
  }

  static String _format(DateTime date) => _dateFormat.format(date);

  static String _joinWithAnd(List<String> items) => items.length <= 1
      ? items.join()
      : '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';

  /// Turnos de ejemplo a partir de la semana que viene, con una fecha
  /// suspendida, para poder probar el listado y los cruces.
  void _seed() {
    final now = UruguayTime.toUruguay(admin.clock());
    final today = DateTime.utc(now.year, now.month, now.day);
    // El próximo lunes (si hoy es lunes, el de la semana siguiente).
    final monday = DateTime.utc(
      today.year,
      today.month,
      today.day + (8 - today.weekday),
    );
    DateTime inWeeks(int weeks) =>
        DateTime.utc(monday.year, monday.month, monday.day + 7 * weeks);

    final byLastName = {
      for (final a in admin.accounts)
        if (a.role == UserRole.medico && a.status == AccountStatus.active)
          a.lastName: a,
    };
    final clinics = admin.clinics;
    final morning = [
      ShiftNumber(number: 1, startMinutes: 9 * 60, endMinutes: 9 * 60 + 20),
      ShiftNumber(
        number: 2,
        startMinutes: 9 * 60 + 20,
        endMinutes: 9 * 60 + 40,
      ),
      ShiftNumber(number: 3, startMinutes: 9 * 60 + 40, endMinutes: 10 * 60),
    ];
    final afternoon = [
      ShiftNumber(number: 1, startMinutes: 15 * 60, endMinutes: 15 * 60 + 30),
      ShiftNumber(number: 2, startMinutes: 15 * 60 + 30, endMinutes: 16 * 60),
    ];

    final first = createWeeklyShift(
      NewWeeklyShift(
        doctorId: byLastName['Méndez']!.id,
        specialtyId: 1,
        clinicId: clinics[0].id,
        weekday: 1,
        startDate: inWeeks(0),
        endDate: inWeeks(4),
        numbers: morning,
      ),
    );
    createWeeklyShift(
      NewWeeklyShift(
        doctorId: byLastName['Silva']!.id,
        specialtyId: 2,
        clinicId: clinics[1].id,
        weekday: 2,
        startDate: inWeeks(0),
        endDate: inWeeks(5),
        numbers: afternoon,
      ),
    );
    createWeeklyShift(
      NewWeeklyShift(
        doctorId: byLastName['Acosta']!.id,
        specialtyId: 3,
        clinicId: clinics[2].id,
        weekday: 4,
        startDate: inWeeks(1),
        endDate: inWeeks(6),
        numbers: morning,
      ),
    );
    suspendShift(shifts.firstWhere((s) => s.weeklyShiftId == first.id).id);
    // Silva (configuración 2) tiene dos consultas agendadas, para ver el
    // error a mano.
    agendadasPorTurnoSemanal[2] = 2;
    agendadasPorTurno[shifts.firstWhere((s) => s.weeklyShiftId == 2).id] = 2;
  }

  /// Calcula la vista previa sin tocar el estado de los turnos (RF-20).
  /// Las fechas suspendidas se muestran, pero no generan solapamientos:
  /// RF-15 los volverá a validar cuando se rehabiliten.
  ClinicChangePreview previewClinicChange(int weeklyShiftId, int clinicId) {
    if (weeklyShiftId <= 0 || clinicId <= 0) {
      throw const ShiftValidationException('Identificadores no válidos');
    }
    if (weeklyShiftById(weeklyShiftId) == null) {
      throw const ShiftNotFoundException('No existe el turno semanal indicado');
    }
    if (!admin.clinics.any((clinic) => clinic.id == clinicId)) {
      throw const ShiftNotFoundException('No existe el consultorio indicado');
    }

    final now = UruguayTime.toUruguay(admin.clock());
    final today = DateTime.utc(now.year, now.month, now.day);
    final future = [
      for (final shift in shifts)
        if (shift.weeklyShiftId == weeklyShiftId &&
            !shift.date.isBefore(today))
          shift,
    ]..sort((a, b) => a.date.compareTo(b.date));

    return ClinicChangePreview(
      dates: [
        for (final shift in future)
          ClinicChangePreviewDate(
            shiftId: shift.id,
            date: shift.date,
            state: shift.state,
            bookedAppointments: agendadasPorTurno[shift.id] ??
                (shift == future.first
                    ? (agendadasPorTurnoSemanal[weeklyShiftId] ?? 0)
                    : 0),
            currentClinicId: shift.clinicId,
            currentClinicName: admin.clinics
                .firstWhere((clinic) => clinic.id == shift.clinicId)
                .name,
            overlaps: [
              if (shift.state == ShiftState.active)
                for (final other in shifts)
                  if (other.weeklyShiftId != weeklyShiftId &&
                      other.state == ShiftState.active &&
                      other.date == shift.date &&
                      (other.doctorId == shift.doctorId ||
                          other.clinicId == clinicId))
                    for (final own in shift.numbers)
                      for (final existing in other.numbers)
                        if (own.startMinutes < existing.endMinutes &&
                            existing.startMinutes < own.endMinutes)
                          ClinicChangeOverlap(
                            ownNumber: own.number,
                            existingNumber: existing.number,
                          ),
            ],
          ),
      ],
    );
  }

  /// RF-20: valida todas las fechas antes de aplicar un cambio atómico.
  /// Sin turnoIds conserva el cambio de todas las fechas futuras.
  WeeklyShift changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  }) {
    if (weeklyShiftId <= 0 || clinicId <= 0) {
      throw const ShiftValidationException(
        'Faltan datos obligatorios o no son válidos',
      );
    }
    final current = weeklyShiftById(weeklyShiftId);
    if (current == null) {
      throw const ShiftNotFoundException('No existe el turno semanal indicado');
    }
    final clinics = admin.clinics.where((c) => c.id == clinicId);
    if (clinics.isEmpty) {
      throw const ShiftNotFoundException('No existe el consultorio indicado');
    }
    final clinic = clinics.first;
    final now = UruguayTime.toUruguay(admin.clock());
    final today = DateTime.utc(now.year, now.month, now.day);
    final future = [
      for (final shift in shifts)
        if (shift.weeklyShiftId == weeklyShiftId &&
            !shift.date.isBefore(today))
          shift,
    ];
    if (future.isEmpty) {
      throw const ShiftNotModifiableException(
        'El turno semanal ya finalizó; no tiene fechas actuales ni futuras por modificar',
      );
    }

    final List<FakeShift> selected;
    if (turnoIds == null) {
      selected = future;
    } else {
      final ids = turnoIds.toSet();
      if (ids.isEmpty || ids.length != turnoIds.length ||
          turnoIds.any((id) => id <= 0) ||
          !ids.every((id) => future.any((shift) => shift.id == id))) {
        throw const ShiftValidationException(
          'Los turnoIds deben ser únicos y pertenecer a fechas actuales o futuras del patrón.',
        );
      }
      selected = [for (final shift in future) if (ids.contains(shift.id)) shift];
    }

    final changing = [
      for (final shift in selected)
        if (shift.clinicId != clinicId) shift,
    ];
    if (changing.isEmpty) return current;

    // No permitimos solapamientos ni siquiera con confirmación.
    final active = [
      for (final shift in changing)
        if (shift.state == ShiftState.active) shift,
    ];
    if (active.isNotEmpty) {
      _rejectClinicChangeOverlaps(
        weeklyShiftId: weeklyShiftId,
        doctorId: current.doctor.id,
        newClinicId: clinicId,
        activeDates: active,
      );
    }

    final withBookings = [
      for (final shift in changing)
        if ((agendadasPorTurno[shift.id] ??
              (shift == future.first
                  ? agendadasPorTurnoSemanal[weeklyShiftId] ?? 0
                  : 0)) > 0)
          shift,
    ];
    if (withBookings.isNotEmpty && !confirmarConConsultas) {
      final dates = withBookings.map((shift) => _isoDate(shift.date)).join(', ');
      throw ShiftNotModifiableException(
        'Hay consultas agendadas en las fechas $dates. '
        'Confirmá el cambio para continuar.',
      );
    }

    // Las fechas suspendidas mantienen su estado.
    for (final shift in changing) {
      shift.clinicId = clinicId;
    }
    // El consultorio del patrón solo se actualiza si se seleccionaron todas
    // las fechas actuales y futuras (también las suspendidas).
    // Puede haber cambios parciales previos: sincronizar el patrón cuando
    // todas las fechas futuras terminaron usando el mismo consultorio.
    final changedAll = future.every((shift) => shift.clinicId == clinicId);
    final updated = WeeklyShift(
      id: current.id,
      doctor: current.doctor,
      specialty: current.specialty,
      clinic: changedAll ? clinic : current.clinic,
      weekday: current.weekday,
      startDate: current.startDate,
      endDate: current.endDate,
      numbers: current.numbers,
      shiftCount: current.shiftCount,
      clinicVariesByDate: future.map((shift) => shift.clinicId).toSet().length > 1,
    );
    final index = weeklyShifts.indexWhere((item) => item.id == current.id);
    weeklyShifts[index] = updated;
    return updated;
  }

  /// Cruces contra turnos activos de otras configuraciones, en las fechas
  /// activas de hoy en adelante. El mensaje no es el del alta.
  void _rejectClinicChangeOverlaps({
    required int weeklyShiftId,
    required int doctorId,
    required int newClinicId,
    required List<FakeShift> activeDates,
  }) {
    final messages = <String>[];
    final sorted = [...activeDates]..sort((a, b) => a.date.compareTo(b.date));
    for (final mine in sorted) {
      for (final other in shifts) {
        if (other.weeklyShiftId == weeklyShiftId) continue;
        if (other.state != ShiftState.active) continue;
        if (other.date != mine.date) continue;
        final sameDoctor = other.doctorId == doctorId;
        final sameClinic = other.clinicId == newClinicId;
        if (!sameDoctor && !sameClinic) continue;
        final ownNumbers = [...mine.numbers]
          ..sort((a, b) => a.number.compareTo(b.number));
        final otherNumbers = [...other.numbers]
          ..sort((a, b) => a.number.compareTo(b.number));
        for (final own in ownNumbers) {
          for (final existing in otherNumbers) {
            final crosses =
                own.startMinutes < existing.endMinutes &&
                existing.startMinutes < own.endMinutes;
            if (!crosses) continue;
            messages.add(
              'fecha ${_isoDate(mine.date)}, número ${own.number} '
              'con número existente ${existing.number}',
            );
          }
        }
      }
    }
    if (messages.isEmpty) return;
    throw OverlappingShiftException(
      'Se encontraron solapamientos: ${messages.join('; ')}',
    );
  }

  static String _isoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Vuelve a habilitar una fecha concreta. Si no está suspendida, lanza
  /// [ShiftNotReinstatableException].
  void reinstateShift(int shiftId) {
    final shift = shifts.firstWhere((s) => s.id == shiftId);
    if (shift.state != ShiftState.suspended) {
      throw const ShiftNotReinstatableException();
    }
    shift._state = ShiftState.active;
  }
}

/// Un único estado en memoria por ejecución de la app.
final fakeShiftDatabaseProvider = Provider<FakeShiftDatabase>(
  (ref) => FakeShiftDatabase(ref.watch(fakeAdminDatabaseProvider)),
);
