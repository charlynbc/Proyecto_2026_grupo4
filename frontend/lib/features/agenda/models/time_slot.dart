class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.professionalId,
    required this.start,
    required this.end,
  });

  final int id;
  final int professionalId;
  final DateTime start;
  final DateTime end;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    id: json['id'] as int,
    professionalId: json['profesionalId'] as int,
    start: DateTime.parse(json['inicio'] as String),
    end: DateTime.parse(json['fin'] as String),
  );
}
