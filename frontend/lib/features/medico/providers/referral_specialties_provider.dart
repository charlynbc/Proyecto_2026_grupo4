import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialties_provider.dart';

/// Las especialidades a las que el médico puede emitir un pase: solo las que
/// lo exigen para agendar (`requiresReferral`).
final referralSpecialtiesProvider = FutureProvider<List<Specialty>>((
  ref,
) async {
  final all = await ref.watch(specialtiesProvider.future);
  return [
    for (final specialty in all)
      if (specialty.requiresReferral) specialty,
  ];
});
