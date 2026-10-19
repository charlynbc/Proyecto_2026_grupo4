import 'package:flutter/foundation.dart' show ValueGetter;

import 'shift.dart';
import 'shift_state.dart';

/// Campos por los que se pueden ordenar los turnos (`orden`, contrato #15).
enum ShiftOrder {
  date('fecha', 'Fecha y horario'),
  doctor('medico', 'Médico'),
  specialty('especialidad', 'Especialidad');

  const ShiftOrder(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Filtros, orden y página del listado de turnos (`FiltroTurnosDTO`, RF-17).
///
/// Las fechas son claves de día en UTC. [weekday] va de 1 (lunes) a 7
/// (domingo), como en el contrato.
class ShiftFilters {
  const ShiftFilters({
    this.doctorId,
    this.specialtyId,
    this.weekday,
    this.fromDate,
    this.toDate,
    this.state,
    this.order = ShiftOrder.date,
    this.ascending = true,
    this.page = 0,
    this.size = kDefaultPageSize,
  });

  /// Tamaño de página por defecto del contrato (P-19).
  static const int kDefaultPageSize = 20;

  final int? doctorId;
  final int? specialtyId;
  final int? weekday;

  /// Primer día del rango, inclusive.
  final DateTime? fromDate;

  /// Último día del rango, inclusive.
  final DateTime? toDate;
  final ShiftState? state;
  final ShiftOrder order;
  final bool ascending;
  final int page;
  final int size;

  /// Los parámetros de consulta de #15. Un filtro vacío no se envía.
  Map<String, Object> toQueryParameters() => {
    'medicoId': ?doctorId,
    'especialidadId': ?specialtyId,
    'diaSemana': ?weekday,
    if (fromDate != null) 'fechaDesde': formatDateKey(fromDate!),
    if (toDate != null) 'fechaHasta': formatDateKey(toDate!),
    'estado': ?state?.apiValue,
    'orden': order.apiValue,
    'sentido': ascending ? 'asc' : 'desc',
    'page': page,
    'size': size,
  };

  ShiftFilters copyWith({
    ValueGetter<int?>? doctorId,
    ValueGetter<int?>? specialtyId,
    ValueGetter<int?>? weekday,
    ValueGetter<DateTime?>? fromDate,
    ValueGetter<DateTime?>? toDate,
    ValueGetter<ShiftState?>? state,
    ShiftOrder? order,
    bool? ascending,
    int? page,
  }) => ShiftFilters(
    doctorId: doctorId != null ? doctorId() : this.doctorId,
    specialtyId: specialtyId != null ? specialtyId() : this.specialtyId,
    weekday: weekday != null ? weekday() : this.weekday,
    fromDate: fromDate != null ? fromDate() : this.fromDate,
    toDate: toDate != null ? toDate() : this.toDate,
    state: state != null ? state() : this.state,
    order: order ?? this.order,
    ascending: ascending ?? this.ascending,
    page: page ?? this.page,
    size: size,
  );

  @override
  bool operator ==(Object other) =>
      other is ShiftFilters &&
      other.doctorId == doctorId &&
      other.specialtyId == specialtyId &&
      other.weekday == weekday &&
      other.fromDate == fromDate &&
      other.toDate == toDate &&
      other.state == state &&
      other.order == order &&
      other.ascending == ascending &&
      other.page == page &&
      other.size == size;

  @override
  int get hashCode => Object.hash(
    doctorId,
    specialtyId,
    weekday,
    fromDate,
    toDate,
    state,
    order,
    ascending,
    page,
    size,
  );
}
