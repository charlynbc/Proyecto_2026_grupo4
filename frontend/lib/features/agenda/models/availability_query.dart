import 'agenda_time.dart';

/// `orden` de `GET /api/disponibilidad`.
enum AvailabilityOrder {
  date('fecha', 'Fecha'),
  doctorLastName('apellidoMedico', 'Apellido del médico');

  const AvailabilityOrder(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// `sentido` de `GET /api/disponibilidad`.
enum SortDirection {
  asc('asc', 'Ascendente'),
  desc('desc', 'Descendente');

  const SortDirection(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Los filtros de `GET /api/disponibilidad`. Hace falta al menos la
/// especialidad o el médico (sin ninguno el servidor responde 400); el resto
/// es opcional y lo que no está se omite al consultar. Las fechas son claves
/// de día (UTC sin hora) y se mandan como `YYYY-MM-DD`. Tiene igualdad por
/// valor: es la clave del provider de disponibilidad.
class AvailabilityQuery {
  const AvailabilityQuery({
    this.specialtyId,
    this.doctorId,
    this.from,
    this.to,
    this.order = AvailabilityOrder.date,
    this.direction = SortDirection.asc,
  }) : assert(
         specialtyId != null || doctorId != null,
         'Hace falta la especialidad o el médico',
       );

  final int? specialtyId;
  final int? doctorId;
  final DateTime? from;
  final DateTime? to;
  final AvailabilityOrder order;
  final SortDirection direction;

  AvailabilityQuery withDoctor(int? doctorId) => AvailabilityQuery(
    specialtyId: specialtyId,
    doctorId: doctorId,
    from: from,
    to: to,
    order: order,
    direction: direction,
  );

  AvailabilityQuery withRange({DateTime? from, DateTime? to}) =>
      AvailabilityQuery(
        specialtyId: specialtyId,
        doctorId: doctorId,
        from: from,
        to: to,
        order: order,
        direction: direction,
      );

  AvailabilityQuery withOrder({
    AvailabilityOrder? order,
    SortDirection? direction,
  }) => AvailabilityQuery(
    specialtyId: specialtyId,
    doctorId: doctorId,
    from: from,
    to: to,
    order: order ?? this.order,
    direction: direction ?? this.direction,
  );

  Map<String, dynamic> toQueryParameters() => {
    'especialidadId': ?specialtyId,
    'medicoId': ?doctorId,
    'fechaDesde': ?(from == null ? null : formatApiDate(from!)),
    'fechaHasta': ?(to == null ? null : formatApiDate(to!)),
    'orden': order.apiValue,
    'sentido': direction.apiValue,
  };

  @override
  bool operator ==(Object other) =>
      other is AvailabilityQuery &&
      other.specialtyId == specialtyId &&
      other.doctorId == doctorId &&
      other.from == from &&
      other.to == to &&
      other.order == order &&
      other.direction == direction;

  @override
  int get hashCode =>
      Object.hash(specialtyId, doctorId, from, to, order, direction);
}
