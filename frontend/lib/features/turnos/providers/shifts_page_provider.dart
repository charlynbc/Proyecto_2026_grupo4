import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shift_page.dart';
import 'shift_filters_controller.dart';
import 'shift_repository_provider.dart';

/// La página de turnos que corresponde a los filtros aplicados.
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final shiftsPageProvider = FutureProvider.autoDispose<ShiftPage>((ref) async {
  final filters = ref.watch(shiftFiltersControllerProvider);
  final repository = await ref.watch(shiftRepositoryProvider.future);
  return repository.listShifts(filters);
}, retry: (_, _) => null);
