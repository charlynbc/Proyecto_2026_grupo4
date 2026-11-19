import 'announcement_draft.dart';

/// Una imagen de la lista final de una edición: una que la novedad ya tiene
/// ([ExistingImageRef]) o una nueva que se sube en el mismo pedido
/// ([NewImageRef]).
sealed class AnnouncementImageRef {
  const AnnouncementImageRef();
}

class ExistingImageRef extends AnnouncementImageRef {
  const ExistingImageRef(this.id);

  final int id;
}

class NewImageRef extends AnnouncementImageRef {
  const NewImageRef(this.upload);

  final AnnouncementImageUpload upload;
}

/// Lo que se envía en `PUT /api/admin/anuncios/{id}`: el texto y, solo si el
/// administrador tocó las imágenes, la lista final en orden. No lleva la
/// vigencia: se cambia con su propia pantalla.
class AnnouncementEdit {
  const AnnouncementEdit({
    required this.title,
    this.summary,
    this.text,
    this.images,
  });

  final String title;
  final String? summary;
  final String? text;

  /// La lista final de imágenes, en orden (la primera es la portada), o
  /// `null` si no se tocaron: en ese caso el pedido no incluye `imagenes`.
  final List<AnnouncementImageRef>? images;
}
