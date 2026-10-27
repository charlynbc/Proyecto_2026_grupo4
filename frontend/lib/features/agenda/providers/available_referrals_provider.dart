import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/referral.dart';
import 'agenda_repository_provider.dart';

/// Los pases disponibles del socio. `autoDispose`: al soltarlo y volver a
/// leerlo se vuelve a pedir la lista.
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y mientras tanto el estado es
/// "cargando" y el error no se ve.
final availableReferralsProvider = FutureProvider.autoDispose<List<Referral>>((
  ref,
) async {
  final repository = await ref.watch(agendaRepositoryProvider.future);
  return repository.listReferrals();
}, retry: (_, _) => null);
