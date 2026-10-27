import 'package:flutter/foundation.dart';

/// Un turno del médico en una fecha (contrato RF-21, `GET /api/medico/turnos`).
@immutable
class DoctorShift {
  const DoctorShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.specialtyName,
    required this.clinicName,
    required this.status,
    required this.numbersCount,
    required this.reservedCount,
  });

  factory DoctorShift.fromJson(Map<String, dynamic> json) => DoctorShift(
    id: (json['id'] as num).toInt(),
    date: json['fecha'] as String,
    startTime: _hhmm(json['horaInicio'] as String?),
    endTime: _hhmm(json['horaFin'] as String?),
    specialtyName:
        (json['especialidad'] as Map<String, dynamic>)['nombre'] as String,
    clinicName:
        (json['consultorio'] as Map<String, dynamic>)['nombre'] as String,
    status: json['estado'] as String,
    numbersCount: (json['cantidadNumeros'] as num).toInt(),
    reservedCount: (json['cantidadReservados'] as num).toInt(),
  );

  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String specialtyName;
  final String clinicName;
  final String status;
  final int numbersCount;
  final int reservedCount;

  @override
  bool operator ==(Object other) =>
      other is DoctorShift &&
      other.id == id &&
      other.date == date &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.specialtyName == specialtyName &&
      other.clinicName == clinicName &&
      other.status == status &&
      other.numbersCount == numbersCount &&
      other.reservedCount == reservedCount;

  @override
  int get hashCode => Object.hash(
    id,
    date,
    startTime,
    endTime,
    specialtyName,
    clinicName,
    status,
    numbersCount,
    reservedCount,
  );
}

/// El paciente de un número reservado.
@immutable
class DoctorPatient {
  const DoctorPatient({
    required this.ci,
    required this.name,
    required this.lastName,
  });

  final String ci;
  final String name;
  final String lastName;

  @override
  bool operator ==(Object other) =>
      other is DoctorPatient &&
      other.ci == ci &&
      other.name == name &&
      other.lastName == lastName;

  @override
  int get hashCode => Object.hash(ci, name, lastName);
}

/// Un número de un turno. Sin [patient] se muestra "Sin reserva".
@immutable
class DoctorShiftNumber {
  const DoctorShiftNumber({
    required this.numberId,
    required this.number,
    required this.startTime,
    required this.endTime,
    this.appointmentId,
    this.appointmentStatus,
    this.patient,
    this.arrivedAt,
  });

  factory DoctorShiftNumber.fromJson(Map<String, dynamic> json) {
    final appointment = json['consulta'] as Map<String, dynamic>?;
    final patient = appointment?['paciente'] as Map<String, dynamic>?;
    final arrived = appointment?['llegadaEn'] as String?;
    return DoctorShiftNumber(
      numberId: (json['numeroId'] as num).toInt(),
      number: (json['numero'] as num).toInt(),
      startTime: _hhmm(json['horaInicio'] as String?),
      endTime: _hhmm(json['horaFin'] as String?),
      appointmentId: (appointment?['id'] as num?)?.toInt(),
      appointmentStatus: appointment?['estado'] as String?,
      patient: patient == null
          ? null
          : DoctorPatient(
              ci: patient['ci'] as String,
              name: patient['nombre'] as String,
              lastName: patient['apellido'] as String,
            ),
      arrivedAt: arrived == null ? null : DateTime.parse(arrived),
    );
  }

  final int numberId;
  final int number;
  final String startTime;
  final String endTime;
  final int? appointmentId;
  final String? appointmentStatus;
  final DoctorPatient? patient;
  final DateTime? arrivedAt;

  bool get isReserved => patient != null;
  bool get hasArrived => arrivedAt != null;

  @override
  bool operator ==(Object other) =>
      other is DoctorShiftNumber &&
      other.numberId == numberId &&
      other.number == number &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.appointmentId == appointmentId &&
      other.appointmentStatus == appointmentStatus &&
      other.patient == patient &&
      other.arrivedAt == arrivedAt;

  @override
  int get hashCode => Object.hash(
    numberId,
    number,
    startTime,
    endTime,
    appointmentId,
    appointmentStatus,
    patient,
    arrivedAt,
  );
}

/// Los números de un turno, con el turno al que pertenecen.
@immutable
class DoctorShiftNumbers {
  const DoctorShiftNumbers({required this.shiftId, required this.items});

  factory DoctorShiftNumbers.fromJson(Map<String, dynamic> json) =>
      DoctorShiftNumbers(
        shiftId: ((json['turno'] as Map<String, dynamic>)['id'] as num).toInt(),
        items: [
          for (final item in json['items'] as List<dynamic>)
            DoctorShiftNumber.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int shiftId;
  final List<DoctorShiftNumber> items;

  @override
  bool operator ==(Object other) =>
      other is DoctorShiftNumbers &&
      other.shiftId == shiftId &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(shiftId, Object.hashAll(items));
}

/// Orden de la lista de números: por hora del número o por hora de llegada.
enum DoctorNumbersOrder {
  time('hora', 'Hora del número'),
  arrival('horaLlegada', 'Hora de llegada');

  const DoctorNumbersOrder(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

String _hhmm(String? value) {
  if (value == null) return '';
  return value.length >= 5 ? value.substring(0, 5) : value;
}
