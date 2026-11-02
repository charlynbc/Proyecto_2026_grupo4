import 'package:dio/dio.dart';

import '../models/cancellation_result.dart';
import 'appointment_cancellation_repository.dart';

class ApiAppointmentCancellationRepository
    implements AppointmentCancellationRepository {
  ApiAppointmentCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<CancellationResult> cancel(int id) {
    throw UnimplementedError();
  }
}
