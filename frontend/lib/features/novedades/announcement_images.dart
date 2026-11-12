/// Ancho, en píxeles físicos, al que se decodifican las imágenes de las
/// novedades. Es único para el carrusel de Inicio, la fila de la Cartelera y
/// la galería del detalle: así comparten la misma entrada de la caché de
/// imágenes. Sin esto cada imagen se decodifica a su tamaño original, que
/// puede llegar a 6000x6000 px. No baja el peso de la descarga.
const int kAnnouncementImageCacheWidth = 1280;
