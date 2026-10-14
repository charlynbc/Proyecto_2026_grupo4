import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import '../../../core/utils/uruguay_time.dart';
import '../models/professional.dart';
import '../models/time_slot.dart';
import 'agenda_repository.dart';

class ApiAgendaRepository implements AgendaRepository {
  ApiAgendaRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Professional>> listProfessionals() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiRoutes.pocProfessionals,
      );
      return response.data!
          .map((e) => Professional.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<List<TimeSlot>> listTimeSlots({
    required int professionalId,
    required DateTime day,
  }) async {
    final from = UruguayTime.startOfDayIso(day);
    final until = UruguayTime.startOfDayIso(day.add(const Duration(days: 1)));
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiRoutes.pocProfessionalSlots(professionalId),
        queryParameters: {'desde': from, 'hasta': until},
      );
      return response.data!
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> reserve({required int timeSlotId}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiRoutes.pocReservations,
        data: {'horarioId': timeSlotId},
      );
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  Never _throwMapped(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    switch (code) {
      case 'HORARIO_OCUPADO':
        throw const TimeSlotTakenException();
      case 'HORARIO_INICIADO':
        throw const TimeSlotStartedException();
    }
    final message = data is Map ? data['message'] as String? : null;
    if (message != null) throw AgendaException(message);
    throw const AgendaException();
  }
}
