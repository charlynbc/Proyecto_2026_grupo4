import 'package:flutter/foundation.dart';
import 'doctor_shift.dart';

@immutable
class DoctorShiftNumbersResponse {
  const DoctorShiftNumbersResponse({
    required this.turno,
    required this.items,
  });

  final DoctorShiftDetail turno;
  final List<DoctorShiftNumber> items;

  factory DoctorShiftNumbersResponse.fromJson(Map<String, dynamic> json) =>
      DoctorShiftNumbersResponse(
        turno: DoctorShiftDetail.fromJson(
          Map<String, dynamic>.from(json['turno'] as Map),
        ),
        items: [
          for (final item in json['items'] as List<dynamic>)
            DoctorShiftNumber.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      );
}

@immutable
class DoctorShiftDetail {
  const DoctorShiftDetail({
    required this.id,
    required this.fecha,
    required this.especialidad,
    required this.consultorio,
    required this.estado,
  });

  final int id;
  final DateTime fecha;
  final DoctorShiftSpecialty especialidad;
  final DoctorShiftConsultorio consultorio;
  final String estado;

  factory DoctorShiftDetail.fromJson(Map<String, dynamic> json) =>
      DoctorShiftDetail(
        id: (json['id'] as num).toInt(),
        fecha: DateTime.parse(json['fecha'] as String),
        especialidad: DoctorShiftSpecialty.fromJson(
          Map<String, dynamic>.from(json['especialidad'] as Map),
        ),
        consultorio: DoctorShiftConsultorio.fromJson(
          Map<String, dynamic>.from(json['consultorio'] as Map),
        ),
        estado: json['estado'] as String,
      );
}

@immutable
class DoctorShiftNumber {
  const DoctorShiftNumber({
    required this.numeroId,
    required this.numero,
    required this.horaInicio,
    required this.horaFin,
    required this.consulta,
    required this.disponible,
  });

  final int numeroId;
  final int numero;
  final String horaInicio;
  final String horaFin;
  final DoctorShiftAppointment? consulta;
  final bool disponible;

  factory DoctorShiftNumber.fromJson(Map<String, dynamic> json) =>
      DoctorShiftNumber(
        numeroId: (json['numeroId'] as num).toInt(),
        numero: (json['numero'] as num).toInt(),
        horaInicio: json['horaInicio'] as String,
        horaFin: json['horaFin'] as String,
        consulta: json['consulta'] == null
            ? null
            : DoctorShiftAppointment.fromJson(
                Map<String, dynamic>.from(json['consulta'] as Map),
              ),
        disponible: json['disponible'] as bool,
      );
}

@immutable
class DoctorShiftAppointment {
  const DoctorShiftAppointment({
    required this.id,
    required this.estado,
    required this.paciente,
    required this.llegadaEn,
  });

  final int id;
  final String estado;
  final DoctorShiftPatient paciente;
  final DateTime? llegadaEn;

  factory DoctorShiftAppointment.fromJson(Map<String, dynamic> json) =>
      DoctorShiftAppointment(
        id: (json['id'] as num).toInt(),
        estado: json['estado'] as String,
        paciente: DoctorShiftPatient.fromJson(
          Map<String, dynamic>.from(json['paciente'] as Map),
        ),
        llegadaEn: json['llegadaEn'] == null
            ? null
            : DateTime.parse(json['llegadaEn'] as String),
      );
}

@immutable
class DoctorShiftPatient {
  const DoctorShiftPatient({
    required this.ci,
    required this.nombre,
    required this.apellido,
  });

  final String ci;
  final String nombre;
  final String apellido;

  factory DoctorShiftPatient.fromJson(Map<String, dynamic> json) =>
      DoctorShiftPatient(
        ci: json['ci'] as String,
        nombre: json['nombre'] as String,
        apellido: json['apellido'] as String,
      );
}
