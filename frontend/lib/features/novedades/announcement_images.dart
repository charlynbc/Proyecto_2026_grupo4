import 'package:flutter/widgets.dart';

/// Ancho, en píxeles físicos, al que se decodifican las imágenes de las
/// novedades. Es único para el carrusel de Inicio, la fila de la Cartelera y
/// la galería del detalle: así comparten la misma entrada de la caché de
/// imágenes. Sin esto cada imagen se decodifica a su tamaño original, que
/// puede llegar a 6000x6000 px. No baja el peso de la descarga.
const int kAnnouncementImageCacheWidth = 1280;

/// Descarga y decodifica [provider] antes de que se muestre. Se inyecta en el
/// carrusel y en la galería para poder ver qué se precarga.
typedef AnnouncementImagePrecache = void Function(
  BuildContext context,
  ImageProvider provider,
);

/// El proveedor de la imagen de red de una novedad. Es el mismo que usa
/// `Image.network(cacheWidth: ...)`, así que lo precargado se reutiliza.
ImageProvider announcementNetworkImage(String url) =>
    ResizeImage(NetworkImage(url), width: kAnnouncementImageCacheWidth);

/// Precarga [provider]. Si la descarga falla no hace nada: la pantalla ya
/// muestra su propio placeholder o mensaje cuando llega a la imagen. Tampoco
/// hace nada si [context] ya se desmontó (por ejemplo, el usuario salió de la
/// pantalla mientras esperaba).
void precacheAnnouncementImage(BuildContext context, ImageProvider provider) {
  if (!context.mounted) return;
  precacheImage(provider, context, onError: (_, _) {});
}
