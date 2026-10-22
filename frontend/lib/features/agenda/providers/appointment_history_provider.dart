import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import '../repositories/api_appointment_history_repository.dart';
import '../repositories/appointment_history_repository.dart';

class AppointmentHistoryRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final appointmentHistoryRefreshProvider =
    NotifierProvider<AppointmentHistoryRefresh, int>(
      AppointmentHistoryRefresh.new,
    );

final appointmentHistoryRepositoryProvider =
    FutureProvider<AppointmentHistoryRepository>((ref) async {
      final dio = await ref.watch(dioProvider.future);
      return ApiAppointmentHistoryRepository(dio);
    });

final appointmentHistoryProvider =
    FutureProvider.family<AppointmentHistoryPage, AppointmentHistoryQuery>((
      ref,
      query,
    ) async {
      ref.watch(appointmentHistoryRefreshProvider);
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      return repository.list(query);
    });

final appointmentDetailProvider = FutureProvider.family<Appointment, int>((
  ref,
  id,
) async {
  ref.watch(appointmentHistoryRefreshProvider);
  final repository = await ref.watch(
    appointmentHistoryRepositoryProvider.future,
  );
  return repository.get(id);
});
