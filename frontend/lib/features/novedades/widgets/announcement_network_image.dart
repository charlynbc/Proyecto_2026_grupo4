import 'package:flutter/material.dart';

import '../announcement_images.dart';

/// Una imagen de red de una novedad. Arma el proveedor (con la caché por id
/// de imagen), muestra [placeholder] mientras carga y [error] si falla. Es el
/// único lugar donde se construyen estas imágenes: el carrusel, la fila de la
/// Cartelera y la galería del detalle.
class AnnouncementNetworkImage extends StatelessWidget {
  const AnnouncementNetworkImage({
    super.key,
    required this.imageId,
    required this.url,
    required this.cacheWidth,
    required this.placeholder,
    required this.error,
    this.fit,
    this.width,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.imageKey,
  });

  /// El id de la imagen del contrato, que es la clave de la caché. Si no
  /// viene, la caché usa la URL.
  final int? imageId;
  final String url;

  /// El ancho de decodificación en píxeles físicos, o `null` para el tamaño
  /// original. Las vistas pasan [kAnnouncementImageCacheWidth].
  final int? cacheWidth;
  final WidgetBuilder placeholder;
  final WidgetBuilder error;
  final BoxFit? fit;
  final double? width;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  /// La clave del `Image` que se dibuja.
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    return Image(
      key: imageKey,
      image: announcementImageProvider(
        imageId: imageId,
        url: url,
        cacheWidth: cacheWidth,
      ),
      width: width,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(context),
      errorBuilder: (context, _, _) => error(context),
    );
  }
}
