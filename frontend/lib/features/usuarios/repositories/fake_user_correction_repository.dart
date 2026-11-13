import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/forms/email_field_rules.dart';
import '../../../core/validators/uruguayan_ci_validator.dart';
import '../../auth/models/user_role.dart';
import '../models/account_detail.dart';
import 'user_correction_repository.dart';

/// Implementación en memoria de [UserCorrectionRepository] para
/// `USE_FAKES=true`. Aplica las reglas del servidor (contrato, filas 68 y 58)
/// sobre `db.accounts`.
///
/// La CI, el nombre, el apellido y la fecha de nacimiento son de la persona:
/// al corregirlos cambian en todas sus cuentas (las que comparten la CI). Los
/// turnos y consultas de un médico no se modelan: solo [specialtiesInUse], que
/// por defecto marca la especialidad 1 de Carla Méndez.
class FakeUserCorrectionRepository implements UserCorrectionRepository {
  FakeUserCorrectionRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
    Map<int, Set<int>>? specialtiesInUse,
  }) : specialtiesInUse = specialtiesInUse ?? _carla(_db);

  static const int _maxName = 100;
  static const int _maxPhone = 30;

  final FakeAdminDatabase _db;
  final Duration latency;

  /// Por id de cuenta, las especialidades con turnos vigentes o consultas
  /// agendadas: no se pueden quitar.
  final Map<int, Set<int>> specialtiesInUse;

  static Map<int, Set<int>> _carla(FakeAdminDatabase db) => {
    for (final a in db.accounts)
      if (a.ci == '34567894' && a.role == UserRole.medico) a.id: {1},
  };

  @override
  Future<AccountDetail> fetch(int id) async {
    await Future<void>.delayed(latency);
    return _detail(_find(id));
  }

  @override
  Future<AccountDetail> correct(int id, AccountCorrection changes) async {
    await Future<void>.delayed(latency);
    final account = _find(id);
    if (changes.isEmpty) {
      throw const UserCorrectionException(
        UserCorrectionFailure.validation,
        'No hay cambios para guardar.',
      );
    }
    _validateText(changes);
    final newCi = _validateCi(account, changes.ci);
    _validateSpecialties(account, changes.specialtyIds);
    final address = _addressAfter(account, changes);

    final oldCi = account.ci;
    for (var i = 0; i < _db.accounts.length; i++) {
      final current = _db.accounts[i];
      final samePerson = current.ci == oldCi;
      if (current.id != id && !samePerson) continue;
      _db.accounts[i] = FakeAccount(
        id: current.id,
        ci: samePerson ? (newCi ?? current.ci) : current.ci,
        firstName: samePerson
            ? (changes.firstName?.trim() ?? current.firstName)
            : current.firstName,
        lastName: samePerson
            ? (changes.lastName?.trim() ?? current.lastName)
            : current.lastName,
        birthDate: samePerson
            ? (changes.birthDate ?? current.birthDate)
            : current.birthDate,
        email: current.id == id
            ? (changes.email?.trim().toLowerCase() ?? current.email)
            : current.email,
        role: current.role,
        status: current.status,
        activated: current.activated,
        createdAt: current.createdAt,
        specialtyIds: current.id == id
            ? (changes.specialtyIds ?? current.specialtyIds)
            : current.specialtyIds,
        phone1: current.id == id
            ? (changes.phone1?.trim() ?? current.phone1)
            : current.phone1,
        phone2: current.id == id
            ? (changes.phone2 == null
                  ? current.phone2
                  : _clean(changes.phone2!.value))
            : current.phone2,
        address: current.id == id ? address : current.address,
      );
    }
    return _detail(_find(id));
  }

  FakeAccount _find(int id) {
    final account = _db.accounts.where((a) => a.id == id).firstOrNull;
    if (account == null) {
      throw const UserCorrectionException(
        UserCorrectionFailure.notFound,
        'No encontramos esa cuenta.',
      );
    }
    return account;
  }

  /// `""` y `null` borran el dato.
  static String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  void _validateText(AccountCorrection changes) {
    String? problem;
    final first = changes.firstName?.trim();
    final last = changes.lastName?.trim();
    final phone1 = changes.phone1?.trim();
    final phone2 = changes.phone2?.value?.trim();
    if (first != null && (first.isEmpty || first.length > _maxName)) {
      problem = 'El nombre es obligatorio y admite hasta $_maxName caracteres.';
    } else if (last != null && (last.isEmpty || last.length > _maxName)) {
      problem =
          'El apellido es obligatorio y admite hasta $_maxName caracteres.';
    } else if (phone1 != null &&
        (phone1.isEmpty || phone1.length > _maxPhone)) {
      problem =
          'El teléfono 1 es obligatorio y admite hasta $_maxPhone caracteres.';
    } else if (phone2 != null && phone2.length > _maxPhone) {
      problem = 'El teléfono 2 admite hasta $_maxPhone caracteres.';
    } else if (changes.email != null && validateEmail(changes.email) != null) {
      problem = 'El correo no es válido.';
    }
    if (problem != null) {
      throw UserCorrectionException(UserCorrectionFailure.validation, problem);
    }
  }

  /// La CI corregida, solo dígitos, o `null` si no cambia.
  String? _validateCi(FakeAccount account, String? raw) {
    if (raw == null) return null;
    final ci = raw.replaceAll(RegExp(r'[.\-\s]'), '');
    if (!isValidUruguayanCi(ci)) {
      throw const UserCorrectionException(
        UserCorrectionFailure.invalidCi,
        'La cédula no es válida. Revisá el dígito verificador.',
      );
    }
    if (ci != account.ci && _db.accounts.any((a) => a.ci == ci)) {
      throw const UserCorrectionException(
        UserCorrectionFailure.ciInUse,
        'Esa cédula ya pertenece a otra persona.',
      );
    }
    return ci;
  }

  void _validateSpecialties(FakeAccount account, List<int>? ids) {
    if (ids == null) return;
    if (account.role != UserRole.medico) {
      throw const UserCorrectionException(
        UserCorrectionFailure.validation,
        'Solo los médicos tienen especialidades.',
      );
    }
    final known = _db.specialties.map((s) => s.id).toSet();
    if (ids.isEmpty ||
        ids.toSet().length != ids.length ||
        !known.containsAll(ids)) {
      throw const UserCorrectionException(
        UserCorrectionFailure.validation,
        'Elegí una o más especialidades de la lista, sin repetir.',
      );
    }
    final locked = specialtiesInUse[account.id] ?? const <int>{};
    if (!ids.toSet().containsAll(
      locked.intersection(account.specialtyIds.toSet()),
    )) {
      throw const UserCorrectionException(
        UserCorrectionFailure.specialtyInUse,
        'No se puede quitar una especialidad con turnos vigentes o consultas '
        'agendadas.',
      );
    }
  }

  /// La dirección que queda; una cuenta activada no puede quedar sin ella.
  String? _addressAfter(FakeAccount account, AccountCorrection changes) {
    final change = changes.address;
    if (change == null) return account.address;
    final value = _clean(change.value);
    if (value == null && account.activated) {
      throw const UserCorrectionException(
        UserCorrectionFailure.validation,
        'Una cuenta activada tiene que conservar su dirección.',
      );
    }
    return value;
  }

  AccountDetail _detail(FakeAccount a) => AccountDetail(
    id: a.id,
    ci: a.ci,
    firstName: a.firstName,
    lastName: a.lastName,
    birthDate: a.birthDate,
    role: a.role,
    email: a.email,
    phone1: a.phone1,
    phone2: a.phone2,
    address: a.address,
    specialtyIds: a.role == UserRole.medico ? a.specialtyIds : const [],
    status: a.status,
    activated: a.activated,
  );
}
