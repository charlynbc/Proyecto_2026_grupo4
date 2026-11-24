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
  "imagenes": [{ "id": 101, "orden": 0, "url": "https://.../storage/v1/object/sign/anuncios/3f2b.png", "urlMiniatura": "https://.../storage/v1/object/sign/anuncios/mini/3f2b.jpg" }]
}
```

`estado` y `posicion` se calculan igual que en el listado
(`GET /api/admin/anuncios`); `resumen`, `texto` y `vigenteDesde` pueden ser
`null`. Las `url` de las imágenes son enlaces temporales de Storage válidos por
una hora, como en el detalle público. `urlMiniatura` es la copia reducida de
la imagen, con las mismas reglas que en el contrato de la consulta de
novedades: siempre figura y es `null` si no hay miniatura o no se pudo firmar.
Si el anuncio no existe responde
`404 NO_ENCONTRADO` con el formato de error habitual (`{"code","message"}`);
sin sesión responde 401 y con otro rol 403.

`PUT /api/admin/anuncios/{id}` edita el texto y las imágenes de una novedad ya
publicada: antes una novedad con un error solo podía eliminarse y volver a
publicarse. Solo `ADMINISTRADOR`. Estado: IMPLEMENTADA EN BACKEND. El pedido es
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
el carrusel, el autor ni la fecha de publicación**.

Imágenes. Si `datos` no trae `imagenes` (ausente o `null`), las imágenes no se
tocan; en ese caso, si el pedido trae partes de archivo (cualquier parte distinta de
`datos`) responde 400. Si trae `imagenes`, esa es la **lista final, en orden**, y la
primera es la portada:

```json
{ "titulo": "Campaña", "texto": "Texto", "imagenes": [ { "id": 12 }, { "archivo": "nueva1" }, { "id": 14 } ] }
```

Cada entrada es `{"id": n}` (una imagen que ya tiene la novedad) o
`{"archivo": "nombre"}` (una imagen nueva, que llega como parte de archivo del mismo
multipart con ese nombre). El servidor guarda `orden` 0, 1, 2 según la posición en
la lista, aunque cambie el orden de las imágenes que ya existían. Las existentes que
no figuran se eliminan: se borran de la base y sus archivos se limpian después con
la misma cola que usa `DELETE` (`app.anuncios.limpieza-intervalo-ms`). Con
`"imagenes": []` se eliminan todas, y solo se acepta si queda texto. Reglas, las
mismas que al publicar: hasta 5 imágenes en total entre existentes y nuevas; cada
archivo nuevo JPEG o PNG real, de hasta 5 MB y hasta 6000 × 6000 píxeles; los `id`
deben pertenecer a esta novedad.

Orden de la operación: primero se valida todo, antes de tocar Storage; luego se suben
las imágenes nuevas, sin bloquear otras operaciones de cartelera; y por último, en una
sola transacción con el candado del borrado, se vuelve a comprobar que la novedad
existe y se aplican texto, imágenes nuevas, orden y borrado. Es todo o nada: si falla
la subida de una imagen nueva responde `503 ALMACENAMIENTO_NO_DISPONIBLE`, se borran
las ya subidas y no cambia nada, ni el texto ni las imágenes. Si la novedad se elimina
mientras se suben las imágenes, responde 404 y se borran las ya subidas.

Responde `204 No Content` sin cuerpo. Errores, con el formato habitual
(`{"code","message"}`):

- `400 VALIDACION` con `message` exacto: `El título es obligatorio y admite hasta 160
  caracteres`; `El resumen admite hasta 300 caracteres`; `La novedad debe tener texto
  o al menos una imagen`; `Se enviaron archivos pero datos no indica imágenes`;
  `Hay dos archivos con el mismo nombre: {nombre}`; y `Faltan datos o la solicitud
  tiene un formato inválido` si falta la parte `datos` o su JSON no se puede leer.
  Con imágenes: `La novedad admite hasta 5 imágenes`; `Cada imagen debe indicar solo
  un id o solo un archivo`; `La imagen {id} figura más de una vez`; `El archivo
  {nombre} figura más de una vez`; `El archivo {nombre} no llegó en el pedido`; `El
  archivo {nombre} se envió pero no figura en imagenes`; `La imagen {id} no pertenece
  a esta novedad`; y los de cada archivo nuevo (`Solo se admiten imágenes JPEG o PNG`,
  `El contenido de la imagen no coincide con su formato`, `La imagen supera las
  dimensiones permitidas`, `La imagen no es válida`, `Cada imagen debe tener
  contenido`).
- `400 IMAGEN_INVALIDA` (`Cada imagen admite hasta 5 MB`) si un archivo supera 5 MB o
  se excede el límite multipart.
- `404 NO_ENCONTRADO` (`Anuncio no encontrado`) si la novedad no existe.
- `503 ALMACENAMIENTO_NO_DISPONIBLE` si Storage falla al subir una imagen nueva.
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
