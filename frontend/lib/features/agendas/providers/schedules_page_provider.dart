import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_page.dart';
import 'schedule_filters_controller.dart';
import 'schedule_repository_provider.dart';

/// La página de la agenda que corresponde a los filtros aplicados.
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final schedulesPageProvider = FutureProvider.autoDispose<SchedulePage>((
  ref,
) async {
  final filters = ref.watch(scheduleFiltersControllerProvider);
  final repository = await ref.watch(scheduleRepositoryProvider.future);
  return repository.search(filters);
}, retry: (_, _) => null);
