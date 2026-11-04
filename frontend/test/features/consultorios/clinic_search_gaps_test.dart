import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/api_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({'items': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('un nombre vacío no se manda', () {
    expect(const ClinicFilters(name: '').toQueryParameters(), isEmpty);
  });

  test('un nombre de solo espacios no se manda', () {
    expect(const ClinicFilters(name: '   ').toQueryParameters(), isEmpty);
  });

  test('una ubicación vacía no se manda', () {
    expect(const ClinicFilters(location: '').toQueryParameters(), isEmpty);
  });

  test('el sentido descendente no se manda', () {
    expect(
      const ClinicFilters(
        ascending: false,
        order: ClinicOrder.location,
      ).toQueryParameters(),
      {'orden': 'ubicacion'},
    );
  });

  test('los parámetros no incluyen sentido', () {
    final parameters = const ClinicFilters(
      name: '5',
      location: 'norte',
      order: ClinicOrder.location,
    ).toQueryParameters();

    expect(parameters.containsKey('sentido'), isFalse);
    expect(parameters, {
      'nombre': '5',
      'ubicacion': 'norte',
      'orden': 'ubicacion',
    });
  });

  test(
    'el repositorio Api no llama al servidor con una ubicación de 201',
    () async {
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = ApiClinicSearchRepository(dio);

      await expectLater(
        repository.search(
          ClinicFilters(location: List.filled(201, 'b').join()),
        ),
        throwsA(
          isA<ClinicSearchException>().having(
            (error) => error.failure,
            'tipo correspondiente a VALIDACION',
            ClinicSearchFailure.validation,
          ),
        ),
      );
      expect(adapter.last, isNull);
    },
  );

  test('buscar no modifica la base falsa', () async {
    final db = FakeAdminDatabase();
    db.clinics
      ..clear()
      ..addAll(const [
        Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
        Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
        Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
      ]);
    final before = [
      for (final clinic in db.clinics)
        (clinic.id, clinic.name, clinic.location),
    ];
    final repository = FakeClinicSearchRepository(db, latency: Duration.zero);

    await repository.search(const ClinicFilters(order: ClinicOrder.location));

    expect([
      for (final clinic in db.clinics)
        (clinic.id, clinic.name, clinic.location),
    ], before);
  });

  testWidgets('los campos limitan el nombre a 120 y la ubicación a 200', (
    tester,
  ) async {
    final db = FakeAdminDatabase();
    final container = ProviderContainer(
      overrides: [
        clinicSearchRepositoryProvider.overrideWith(
          (ref) async => FakeClinicSearchRepository(db, latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: appTheme, home: const ClinicsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('clinic-filter-name')),
      List.filled(121, 'a').join(),
    );
    await tester.enterText(
      find.byKey(const Key('clinic-filter-location')),
      List.filled(201, 'b').join(),
    );

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('clinic-filter-name')))
          .controller!
          .text
          .length,
      120,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('clinic-filter-location')),
          )
          .controller!
          .text
          .length,
      200,
    );
  });
}
