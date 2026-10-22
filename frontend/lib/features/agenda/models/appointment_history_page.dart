import 'appointment.dart';

class AppointmentHistoryPage {
  const AppointmentHistoryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  factory AppointmentHistoryPage.fromJson(Map<String, dynamic> json) =>
      AppointmentHistoryPage(
        items: (json['items'] as List<dynamic>)
            .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        page: json['page'] as int,
        size: json['size'] as int,
        total: json['total'] as int,
      );

  final List<Appointment> items;
  final int page;
  final int size;
  final int total;

  bool get hasPrevious => page > 0;
  bool get hasNext => (page + 1) * size < total;
}
