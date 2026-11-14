import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../../core/utils/uruguay_time.dart';
import '../../../agenda/models/agenda_time.dart';
import '../models/time_slot_statistics.dart';

enum TimeSlotView { consultations, arrivals }

abstract class TimeSlotStatisticsRepository {
  Future<TimeSlotStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    required TimeSlotView view,
  });
}

class ApiTimeSlotStatisticsRepository implements TimeSlotStatisticsRepository {
  ApiTimeSlotStatisticsRepository(this.dio);
  final Dio dio;
  @override
  Future<TimeSlotStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    required TimeSlotView view,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiRoutes.statsTimeSlots,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
          'especialidadId': ?specialtyId,
          'vista': view == TimeSlotView.consultations
              ? 'CONSULTAS'
              : 'LLEGADAS',
        },
      );
      return TimeSlotStatistics.fromJson(
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

class FakeTimeSlotStatisticsRepository implements TimeSlotStatisticsRepository {
  FakeTimeSlotStatisticsRepository({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  @override
  Future<TimeSlotStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    required TimeSlotView view,
  }) async {
    final now = UruguayTime.toUruguay(clock());
    return TimeSlotStatistics(
      from: from ?? DateTime.utc(now.year, now.month),
      to: to ?? DateTime.utc(now.year, now.month + 1, 0),
      cells: [
        for (var day = 1; day <= 7; day++)
          for (var hour = 0; hour < 24; hour++)
            TimeSlotCell(
              day: day,
              hour: hour,
              count:
                  hour >= 8 &&
                      hour < 18 &&
                      day < 6 &&
                      (specialtyId == null || specialtyId == 1)
                  ? (view == TimeSlotView.consultations ? day : day + 1)
                  : 0,
            ),
      ],
    );
  }
}
