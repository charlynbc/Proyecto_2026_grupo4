import 'package:flutter/foundation.dart';

@immutable
class DoctorShift {
  const DoctorShift({
    required this.id,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.especialidad,
    required this.consultorio,
    required this.estado,
    required this.cantidadNumeros,
    required this.cantidadReservados,
  });

  final int id;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final DoctorShiftSpecialty especialidad;
  final DoctorShiftConsultorio consultorio;
  final String estado;
  final int cantidadNumeros;
  final int cantidadReservados;

  factory DoctorShift.fromJson(Map<String, dynamic> json) => DoctorShift(
    id: (json['id'] as num).toInt(),
    fecha: DateTime.parse(json['fecha'] as String),
    horaInicio: json['horaInicio'] as String,
    horaFin: json['horaFin'] as String,
    especialidad: DoctorShiftSpecialty.fromJson(
      Map<String, dynamic>.from(json['especialidad'] as Map),
    ),
    consultorio: DoctorShiftConsultorio.fromJson(
      Map<String, dynamic>.from(json['consultorio'] as Map),
    ),
    estado: json['estado'] as String,
    cantidadNumeros: (json['cantidadNumeros'] as num).toInt(),
    cantidadReservados: (json['cantidadReservados'] as num).toInt(),
  );
}

@immutable
class DoctorShiftSpecialty {
  const DoctorShiftSpecialty({
    required this.id,
    required this.nombre,
    required this.requierePase,
  });

  final int id;
  final String nombre;
  final bool requierePase;

  factory DoctorShiftSpecialty.fromJson(Map<String, dynamic> json) =>
      DoctorShiftSpecialty(
        id: (json['id'] as num).toInt(),
        nombre: json['nombre'] as String,
        requierePase: json['requierePase'] as bool,
      );
}

@immutable
class DoctorShiftConsultorio {
  const DoctorShiftConsultorio({
    required this.id,
    required this.nombre,
    required this.ubicacion,
  });

  final int id;
  final String nombre;
  final String ubicacion;

  factory DoctorShiftConsultorio.fromJson(Map<String, dynamic> json) =>
      DoctorShiftConsultorio(
        id: (json['id'] as num).toInt(),
        nombre: json['nombre'] as String,
        ubicacion: json['ubicacion'] as String,
      );
}
