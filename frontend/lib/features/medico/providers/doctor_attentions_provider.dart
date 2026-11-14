import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';
import 'doctor_attention_repository_provider.dart';

class DoctorAttentionFiltersController extends Notifier<DoctorAttentionQuery> {
  @override
  DoctorAttentionQuery build() => DoctorAttentionQuery.initial();
  void apply(DoctorAttentionQuery query) => state = query;

  /// Cambia solo el orden y el sentido; los filtros que ya estaban aplicados
  /// quedan como estaban.
  void sortBy(DoctorAttentionOrder order, DoctorAttentionDirection direction) =>
      state = DoctorAttentionQuery(
        from: state.from,
        to: state.to,
        patientText: state.patientText,
        specialtyId: state.specialtyId,
        order: order,
        direction: direction,
      );
  void clear() => state = DoctorAttentionQuery.initial();
}

final doctorAttentionFiltersProvider =
    NotifierProvider.autoDispose<
      DoctorAttentionFiltersController,
      DoctorAttentionQuery
    >(DoctorAttentionFiltersController.new);
final doctorAttentionsProvider =
    FutureProvider.autoDispose<List<DoctorAttention>>((ref) async {
      final query = ref.watch(doctorAttentionFiltersProvider);
      return (await ref.watch(doctorAttentionRepositoryProvider.future))
          .list(query);
    }, retry: (_, _) => null);
final doctorAttentionDetailProvider = FutureProvider.autoDispose
    .family<DoctorAttention, int>(
      (ref, id) async =>
          (await ref.watch(doctorAttentionRepositoryProvider.future)).get(id),
      retry: (_, _) => null,
    );
