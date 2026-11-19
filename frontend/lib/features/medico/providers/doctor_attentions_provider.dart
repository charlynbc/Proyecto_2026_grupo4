import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';
import 'doctor_attention_repository_provider.dart';

// El shell y las rutas cubiertas conservan las pantallas montadas. Riverpod
// reanuda sus suscripciones al volver a verlas (`onResume`); se renuevan solo
// los datos. Cuando vuelve la pestaña del navegador o la app a primer plano,
// Riverpod no se entera: lo escucha un `AppLifecycleListener`, que solo pide
// datos si la pantalla se está viendo (con Atenciones en otra sección del
// shell, lo hace `onResume` al volver).
void _refreshWhenVisibleAgain(Ref ref) {
  void refresh() {
    Future.microtask(() {
      if (ref.mounted) ref.invalidateSelf();
    });
  }

  ref.onResume(refresh);
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (ref.mounted && !ref.isPaused) refresh();
    },
  );
  ref.onDispose(lifecycle.dispose);
}

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
      _refreshWhenVisibleAgain(ref);
      final query = ref.watch(doctorAttentionFiltersProvider);
      return (await ref.watch(doctorAttentionRepositoryProvider.future))
          .list(query);
    }, retry: (_, _) => null);
final doctorAttentionDetailProvider = FutureProvider.autoDispose
    .family<DoctorAttention, int>((ref, id) async {
      _refreshWhenVisibleAgain(ref);
      return (await ref.watch(doctorAttentionRepositoryProvider.future))
          .get(id);
    }, retry: (_, _) => null);
