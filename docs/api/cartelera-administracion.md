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
