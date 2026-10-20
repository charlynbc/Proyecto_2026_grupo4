import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// El idioma de la app: español de Uruguay. Con él los textos de Material (el
/// calendario, los tooltips, el menú de copiar y pegar) salen en español, la
/// semana del calendario empieza el lunes y los meses y días tienen sus
/// nombres. La variante `es_UY` cambia solo la redacción de algunos textos
/// respecto de `es`; las fechas usan los mismos datos.
const Locale kAppLocale = Locale('es', 'UY');

const List<Locale> kSupportedLocales = [kAppLocale];

final List<LocalizationsDelegate<dynamic>> kLocalizationsDelegates =
    GlobalMaterialLocalizations.delegates;
