import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// La clave de la caché de imágenes de una imagen de novedad: su id y el ancho
/// de decodificación, nunca la URL.
///
/// Las URL del contrato son enlaces temporales firmados: la misma imagen llega
/// con otra URL al reabrir el detalle o al refrescar los enlaces, y con la URL
/// como clave se volvería a descargar. Cada imagen de una novedad tiene su
/// propio id (hasta cinco por novedad), así que el id de la imagen la
/// distingue de las otras de la misma novedad.
@immutable
class AnnouncementImageKey {
  const AnnouncementImageKey({
    required this.imageId,
    required this.cacheWidth,
    required this.source,
    required this.sourceKey,
  });

  final int imageId;
  final int? cacheWidth;

  /// De dónde se baja, y la clave de ese origen. No cuentan para la igualdad.
  final ImageProvider<Object> source;
  final Object sourceKey;

  @override
  bool operator ==(Object other) =>
      other is AnnouncementImageKey &&
      other.imageId == imageId &&
      other.cacheWidth == cacheWidth;

  @override
  int get hashCode => Object.hash(imageId, cacheWidth);
}

/// Una imagen de una novedad: baja por [url] (con `NetworkImage`), pero se
/// guarda en la caché de imágenes por [imageId] y [cacheWidth]. Así el
/// carrusel de Inicio, la fila de la Cartelera y el detalle comparten la misma
/// entrada, y un refresco de enlaces no vuelve a bajar lo que ya está en
/// memoria.
///
/// [cacheWidth] es el ancho al que se decodifica (como el de `ResizeImage`):
/// no agranda las imágenes más chicas y conserva la proporción. Con `null` se
/// decodifica al tamaño original.
@immutable
class AnnouncementImageProvider extends ImageProvider<AnnouncementImageKey> {
  const AnnouncementImageProvider({
    required this.imageId,
    required this.url,
    required this.cacheWidth,
    this.sourceBuilder = _network,
  });

  static ImageProvider<Object> _network(String url) => NetworkImage(url);

  final int imageId;
  final String url;
  final int? cacheWidth;

  /// Arma el origen de la descarga. Las pruebas lo cambian para no usar la
  /// red.
  final ImageProvider<Object> Function(String url) sourceBuilder;

  @override
  Future<AnnouncementImageKey> obtainKey(ImageConfiguration configuration) {
    final source = sourceBuilder(url);
    return source
        .obtainKey(configuration)
        .then(
          (sourceKey) => AnnouncementImageKey(
            imageId: imageId,
            cacheWidth: cacheWidth,
            source: source,
            sourceKey: sourceKey,
          ),
        );
  }

  @override
  ImageStreamCompleter loadImage(
    AnnouncementImageKey key,
    ImageDecoderCallback decode,
  ) {
    final width = key.cacheWidth;
    Future<ui.Codec> decodeResized(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) => decode(
      buffer,
      getTargetSize: width == null
          ? null
          : (intrinsicWidth, intrinsicHeight) => ui.TargetImageSize(
              width: intrinsicWidth < width ? intrinsicWidth : width,
            ),
    );

    final completer = key.source.loadImage(key.sourceKey, decodeResized);
    // Una descarga fallida no tiene que quedar en la caché: "Volver a cargar
    // imágenes" la pide de nuevo. El origen solo la saca de la caché con su
    // propia clave, no con esta.
    completer.addListener(
      ImageStreamListener(
        (_, _) {},
        onError: (_, _) {
          scheduleMicrotask(
            () => PaintingBinding.instance.imageCache.evict(key),
          );
        },
      ),
    );
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is AnnouncementImageProvider &&
      other.imageId == imageId &&
      other.cacheWidth == cacheWidth;

  @override
  int get hashCode => Object.hash(imageId, cacheWidth);

  @override
  String toString() =>
      'AnnouncementImageProvider(imageId: $imageId, cacheWidth: $cacheWidth)';
}
