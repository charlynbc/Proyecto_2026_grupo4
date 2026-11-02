import '../../../core/fakes/fake_admin_database.dart';
import '../models/specialty.dart';
import '../models/specialty_filters.dart';
import 'specialty_search_repository.dart';

/// Búsqueda local de RF-36 sobre las especialidades de la base falsa compartida.
class FakeSpecialtySearchRepository implements SpecialtySearchRepository {
  FakeSpecialtySearchRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) async {
    await Future<void>.delayed(latency);
    final name = filters.name?.trim() ?? '';
    if (name.length > 120) {
      throw const SpecialtySearchException(
        SpecialtySearchFailure.validation,
        'El nombre no puede superar los 120 caracteres.',
      );
    }

    final search = name.toLowerCase();
    final items = [
      for (final specialty in _db.specialties)
        if ((search.isEmpty ||
                specialty.name.toLowerCase().contains(search)) &&
            (filters.requiresReferral == null ||
                specialty.requiresReferral == filters.requiresReferral))
          specialty,
    ];

    // La copia conserva el orden de alta; solo se ordena si se pidió nombre.
    if (filters.order == SpecialtyOrder.name) {
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return items;
  }
}
