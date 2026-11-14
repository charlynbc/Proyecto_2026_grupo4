import '../../../core/fakes/fake_admin_database.dart';
import '../../auth/models/user_role.dart';
import '../models/account_status_change.dart';
import '../models/user_account.dart';
import 'user_status_repository.dart';

/// Implementación en memoria de [UserStatusRepository] para `USE_FAKES=true`.
/// Cambia el estado de la cuenta dentro de `db.accounts` y aplica las reglas
/// del servidor. El plazo y las consultas de un médico no se modelan: solo el
/// conjunto [doctorsWithActiveShifts], que por defecto tiene a Carla Méndez.
class FakeUserStatusRepository implements UserStatusRepository {
  FakeUserStatusRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
    Set<int>? doctorsWithActiveShifts,
  }) : doctorsWithActiveShifts = doctorsWithActiveShifts ?? _carla(_db);

  /// El id del administrador que "hace" los cambios en la base falsa: el
  /// de la cuenta de la sesión falsa.
  static const int _adminId = kFakeAdminAccountId;

  final FakeAdminDatabase _db;
  final Duration latency;

  /// Ids de médicos con fechas de turnos activas: no se pueden inactivar.
  final Set<int> doctorsWithActiveShifts;

  /// Última inactivación y reactivación de cada cuenta (como las guarda el
  /// servidor), para devolverlas completas.
  final _audit = <int, _Audit>{};

  static Set<int> _carla(FakeAdminDatabase db) => {
    for (final a in db.accounts)
      if (a.ci == '34567894' && a.role == UserRole.medico) a.id,
  };

  @override
  Future<AccountStatusChange> deactivate(int id) async {
    await Future<void>.delayed(latency);
    if (id == _adminId) {
      throw const UserStatusException(
        UserStatusFailure.ownAccount,
        'No puede inactivar su propia cuenta',
      );
    }
    final account = _employee(id);
    if (account.status == AccountStatus.inactive) {
      throw const UserStatusException(
        UserStatusFailure.alreadyInactive,
        'La cuenta ya está inactiva.',
      );
    }
    if (doctorsWithActiveShifts.contains(id)) {
      throw const UserStatusException(
        UserStatusFailure.doctorHasShifts,
        'El médico tiene fechas de turnos activas.',
      );
    }
    final audit = (_audit[id] ?? const _Audit()).deactivatedNow(
      _db.clock().toUtc(),
    );
    _audit[id] = audit;
    return _replace(account, AccountStatus.inactive, audit);
  }

  @override
  Future<AccountStatusChange> reactivate(int id) async {
    await Future<void>.delayed(latency);
    if (id == _adminId) {
      throw const UserStatusException(
        UserStatusFailure.ownAccount,
        'No puede reactivar su propia cuenta',
      );
    }
    final account = _employee(id);
    if (account.status == AccountStatus.active) {
      throw const UserStatusException(
        UserStatusFailure.alreadyActive,
        'La cuenta ya está activa.',
      );
    }
    final duplicated = _db.accounts.any(
      (a) =>
          a.id != id &&
          a.ci == account.ci &&
          a.role != UserRole.socio &&
          a.status == AccountStatus.active,
    );
    if (duplicated) {
      throw const UserStatusException(
        UserStatusFailure.duplicateStaff,
        'Ya hay otra cuenta de empleado habilitada con esa CI.',
      );
    }
    final audit = (_audit[id] ?? const _Audit()).reactivatedNow(
      _db.clock().toUtc(),
    );
    _audit[id] = audit;
    return _replace(account, AccountStatus.active, audit);
  }

  /// La cuenta [id], que tiene que existir y ser de un empleado.
  FakeAccount _employee(int id) {
    final account = _db.accounts.where((a) => a.id == id).firstOrNull;
    if (account == null) {
      throw const UserStatusException(
        UserStatusFailure.notFound,
        'No se encontró la cuenta.',
      );
    }
    if (account.role == UserRole.socio) {
      throw const UserStatusException(
        UserStatusFailure.validation,
        'La cuenta no es de un empleado.',
      );
    }
    return account;
  }

  AccountStatusChange _replace(
    FakeAccount account,
    AccountStatus status,
    _Audit audit,
  ) {
    final index = _db.accounts.indexWhere((a) => a.id == account.id);
    _db.accounts[index] = FakeAccount(
      id: account.id,
      ci: account.ci,
      firstName: account.firstName,
      lastName: account.lastName,
      birthDate: account.birthDate,
      email: account.email,
      role: account.role,
      status: status,
      activated: account.activated,
      createdAt: account.createdAt,
      specialtyIds: account.specialtyIds,
      phone1: account.phone1,
      phone2: account.phone2,
      address: account.address,
    );
    return AccountStatusChange(
      id: account.id,
      ci: account.ci,
      firstName: account.firstName,
      lastName: account.lastName,
      role: account.role,
      status: status,
      lastDeactivatedAt: audit.deactivatedAt,
      lastDeactivatedBy: audit.deactivatedAt == null ? null : _adminId,
      lastReactivatedAt: audit.reactivatedAt,
      lastReactivatedBy: audit.reactivatedAt == null ? null : _adminId,
    );
  }
}

class _Audit {
  const _Audit({this.deactivatedAt, this.reactivatedAt});

  final DateTime? deactivatedAt;
  final DateTime? reactivatedAt;

  _Audit deactivatedNow(DateTime now) =>
      _Audit(deactivatedAt: now, reactivatedAt: reactivatedAt);

  _Audit reactivatedNow(DateTime now) =>
      _Audit(deactivatedAt: deactivatedAt, reactivatedAt: now);
}
