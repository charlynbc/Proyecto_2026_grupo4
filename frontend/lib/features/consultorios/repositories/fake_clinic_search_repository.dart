import '../../../core/fakes/fake_admin_database.dart';
import '../models/clinic.dart';
import '../models/clinic_filters.dart';
import 'clinic_search_repository.dart';

/// Búsqueda local de RF-37 sobre los consultorios de la base falsa compartida.
class FakeClinicSearchRepository implements ClinicSearchRepository {
  FakeClinicSearchRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<List<Clinic>> search(ClinicFilters filters) async {
    await Future<void>.delayed(latency);
    final name = filters.name?.trim() ?? '';
    final location = filters.location?.trim() ?? '';
    if (name.length > 120) {
      throw const ClinicSearchException(
        ClinicSearchFailure.validation,
        'El nombre no puede superar los 120 caracteres.',
      );
    }
    if (location.length > 200) {
      throw const ClinicSearchException(
        ClinicSearchFailure.validation,
        'La ubicación no puede superar los 200 caracteres.',
      );
    }

    final search = name.toLowerCase();
    final place = location.toLowerCase();
    final items = [
      for (final clinic in _db.clinics)
        if ((search.isEmpty || clinic.name.toLowerCase().contains(search)) &&
            (place.isEmpty || clinic.location.toLowerCase().contains(place)))
          clinic,
    ];

    items.sort((a, b) {
      final left = filters.order == ClinicOrder.location ? a.location : a.name;
      final right = filters.order == ClinicOrder.location ? b.location : b.name;
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return items;
  }
}
