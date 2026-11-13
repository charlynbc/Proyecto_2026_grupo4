import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../../core/utils/uruguay_time.dart';
import '../../../agenda/models/agenda_time.dart';
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

class FakeReferralStatisticsRepository implements ReferralStatisticsRepository {
  FakeReferralStatisticsRepository({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    final now = UruguayTime.toUruguay(clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    final rows = <ReferralItem>[
      if (specialtyId == null || specialtyId == 1)
        const ReferralItem(
          name: 'Cardiología',
          issued: 10,
          used: 5,
          available: 3,
          expired: 2,
          percentage: 71.43,
          utilization: '71.43 %',
        ),
      if (specialtyId != null && specialtyId != 1)
        const ReferralItem(
          name: 'Cardiología',
          issued: 0,
          used: 0,
          available: 0,
          expired: 0,
          percentage: null,
          utilization: 'Sin datos',
        ),
      const ReferralItem(
        name: 'Pediatría',
        issued: 0,
        used: 0,
        available: 0,
        expired: 0,
        percentage: null,
        utilization: 'Sin datos',
      ),
    ];
    return ReferralStatistics(from: start, to: end, items: rows);
  }
}
