import '../../../core/fakes/fake_admin_database.dart';
import '../models/clinic.dart';
import 'clinic_correction_repository.dart';

class FakeClinicCorrectionRepository implements ClinicCorrectionRepository {
  FakeClinicCorrectionRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<Clinic> correct(int id, {String? name, String? location}) async {
    await Future<void>.delayed(latency);
    final index = _db.clinics.indexWhere((clinic) => clinic.id == id);
    if (index == -1) {
      throw const ClinicCorrectionException(
        ClinicCorrectionFailure.notFound,
        'No se encontró el consultorio.',
      );
    }

    final current = _db.clinics[index];
    final correctedName = name?.trim();
    final correctedLocation = location?.trim();
    if (name != null) {
      if (correctedName!.isEmpty) {
        throw const ClinicCorrectionException(
          ClinicCorrectionFailure.validation,
          'El nombre es obligatorio',
        );
      }
      if (correctedName.length > 120) {
        throw const ClinicCorrectionException(
          ClinicCorrectionFailure.validation,
          'El nombre supera 120 caracteres',
        );
      }
    }
    if (location != null) {
      if (correctedLocation!.isEmpty) {
        throw const ClinicCorrectionException(
          ClinicCorrectionFailure.validation,
          'La ubicación es obligatoria',
        );
      }
      if (correctedLocation.length > 200) {
        throw const ClinicCorrectionException(
          ClinicCorrectionFailure.validation,
          'La ubicación supera 200 caracteres',
        );
      }
    }

    if (correctedName != null) {
      final normalizedName = FakeAdminDatabase.normalize(correctedName);
      if (_db.clinics.any(
        (clinic) =>
            clinic.id != id &&
            FakeAdminDatabase.normalize(clinic.name) == normalizedName,
      )) {
        throw const ClinicCorrectionException(
          ClinicCorrectionFailure.duplicate,
          'Ya existe un consultorio con ese nombre o número.',
        );
      }
    }

    final corrected = Clinic(
      id: current.id,
      name: correctedName ?? current.name,
      location: correctedLocation ?? current.location,
    );
    _db.clinics[index] = corrected;
    return corrected;
  }
}
