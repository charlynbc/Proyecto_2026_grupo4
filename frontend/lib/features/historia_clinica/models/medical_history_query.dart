import '../../agenda/models/agenda_time.dart';

/// Órdenes disponibles para consultar la historia clínica.
enum MedicalHistoryOrder { date, specialty }

/// Sentidos disponibles para ordenar las atenciones.
enum MedicalHistoryDirection { ascending, descending }

/// Filtros combinables del listado, sin paginación ni identidad del socio.
class MedicalHistoryQuery {
  const MedicalHistoryQuery({
    this.from,
    this.to,
    this.specialtyId,
    this.doctorId,
    this.text,
    this.order = MedicalHistoryOrder.date,
    this.direction = MedicalHistoryDirection.descending,
  });

  final DateTime? from;
  final DateTime? to;
  final int? specialtyId;
  final int? doctorId;
  final String? text;
  final MedicalHistoryOrder order;
  final MedicalHistoryDirection direction;

  Map<String, dynamic> toQueryParameters() {
    final search = text?.trim();
    return {
      if (from != null) 'fechaDesde': formatApiDate(from!),
      if (to != null) 'fechaHasta': formatApiDate(to!),
      if (specialtyId != null) 'especialidadId': specialtyId,
      if (doctorId != null) 'medicoId': doctorId,
      if (search != null && search.isNotEmpty) 'texto': search,
      'orden': switch (order) {
        MedicalHistoryOrder.date => 'fecha_atencion',
        MedicalHistoryOrder.specialty => 'especialidad',
      },
      'sentido': switch (direction) {
        MedicalHistoryDirection.ascending => 'asc',
        MedicalHistoryDirection.descending => 'desc',
      },
    };
  }
}
