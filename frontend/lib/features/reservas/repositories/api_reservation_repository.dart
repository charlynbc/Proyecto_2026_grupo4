import 'package:dio/dio.dart';

import '../models/reservation.dart';
import 'reservation_repository.dart';

class ApiReservationRepository implements ReservationRepository {
  ApiReservationRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Reservation>> listMine() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/mis-reservas');
      return response.data!
          .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> cancel({required int reservationId}) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/api/reservas/$reservationId/cancelacion',
      );
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  Never _throwMapped(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    if (code == 'RESERVA_NO_ENCONTRADA') {
      throw const ReservationNotFoundException();
    }
    final message = data is Map ? data['message'] as String? : null;
    if (message != null) throw ReservationException(message);
    throw const ReservationException();
  }
}
