import 'models/clinic.dart';
import 'models/clinic_filters.dart';
import 'natural_order.dart';

/// Ordena una copia de [items] como la lee una persona: por nombre o por
/// ubicación, con los números como cantidad. Con [ascending] en `false`
/// invierte esa copia. No consulta nada: el sentido se resuelve acá.
List<Clinic> sortClinics(
  List<Clinic> items, {
  required ClinicOrder order,
  required bool ascending,
}) {
  final sorted = sortedNaturally(items, (clinic) {
    return order == ClinicOrder.location ? clinic.location : clinic.name;
  });
  return ascending ? sorted : sorted.reversed.toList();
}
