import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_shift_number.dart';
import 'doctor_shift_repository_provider.dart';

@immutable
class DoctorShiftNumbersParams {
  const DoctorShiftNumbersParams({
    required this.shiftId,
    this.llegada,
    this.orden,
    this.sentido,
  });

  final int shiftId;
  final bool? llegada;
  final String? orden;
  final String? sentido;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorShiftNumbersParams &&
          shiftId == other.shiftId &&
          llegada == other.llegada &&
          orden == other.orden &&
          sentido == other.sentido;

  @override
  int get hashCode => Object.hash(shiftId, llegada, orden, sentido);
}

final doctorShiftNumbersProvider = FutureProvider.autoDispose
    .family<DoctorShiftNumbersResponse, DoctorShiftNumbersParams>(
  (ref, params) async {
    final repository = await ref.watch(doctorShiftRepositoryProvider.future);
    return repository.getDoctorShiftNumbers(
      shiftId: params.shiftId,
      llegada: params.llegada,
      orden: params.orden,
      sentido: params.sentido,
    );
  },
  retry: (_, _) => null,
);
