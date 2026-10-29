import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medical_history_query.dart';

/// Mantiene los filtros y el orden aplicados al listado de historia clínica.
class MedicalHistoryFiltersController extends Notifier<MedicalHistoryQuery> {
  @override
  MedicalHistoryQuery build() => const MedicalHistoryQuery();

  void apply({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    int? doctorId,
    String? text,
  }) {
    state = MedicalHistoryQuery(
      from: from,
      to: to,
      specialtyId: specialtyId,
      doctorId: doctorId,
      text: text,
      order: state.order,
      direction: state.direction,
    );
  }

  void sortBy(
    MedicalHistoryOrder order, {
    required MedicalHistoryDirection direction,
  }) {
    state = MedicalHistoryQuery(
      from: state.from,
      to: state.to,
      specialtyId: state.specialtyId,
      doctorId: state.doctorId,
      text: state.text,
      order: order,
      direction: direction,
    );
  }

  void clear() {
    state = const MedicalHistoryQuery();
  }
}

final medicalHistoryFiltersProvider =
    NotifierProvider.autoDispose<
      MedicalHistoryFiltersController,
      MedicalHistoryQuery
    >(MedicalHistoryFiltersController.new);
