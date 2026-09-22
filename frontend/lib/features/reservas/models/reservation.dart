enum ReservationStatus { active, cancelled }

ReservationStatus reservationStatusFromJson(String value) => switch (value) {
  'ACTIVA' => ReservationStatus.active,
  'CANCELADA' => ReservationStatus.cancelled,
  _ => throw FormatException('Estado de reserva desconocido: $value'),
};

class Reservation {
  const Reservation({
    required this.id,
    required this.status,
    required this.createdAt,
    this.cancelledAt,
    required this.timeSlotId,
    required this.start,
    required this.end,
    required this.professionalId,
    required this.professionalName,
  });

  final int id;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final int timeSlotId;
  final DateTime start;
  final DateTime end;
  final int professionalId;
  final String professionalName;

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: json['id'] as int,
    status: reservationStatusFromJson(json['estado'] as String),
    createdAt: DateTime.parse(json['fechaCreacion'] as String),
    cancelledAt: json['fechaCancelacion'] == null
        ? null
        : DateTime.parse(json['fechaCancelacion'] as String),
    timeSlotId: json['horarioId'] as int,
    start: DateTime.parse(json['inicio'] as String),
    end: DateTime.parse(json['fin'] as String),
    professionalId: json['profesionalId'] as int,
    professionalName: json['profesional'] as String,
  );
}
