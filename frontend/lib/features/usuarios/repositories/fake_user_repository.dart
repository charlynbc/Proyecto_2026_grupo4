import 'dart:math' as math;

import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/validators/uruguayan_ci_validator.dart';
import '../../auth/models/user_role.dart';
import '../models/new_user.dart';
import '../models/user_account.dart';
import '../models/user_filters.dart';
import '../models/user_page.dart';
import 'user_repository.dart';

/// Implementación en memoria de [UserRepository] para `USE_FAKES=true`.
///
/// Aplica las reglas que aplicará el servidor (CU 3.5.2): dígito verificador
/// de la CI, nombre, apellido y fecha de nacimiento coincidentes para una CI
/// que ya existe, una sola cuenta de Socio por CI y una sola cuenta de
/// empleado habilitada o pendiente por CI (una inactivada no cuenta). Los
/// rechazos de formato (400) se evalúan antes que los de unicidad (409).
class FakeUserRepository implements UserRepository {
  FakeUserRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<void> createUser(NewUser user) async {
    await Future<void>.delayed(latency);
    if (!isValidUruguayanCi(user.ci)) throw const InvalidCiException();
    _validateSpecialties(user);

    final firstName = user.firstName.trim();
    final lastName = user.lastName.trim();
    final sameCi = _db.accounts.where((a) => a.ci == user.ci).toList();
    if (sameCi.isNotEmpty) {
      final known = sameCi.first;
      final sameBirthDate =
          known.birthDate.year == user.birthDate.year &&
          known.birthDate.month == user.birthDate.month &&
          known.birthDate.day == user.birthDate.day;
      if (known.firstName != firstName ||
          known.lastName != lastName ||
          !sameBirthDate) {
        throw const MismatchedPersonDataException();
      }
    }

    if (user.role == UserRole.socio) {
      if (sameCi.any((a) => a.role == UserRole.socio)) {
        throw const DuplicateMemberException();
      }
    } else if (sameCi.any(
      (a) => a.role != UserRole.socio && a.status == AccountStatus.active,
    )) {
      throw const DuplicateStaffException();
    }

    _db.accounts.add(
      FakeAccount(
        id: _db.newAccountId(),
        ci: user.ci,
        firstName: firstName,
        lastName: lastName,
        birthDate: DateTime.utc(
          user.birthDate.year,
          user.birthDate.month,
          user.birthDate.day,
        ),
        email: user.email.trim(),
        role: user.role,
        activated: false,
        createdAt: _db.clock().toUtc(),
        specialtyIds: user.role == UserRole.medico ? user.specialtyIds : [],
      ),
    );
  }

  /// `VALIDACION`: un Médico necesita una o más especialidades existentes y
  /// los demás roles no llevan ninguna.
  void _validateSpecialties(NewUser user) {
    if (user.role != UserRole.medico) {
      if (user.specialtyIds.isNotEmpty) {
        throw const ApiException(
          'Solo los médicos tienen especialidades. Quitá las que elegiste.',
        );
      }
      return;
    }
    final known = _db.specialties.map((s) => s.id).toSet();
    if (user.specialtyIds.isEmpty || !known.containsAll(user.specialtyIds)) {
      throw const ApiException(
        'Elegí una o más especialidades de la lista para el médico.',
      );
    }
  }

  @override
  Future<UserPage> listUsers(UserFilters filters) async {
    await Future<void>.delayed(latency);
    final query = _fold(filters.query.trim());
    final matches = _db.accounts.where((a) {
      if (filters.role != null && a.role != filters.role) return false;
      if (filters.status != null && a.status != filters.status) return false;
      if (query.isEmpty) return true;
      return a.ci.contains(query) || _fold(a.lastName).contains(query);
    }).toList();

    int byLastName(FakeAccount a, FakeAccount b) {
      final byLast = _fold(a.lastName).compareTo(_fold(b.lastName));
      if (byLast != 0) return byLast;
      final byFirst = _fold(a.firstName).compareTo(_fold(b.firstName));
      return byFirst != 0 ? byFirst : a.id.compareTo(b.id);
    }

    matches.sort((a, b) {
      final result = switch (filters.order) {
        UserOrder.lastName => byLastName(a, b),
        UserOrder.createdAt => a.createdAt.compareTo(b.createdAt),
      };
      return filters.ascending ? result : -result;
    });

    final size = filters.size.clamp(1, 100);
    final page = math.max(0, filters.page);
    final start = math.min(page * size, matches.length);
    final end = math.min(start + size, matches.length);
    return UserPage(
      items: [for (final a in matches.sublist(start, end)) a.toAccount()],
      page: page,
      size: size,
      total: matches.length,
    );
  }

  /// Minúsculas y sin tildes, para buscar y ordenar por apellido.
  static String _fold(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      out.write(index == -1 ? char : to[index]);
    }
    return out.toString();
  }
}
