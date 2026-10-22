import 'agenda_time.dart';

enum AppointmentHistoryOrder {
  date('fecha'),
  specialty('especialidad');

  const AppointmentHistoryOrder(this.apiValue);

  final String apiValue;
}

enum AppointmentHistoryDirection {
  ascending('asc'),
  descending('desc');

  const AppointmentHistoryDirection(this.apiValue);

  final String apiValue;
}

class AppointmentHistoryQuery {
  const AppointmentHistoryQuery({
    this.status,
    this.from,
    this.to,
    this.specialtyId,
    this.doctorId,
    this.order = AppointmentHistoryOrder.date,
    this.direction = AppointmentHistoryDirection.descending,
    this.page = 0,
    this.size = 20,
  });

  final String? status;
  final DateTime? from;
  final DateTime? to;
  final int? specialtyId;
  final int? doctorId;
  final AppointmentHistoryOrder order;
  final AppointmentHistoryDirection direction;
  final int page;
  final int size;

  Map<String, dynamic> toQueryParameters() => {
    'estado': ?status,
    'fechaDesde': ?(from == null ? null : formatApiDate(from!)),
    'fechaHasta': ?(to == null ? null : formatApiDate(to!)),
    'especialidadId': ?specialtyId,
    'medicoId': ?doctorId,
    'orden': order.apiValue,
    'sentido': direction.apiValue,
    'page': page,
    'size': size,
  };

  @override
  bool operator ==(Object other) =>
      other is AppointmentHistoryQuery &&
      other.status == status &&
      other.from == from &&
      other.to == to &&
      other.specialtyId == specialtyId &&
      other.doctorId == doctorId &&
      other.order == order &&
      other.direction == direction &&
      other.page == page &&
      other.size == size;

  @override
  int get hashCode => Object.hash(
    status,
    from,
    to,
    specialtyId,
    doctorId,
    order,
    direction,
    page,
    size,
  );
}
