import 'package:flutter/foundation.dart' show ValueGetter;

import '../../agenda/models/agenda_time.dart';

/// Campos por los que se puede ordenar la agenda (`orden`, contrato #28).
enum ScheduleOrder {
  dateTime('fechaHora'),
  arrivalTime('horaLlegada');

  const ScheduleOrder(this.apiValue);

  final String apiValue;
}

/// Filtros, orden y página de la consulta de agendas (`FiltroAgendaDTO`,
/// RF-18).
///
/// La [date] es una clave de día en UTC y la elige quien arma el filtro
/// (normalmente hoy en Uruguay): la agenda se consulta de a un día. [ci] y
/// [appointmentId] guardan lo que se escribió; al armar el pedido se les dejan
/// solo los dígitos.
class ScheduleFilters {
  const ScheduleFilters({
    required this.date,
    this.ci,
    this.appointmentId,
    this.doctorId,
    this.status,
    this.arrived,
    this.order = ScheduleOrder.dateTime,
    this.ascending = true,
    this.page = 0,
    this.size = kDefaultPageSize,
  });

  /// Tamaño de página por defecto del contrato.
  static const int kDefaultPageSize = 20;

  final DateTime date;

  /// Cédula del socio, tal como se escribió.
  final String? ci;

  /// Identificador de la consulta, tal como se escribió.
  final String? appointmentId;
  final int? doctorId;

  /// Uno de `kAppointmentStatuses`.
  final String? status;

  /// `true` solo con aviso de llegada, `false` solo sin él, `null` todas.
  final bool? arrived;
  final ScheduleOrder order;
  final bool ascending;

  /// Número de página, desde 0.
  final int page;
  final int size;

  /// Los parámetros de consulta de #28. Un filtro vacío no se envía.
  Map<String, Object> toQueryParameters() {
    final ciDigits = _digitsOf(ci);
    final idDigits = _digitsOf(appointmentId);
    return {
      if (ciDigits.isNotEmpty) 'ci': ciDigits,
      if (idDigits.isNotEmpty) 'consultaId': ?int.tryParse(idDigits),
      'medicoId': ?doctorId,
      'fecha': formatApiDate(date),
      'estado': ?status,
      'llegada': ?arrived,
      'orden': order.apiValue,
      'sentido': ascending ? 'asc' : 'desc',
      'page': page,
      'size': size,
    };
  }

  /// Copia con los cambios indicados, sin tocar la página. Para cambiar de
  /// página.
  ScheduleFilters copyWith({
    DateTime? date,
    ValueGetter<String?>? ci,
    ValueGetter<String?>? appointmentId,
    ValueGetter<int?>? doctorId,
    ValueGetter<String?>? status,
    ValueGetter<bool?>? arrived,
    ScheduleOrder? order,
    bool? ascending,
    int? page,
  }) => ScheduleFilters(
    date: date ?? this.date,
    ci: ci != null ? ci() : this.ci,
    appointmentId: appointmentId != null ? appointmentId() : this.appointmentId,
    doctorId: doctorId != null ? doctorId() : this.doctorId,
    status: status != null ? status() : this.status,
    arrived: arrived != null ? arrived() : this.arrived,
    order: order ?? this.order,
    ascending: ascending ?? this.ascending,
    page: page ?? this.page,
    size: size,
  );

  /// Cambia filtros u orden y vuelve a la primera página.
  ScheduleFilters withFilterChange({
    DateTime? date,
    ValueGetter<String?>? ci,
    ValueGetter<String?>? appointmentId,
    ValueGetter<int?>? doctorId,
    ValueGetter<String?>? status,
    ValueGetter<bool?>? arrived,
    ScheduleOrder? order,
    bool? ascending,
  }) => copyWith(
    date: date,
    ci: ci,
    appointmentId: appointmentId,
    doctorId: doctorId,
    status: status,
    arrived: arrived,
    order: order,
    ascending: ascending,
    page: 0,
  );

  @override
  bool operator ==(Object other) =>
      other is ScheduleFilters &&
      other.date == date &&
      other.ci == ci &&
      other.appointmentId == appointmentId &&
      other.doctorId == doctorId &&
      other.status == status &&
      other.arrived == arrived &&
      other.order == order &&
      other.ascending == ascending &&
      other.page == page &&
      other.size == size;

  @override
  int get hashCode => Object.hash(
    date,
    ci,
    appointmentId,
    doctorId,
    status,
    arrived,
    order,
    ascending,
    page,
    size,
  );
}

String _digitsOf(String? text) => (text ?? '').replaceAll(RegExp(r'\D'), '');
