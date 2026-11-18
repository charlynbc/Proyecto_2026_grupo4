import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../../core/fakes/fake_admin_database.dart';
import '../../../../core/utils/uruguay_time.dart';
import '../../../agenda/models/agenda_time.dart';
import '../../../especialidades/models/specialty.dart';
import '../models/referral_statistics.dart';

abstract class ReferralStatisticsRepository {
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  });
}

class ApiReferralStatisticsRepository implements ReferralStatisticsRepository {
  ApiReferralStatisticsRepository(this.dio);
  final Dio dio;
  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiRoutes.statsReferrals,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
          'especialidadOrigenId': ?specialtyId,
        },
      );
      return ReferralStatistics.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const ApiException(
          'Tu cuenta no tiene permiso para ver las estadísticas.',
        );
      }
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}

/// Solo para USE_FAKES y pruebas. Devuelve el contrato completo: una fila por
/// especialidad del catálogo, con cero si no tiene pases y con su
/// `requierePase`. Ocultar las de pase libre sin pases es cosa de la pantalla.
///
/// Los 10 pases de ejemplo los emitió Medicina General y van a Cardiología
/// (5 utilizados, 3 disponibles y 2 vencidos). Con Todas o con Medicina
/// General como origen se ven; con cualquier otro origen todo queda en cero.
class FakeReferralStatisticsRepository implements ReferralStatisticsRepository {
  FakeReferralStatisticsRepository({
    DateTime Function()? clock,
    List<Specialty> Function()? catalog,
  }) : clock = clock ?? DateTime.now,
       catalog = catalog ?? _defaultCatalog;

  final DateTime Function() clock;

  /// El catálogo de especialidades que ve el selector de origen.
  final List<Specialty> Function() catalog;

  static List<Specialty> _defaultCatalog() => FakeAdminDatabase().specialties;

  static const _originName = 'medicina general';
  static const _destinationName = 'cardiología';

  static String _key(String name) => FakeAdminDatabase.normalize(name);

  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    final now = UruguayTime.toUruguay(clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    final specialties = catalog();
    final origin = specialties
        .where((s) => _key(s.name) == _originName)
        .map((s) => s.id)
        .firstOrNull;
    final seeded = specialtyId == null || specialtyId == origin;
    final rows =
        [
          for (final specialty in specialties)
            seeded && _key(specialty.name) == _destinationName
                ? ReferralItem(
                    name: specialty.name,
                    requiresReferral: specialty.requiresReferral,
                    issued: 10,
                    used: 5,
                    available: 3,
                    expired: 2,
                    percentage: 71.43,
                    utilization: '71.43 %',
                  )
                : ReferralItem(
                    name: specialty.name,
                    requiresReferral: specialty.requiresReferral,
                    issued: 0,
                    used: 0,
                    available: 0,
                    expired: 0,
                    percentage: null,
                    utilization: 'Sin datos',
                  ),
        ]..sort((a, b) {
          final byIssued = b.issued.compareTo(a.issued);
          return byIssued != 0 ? byIssued : a.name.compareTo(b.name);
        });
    return ReferralStatistics(from: start, to: end, items: rows);
  }
}
