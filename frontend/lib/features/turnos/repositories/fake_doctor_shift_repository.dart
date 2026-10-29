import '../models/doctor_shift.dart';
import '../models/doctor_shift_number.dart';
import 'doctor_shift_repository.dart';

class FakeDoctorShiftRepository implements DoctorShiftRepository {
  @override
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    return [
      DoctorShift(
        id: 101,
        fecha: date,
        horaInicio: '09:00',
        horaFin: '12:00',
        especialidad: const DoctorShiftSpecialty(
          id: 1,
          nombre: 'Cardiología',
          requierePase: false,
        ),
        consultorio: const DoctorShiftConsultorio(
          id: 3,
          nombre: 'Consultorio 3',
          ubicacion: 'Piso 1',
        ),
        estado: 'ACTIVO',
        cantidadNumeros: 4,
        cantidadReservados: 2,
      ),
      DoctorShift(
        id: 102,
        fecha: date,
        horaInicio: '14:00',
        horaFin: '16:00',
        especialidad: const DoctorShiftSpecialty(
          id: 2,
          nombre: 'Pediatría',
          requierePase: false,
        ),
        consultorio: const DoctorShiftConsultorio(
          id: 5,
          nombre: 'Consultorio 5',
          ubicacion: 'Piso 2',
        ),
        estado: 'SUSPENDIDO',
        cantidadNumeros: 10,
        cantidadReservados: 4,
      ),
    ];
  }

  @override
  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final validOrders = {'hora', 'horaLlegada'};
    final validSentidos = {'asc', 'desc'};

    if (orden != null && !validOrders.contains(orden)) {
      throw const DoctorShiftValidationException('Orden inválido.');
    }
    if (sentido != null && !validSentidos.contains(sentido)) {
      throw const DoctorShiftValidationException('Sentido inválido.');
    }

    final isSuspendedShift = shiftId == 102;
    final appointmentWithArrival = DoctorShiftAppointment(
      id: 9001,
      estado: 'AGENDADA',
      paciente: const DoctorShiftPatient(
        ci: '90000030',
        nombre: 'Carlos',
        apellido: 'Rodríguez',
      ),
      llegadaEn: DateTime(2026, 10, 28, 9, 15),
    );

    final appointmentWithoutArrival = DoctorShiftAppointment(
      id: 9002,
      estado: 'AGENDADA',
      paciente: const DoctorShiftPatient(
        ci: '90000046',
        nombre: 'Ana',
        apellido: 'Fernández',
      ),
      llegadaEn: null,
    );

    final appointmentAttended = DoctorShiftAppointment(
      id: 9003,
      estado: 'ATENDIDA',
      paciente: const DoctorShiftPatient(
        ci: '90000010',
        nombre: 'Lucía',
        apellido: 'Sosa',
      ),
      llegadaEn: DateTime(2026, 10, 28, 9, 50),
    );

    final baseItems = <DoctorShiftNumber>[
      DoctorShiftNumber(
        numeroId: 1,
        numero: 1,
        horaInicio: '09:00',
        horaFin: '09:15',
        consulta: null,
        disponible: true,
      ),
      DoctorShiftNumber(
        numeroId: 2,
        numero: 2,
        horaInicio: '09:15',
        horaFin: '09:30',
        consulta: null,
        disponible: false,
      ),
      DoctorShiftNumber(
        numeroId: 3,
        numero: 3,
        horaInicio: '09:30',
        horaFin: '09:45',
        consulta: appointmentWithArrival,
        disponible: false,
      ),
      DoctorShiftNumber(
        numeroId: 4,
        numero: 4,
        horaInicio: '09:45',
        horaFin: '10:00',
        consulta: appointmentWithoutArrival,
        disponible: false,
      ),
      DoctorShiftNumber(
        numeroId: 5,
        numero: 5,
        horaInicio: '10:00',
        horaFin: '10:15',
        consulta: appointmentAttended,
        disponible: false,
      ),
    ];

    final items = <DoctorShiftNumber>[];
    for (final item in baseItems) {
      final hasReservation = item.consulta != null;
      final hasArrival = item.consulta?.llegadaEn != null;
      final matchesLlegada = switch (llegada) {
        true => hasReservation && hasArrival,
        false => hasReservation && !hasArrival,
        null => true,
      };
      if (matchesLlegada) {
        items.add(item);
      }
    }

    final sorted = [...items];
    final safeOrden = orden ?? 'hora';
    final ascending = sentido != 'desc';
    sorted.sort((a, b) {
      final aValue = (safeOrden == 'horaLlegada')
          ? (a.consulta?.llegadaEn ?? DateTime(1970, 1, 1))
          : _timeToDateTime(a.horaInicio);
      final bValue = (safeOrden == 'horaLlegada')
          ? (b.consulta?.llegadaEn ?? DateTime(1970, 1, 1))
          : _timeToDateTime(b.horaInicio);
      final comparison = aValue.compareTo(bValue);
      return ascending ? comparison : -comparison;
    });

    return DoctorShiftNumbersResponse(
      turno: DoctorShiftDetail(
        id: shiftId,
        fecha: DateTime(2026, 10, 28),
        especialidad: DoctorShiftSpecialty(
          id: isSuspendedShift ? 2 : 1,
          nombre: isSuspendedShift ? 'Pediatría' : 'Cardiología',
          requierePase: false,
        ),
        consultorio: DoctorShiftConsultorio(
          id: isSuspendedShift ? 5 : 3,
          nombre: isSuspendedShift ? 'Consultorio 5' : 'Consultorio 3',
          ubicacion: isSuspendedShift ? 'Piso 2' : 'Piso 1',
        ),
        estado: isSuspendedShift ? 'SUSPENDIDO' : 'ACTIVO',
      ),
      items: sorted,
    );
  }

  DateTime _timeToDateTime(String time) {
    final parts = time.split(':');
    return DateTime(
      2026,
      10,
      28,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
