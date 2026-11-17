# Gestión de cartelera: propuesta de contrato en implementación

Las operaciones requieren autenticación. Las rutas bajo `/api/admin` requieren
`ADMINISTRADOR`; el servidor obtiene el autor del token. Fechas ISO 8601 con
desplazamiento. La interfaz presenta fechas en `America/Montevideo`.

Al publicar mediante `POST /api/anuncios`, el JSON multipart `datos` agrega
`vigenteDesde` opcional y `vigenteHasta` obligatorio. Un inicio nulo comienza
inmediatamente; el fin es exclusivo y debe ser posterior al inicio (o al
momento de publicación si el inicio se omite). Las publicaciones preexistentes
pueden conservar el fin nulo. Esta exigencia rompe la publicación de clientes
anteriores que no envían fin: coordinar el cambio con Flutter antes de desplegar.

`GET /api/anuncios` y `GET /api/anuncios/{id}` solo muestran anuncios vigentes;
el detalle fuera de vigencia responde 404. El listado conserva orden por fecha
de publicación descendente e ID descendente. `GET /api/anuncios/carrusel`
devuelve una lista de detalles vigentes en orden de posición, sin huecos.
Flutter debe usar este endpoint en Inicio en lugar de pedir `size=5` al listado.

`GET /api/admin/anuncios` devuelve los anuncios con `id`, `titulo`,
`publicadoEn`, `vigenteDesde`, `vigenteHasta`, `estado` (PROGRAMADO, VIGENTE,
VENCIDO) y `posicion` opcional. `PUT /api/admin/anuncios/{id}/vigencia` recibe
`{"vigenteDesde":null,"vigenteHasta":"2027-01-01T00:00:00-03:00"}` y
responde 204; exige fin y valida su relación con inicio.

`GET /api/admin/anuncios/{id}` devuelve el detalle de cualquier anuncio, esté
vigente, programado o vencido (el detalle público `GET /api/anuncios/{id}` sigue
respondiendo 404 fuera de vigencia y no cambia). Solo `ADMINISTRADOR`. Responde
200 con el contenido del detalle público más los datos de gestión:

```json
{
  "id": 42,
  "titulo": "Campaña de vacunación",
  "resumen": "Resumen corto",
  "texto": "**Comienza** el lunes (Markdown)",
  "publicadoEn": "2026-11-01T10:00:00-03:00",
  "vigenteDesde": null,
  "vigenteHasta": "2026-11-10T00:00:00-03:00",
  "estado": "VENCIDO",
  "posicion": null,
  "imagenes": [{ "id": 101, "orden": 0, "url": "https://.../storage/v1/object/sign/anuncios/..." }]
}
```

`estado` y `posicion` se calculan igual que en el listado
(`GET /api/admin/anuncios`); `resumen`, `texto` y `vigenteDesde` pueden ser
`null`. Las `url` de las imágenes son enlaces temporales de Storage válidos por
una hora, como en el detalle público. Si el anuncio no existe responde
`404 NO_ENCONTRADO` con el formato de error habitual (`{"code","message"}`);
sin sesión responde 401 y con otro rol 403.

`PUT /api/admin/anuncios/{id}` edita el texto de una novedad ya publicada: hoy una
novedad con un error solo puede eliminarse y volver a publicarse. Solo
`ADMINISTRADOR`. Estado: IMPLEMENTADA EN BACKEND (tramo de texto; las imágenes se
editan en una versión posterior de este mismo endpoint). El pedido es
`multipart/form-data` con una parte `datos` de tipo `application/json`, igual que
`POST /api/anuncios`:

```json
{ "titulo": "Campaña de vacunación", "resumen": "Comienza el lunes", "texto": "**Comienza** el lunes (Markdown)" }
```

`titulo` es obligatorio (1 a 160 caracteres sin contar espacios exteriores);
`resumen` es opcional (hasta 300 caracteres) y `texto` es opcional; un `texto` o un
`resumen` solo de espacios se guarda como `null`. Son las mismas reglas que al
publicar. Una novedad no puede quedar sin texto y sin imágenes: si `texto` falta o
está en blanco y la novedad no tiene imágenes, responde 400. El pedido no incluye
`vigenteDesde` ni `vigenteHasta`: la edición **no cambia la vigencia, la posición en
el carrusel, el autor ni la fecha de publicación**, y tampoco las imágenes. Si el
pedido trae partes de archivo (cualquier parte distinta de `datos`) responde 400,
porque `datos` no indica imágenes.

Responde `204 No Content` sin cuerpo. Errores, con el formato habitual
(`{"code","message"}`):

- `400 VALIDACION` con `message` exacto: `El título es obligatorio y admite hasta 160
  caracteres`; `El resumen admite hasta 300 caracteres`; `La novedad debe tener texto
  o al menos una imagen`; `Se enviaron archivos pero datos no indica imágenes`;
  `Hay dos archivos con el mismo nombre: {nombre}`; y `Faltan datos o la solicitud
  tiene un formato inválido` si falta la parte `datos` o su JSON no se puede leer.
- `404 NO_ENCONTRADO` (`Anuncio no encontrado`) si la novedad no existe.
- `401` sin sesión y `403` con cualquier otro rol.

Si dos administradores guardan a la vez, el último guardado prevalece. La edición
toma el mismo candado que el borrado, de modo que una edición y un borrado no se
pisan.

Efecto lateral de esta versión: `PUT /api/admin/anuncios/{id}/vigencia` y
`PUT /api/admin/carrusel` responden ahora `400 VALIDACION` con el cuerpo JSON
habitual (`Faltan datos o la solicitud tiene un formato inválido`) cuando el cuerpo
del pedido no se puede leer, en lugar del 400 por defecto sin cuerpo que devolvían
antes. Los clientes que ya tratan cualquier 400 como error de validación no
necesitan cambios.

`GET /api/admin/carrusel` devuelve `{"posiciones":[]}`. Para guardar,
`PUT` a la misma ruta recibe la selección completa, por ejemplo
`{"posiciones":[{"posicion":1,"anuncioId":42},{"posicion":3,"anuncioId":56}]}`.
Las posiciones van de 1 a 5, sin posiciones ni anuncios repetidos. Cada guardado
reemplaza la selección anterior: si dos administradores guardan a la vez, el
último guardado procesado prevalece sin aviso. Las operaciones concurrentes se
serializan para evitar resultados parciales. Las asignaciones no vigentes
permanecen reservadas y no se reemplazan solas.

`DELETE /api/admin/anuncios/{id}` responde 202 tras confirmar en base el borrado
del anuncio, sus filas de imágenes y su posición; una cola durable conserva
las referencias para reintentar su borrado en Storage. La respuesta no confirma
que todos los archivos ya se hayan borrado. No existe reactivación. La interfaz
debe advertir que la acción es definitiva y pedir confirmación.

Los enlaces firmados ya emitidos tienen validez de una hora; mientras un archivo
siga pendiente puede seguir siendo accesible, y las copias descargadas o en
caché no se pueden revocar mediante esta operación. El limpiador intenta una
referencia por intervalo (configurable con `app.anuncios.limpieza-intervalo-ms`,
30 segundos por defecto). Las fallas quedan registradas para reintento.
