import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_page.dart';
import 'announcements_repository.dart';

class ApiAnnouncementsRepository implements AnnouncementsRepository {
  ApiAnnouncementsRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    final form = FormData()
      ..files.add(
        MapEntry(
          'datos',
          MultipartFile.fromString(
            jsonEncode({
              'titulo': draft.title,
              if (draft.summary?.trim().isNotEmpty ?? false)
                'resumen': draft.summary,
              if (draft.text?.trim().isNotEmpty ?? false) 'texto': draft.text,
            }),
            contentType: DioMediaType('application', 'json'),
          ),
        ),
      )
      ..files.addAll([
        for (final image in draft.images)
          MapEntry(
            'imagenes',
            MultipartFile.fromBytes(
              image.bytes,
              filename: image.name,
              contentType: DioMediaType('image', image.subtype),
            ),
          ),
      ]);
    try {
      final response = await _dio.post<Object?>(
        ApiRoutes.announcements,
        data: form,
      );
      if (response.statusCode != 201) throw _unconfirmedPublication;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == null || status >= 500 && status != 503) {
        throw _unconfirmedPublication;
      }
      throw ApiException.fromDio(error);
    }
  }

  static const _unconfirmedPublication = ApiException(
    'No pudimos confirmar la publicación. Revisá la cartelera antes de volver a publicar.',
  );

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    if (page < 0) throw ArgumentError.value(page, 'page');
    try {
      final response = await _dio.get<Object?>(
        ApiRoutes.announcements,
        queryParameters: {'page': page, 'size': AnnouncementPage.pageSize},
      );
      final result = AnnouncementPage.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (result.page != page) throw const FormatException('Página inesperada');
      return result;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<AnnouncementDetail> detail(int id) async {
    if (id <= 0) throw const AnnouncementNotFoundException();
    try {
      final response = await _dio.get<Object?>(ApiRoutes.announcement(id));
      final result = AnnouncementDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (result.id != id) {
        throw const FormatException('Identificador inesperado');
      }
      return result;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404 &&
          apiCodeOf(error) == 'NO_ENCONTRADO') {
        throw const AnnouncementNotFoundException();
      }
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<List<Announcement>> latest() async {
    try {
      final response = await _dio.get<Object?>(
        ApiRoutes.announcements,
        queryParameters: {'page': 0, 'size': 5},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['items'] is! List) {
        throw const ApiException();
      }
      return [
        for (final item in data['items'] as List)
          Announcement.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
