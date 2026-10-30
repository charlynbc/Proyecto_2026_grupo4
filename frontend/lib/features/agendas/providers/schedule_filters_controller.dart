import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_filters.dart';
import 'schedules_today_provider.dart';

/// Los filtros, el orden y la página que están aplicados a la consulta de
/// agendas. Cambiar filtros u orden vuelve a la primera página; solo
/// [goToPage] la conserva.
class ScheduleFiltersController extends Notifier<ScheduleFilters> {
  @override
  ScheduleFilters build() =>
      ScheduleFilters(date: ref.read(schedulesTodayProvider));

  void setCi(String? ci) => state = state.withFilterChange(ci: () => ci);

  void setAppointmentId(String? id) =>
      state = state.withFilterChange(appointmentId: () => id);

  void setDoctorId(int? id) =>
      state = state.withFilterChange(doctorId: () => id);

  void setDate(DateTime date) => state = state.withFilterChange(date: date);

  void setStatus(String? status) =>
      state = state.withFilterChange(status: () => status);

  /// `true` solo con aviso de llegada, `false` solo sin él, `null` todas.
  void setArrived(bool? arrived) =>
      state = state.withFilterChange(arrived: () => arrived);

  void setOrder(ScheduleOrder order) =>
      state = state.withFilterChange(order: order);

  void setAscending(bool ascending) =>
      state = state.withFilterChange(ascending: ascending);

  void goToPage(int page) => state = state.copyWith(page: page);

  /// Vuelve a los valores iniciales, con la fecha de hoy.
  void clear() {
    state = ScheduleFilters(date: ref.read(schedulesTodayProvider));
  }
}

final scheduleFiltersControllerProvider =
    NotifierProvider.autoDispose<ScheduleFiltersController, ScheduleFilters>(
      ScheduleFiltersController.new,
    );
