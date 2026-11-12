import 'package:flutter/widgets.dart';

import 'announcement_image_provider.dart';

/// Ancho, en píxeles físicos, al que se decodifican las imágenes de las
/// novedades. Es único para el carrusel de Inicio, la fila de la Cartelera y
/// la galería del detalle: así comparten la misma entrada de la caché de
/// imágenes. Sin esto cada imagen se decodifica a su tamaño original, que
/// puede llegar a 6000x6000 px. No baja el peso de la descarga.
const int kAnnouncementImageCacheWidth = 1280;

/// Descarga y decodifica [provider] antes de que se muestre, y completa cuando
/// termina de cargar o falla (nunca con error). Se inyecta en el carrusel y en
/// la galería para poder ver qué se precarga y controlar cuándo termina.
typedef AnnouncementImagePrecache = Future<void> Function(
  BuildContext context,
  ImageProvider provider,
);

/// El proveedor de la imagen de red de una novedad. Con [imageId] se guarda
/// en la caché por id (ver [AnnouncementImageProvider]); sin id, por URL. Es
/// el mismo que usan las vistas, así que lo precargado se reutiliza.
ImageProvider announcementImageProvider({
  required int? imageId,
  required String url,
  required int? cacheWidth,
}) {
  if (imageId == null) {
    return cacheWidth == null
        ? NetworkImage(url)
        : ResizeImage(NetworkImage(url), width: cacheWidth);
  }
  return AnnouncementImageProvider(
    imageId: imageId,
    url: url,
    cacheWidth: cacheWidth,
  );
}

/// Precarga [provider]. Si la descarga falla no hace nada: la pantalla ya
/// muestra su propio placeholder o mensaje cuando llega a la imagen. Tampoco
/// hace nada si [context] ya se desmontó (por ejemplo, el usuario salió de la
/// pantalla mientras esperaba): en ese caso completa enseguida.
Future<void> precacheAnnouncementImage(
  BuildContext context,
  ImageProvider provider,
) {
  if (!context.mounted) return Future<void>.value();
  return precacheImage(provider, context, onError: (_, _) {});
}
