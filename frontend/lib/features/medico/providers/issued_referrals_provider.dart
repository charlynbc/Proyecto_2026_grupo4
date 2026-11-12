import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/issued_referral.dart';
import '../models/issued_referral_query.dart';
import 'issued_referral_repository_provider.dart';

/// Los filtros y el orden aplicados a la lista de pases. Cada cambio vuelve a
/// consultar al instante, porque la lista los observa.
class IssuedReferralFiltersController extends Notifier<IssuedReferralQuery> {
  @override
  IssuedReferralQuery build() => const IssuedReferralQuery();

  void setStatus(ReferralStatus? status) {
    state = state.withStatus(status);
  }

  void setOrder(IssuedReferralOrder order) {
    state = state.withOrder(order, direction: state.direction);
  }

  void setDirection(IssuedReferralDirection direction) {
    state = state.withOrder(state.order, direction: direction);
  }
}

final issuedReferralFiltersProvider =
    NotifierProvider.autoDispose<
      IssuedReferralFiltersController,
      IssuedReferralQuery
    >(IssuedReferralFiltersController.new);

/// Los pases que emitió el médico según los filtros. El reintento es explícito
/// (invalidando el provider).
final issuedReferralsProvider =
    FutureProvider.autoDispose<List<IssuedReferral>>((ref) async {
      final query = ref.watch(issuedReferralFiltersProvider);
      final repository = await ref.watch(
        issuedReferralRepositoryProvider.future,
      );
      return repository.list(query);
    }, retry: (_, _) => null);
