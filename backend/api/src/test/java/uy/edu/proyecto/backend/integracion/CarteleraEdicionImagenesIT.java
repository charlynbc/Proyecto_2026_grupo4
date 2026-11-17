package uy.edu.proyecto.backend.integracion;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/** PUT /api/admin/anuncios/{id}, tramo de imagenes, por HTTP y PostgreSQL real; Storage es un doble. */
class CarteleraEdicionImagenesIT extends BaseIntegracionIT {
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l5sAAAAASUVORK5CYII=");

    @MockitoBean
    AlmacenImagenes almacen;

    record Archivo(String tipo, byte[] bytes) { }

    /** Una novedad sin posicion en el carrusel: la posicion es unica, asi que dos novedades no pueden compartirla. */
    private long novedad(String texto, String... referencias) {
        return novedad(null, texto, referencias);
    }

    private long novedadEnCarrusel(int posicion, String texto, String... referencias) {
        return novedad(posicion, texto, referencias);
    }

    private long novedad(Integer posicion, String texto, String... referencias) {
        long id = jdbc.queryForObject("""
                INSERT INTO anuncio (id_administrador, titulo, resumen, texto, vigente_desde, vigente_hasta,
                                     posicion_carrusel)
                VALUES (?, 'Titulo viejo', 'Resumen viejo', ?, '2026-01-01T00:00:00Z'::timestamptz,
                        '2099-01-01T00:00:00Z'::timestamptz, ?) RETURNING id_anuncio
                """, Long.class, idAdmin, texto, posicion);
        for (int i = 0; i < referencias.length; i++) {
            jdbc.update("INSERT INTO imagen_anuncio (id_anuncio, referencia_archivo, orden) VALUES (?, ?, ?)",
                    id, referencias[i], i);
        }
        return id;
    }

    /** Los ids de imagen de la novedad, en su orden actual. */
    private List<Long> ids(long anuncio) {
        return jdbc.queryForList("SELECT id_imagen FROM imagen_anuncio WHERE id_anuncio = ? ORDER BY orden, id_imagen",
                Long.class, anuncio);
    }

    private List<String> referencias(long anuncio) {
        return jdbc.queryForList("SELECT referencia_archivo FROM imagen_anuncio WHERE id_anuncio = ? "
                + "ORDER BY orden, id_imagen", String.class, anuncio);
    }

    private List<Integer> ordenes(long anuncio) {
        return jdbc.queryForList("SELECT orden FROM imagen_anuncio WHERE id_anuncio = ? ORDER BY orden, id_imagen",
                Integer.class, anuncio);
    }

    private List<String> pendientes() {
        return jdbc.queryForList("SELECT referencia_archivo FROM anuncio_archivo_pendiente_borrado "
                + "ORDER BY referencia_archivo", String.class);
    }

    private static String datos(String texto, String imagenes) {
        return "{\"titulo\":\"Titulo nuevo\",\"texto\":" + (texto == null ? "null" : "\"" + texto + "\"")
                + (imagenes == null ? "" : ",\"imagenes\":" + imagenes) + "}";
    }

    private static String id(long id) { return "{\"id\":" + id + "}"; }

    private static String archivo(String nombre) { return "{\"archivo\":\"" + nombre + "\"}"; }

    private static String lista(String... entradas) { return "[" + String.join(",", entradas) + "]"; }

    private Respuesta editar(String bearer, long id, String datos, Map<String, Archivo> archivos) throws Exception {
        String boundary = "ProyectoImagenes" + System.nanoTime();
        var salida = new ByteArrayOutputStream();
        parte(salida, boundary, "datos", "application/json", datos.getBytes(StandardCharsets.UTF_8));
        for (var archivo : archivos.entrySet()) {
            parte(salida, boundary, archivo.getKey(), archivo.getValue().tipo(), archivo.getValue().bytes());
        }
        salida.writeBytes(("--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));
        var peticion = HttpRequest.newBuilder(URI.create("http://localhost:" + puerto + "/api/admin/anuncios/" + id))
                .timeout(Duration.ofSeconds(30))
                .header("Content-Type", "multipart/form-data; boundary=" + boundary);
        if (bearer != null) peticion.header("Authorization", "Bearer " + bearer);
        var respuesta = http.send(peticion.PUT(HttpRequest.BodyPublishers.ofByteArray(salida.toByteArray())).build(),
                HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        return new Respuesta(respuesta.statusCode(), respuesta.body(), respuesta.headers());
    }

    private Respuesta editar(long id, String datos, Map<String, Archivo> archivos) throws Exception {
        return editar(tokenEmpleado(ciAdmin), id, datos, archivos);
    }

    private static void parte(ByteArrayOutputStream salida, String boundary, String nombre, String tipo, byte[] bytes) {
        salida.writeBytes(("--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"" + nombre + "\"; filename=\"" + nombre + "\"\r\n"
                + "Content-Type: " + tipo + "\r\n\r\n").getBytes(StandardCharsets.UTF_8));
        salida.writeBytes(bytes);
        salida.writeBytes("\r\n".getBytes(StandardCharsets.UTF_8));
    }

    private static Map<String, Archivo> pngs(String... nombres) {
        var mapa = new LinkedHashMap<String, Archivo>();
        for (String nombre : nombres) mapa.put(nombre, new Archivo("image/png", PNG));
        return mapa;
    }

    private void sinCambios(long id, List<String> referencias) {
        assertEquals(referencias, referencias(id));
        assertEquals("Titulo viejo", jdbc.queryForObject("SELECT titulo FROM anuncio WHERE id_anuncio = ?",
                String.class, id));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void agregaUnaImagenNuevaAlFinal() throws Exception {
        long id = novedad("Texto", "a.png");
        long existente = ids(id).getFirst();

        Respuesta r = editar(id, datos("Texto", lista(id(existente), archivo("nueva1"))), pngs("nueva1"));

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(2, ids(id).size());
        assertEquals(existente, ids(id).getFirst());
        assertEquals(List.of(0, 1), ordenes(id));
        verify(almacen).guardar(anyString(), eq(PNG), eq("image/png"));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void quitaUnaImagenYLaEncolaParaBorrar() throws Exception {
        long id = novedad("Texto", "a.png", "b.png", "c.png");
        var antes = ids(id);

        Respuesta r = editar(id, datos("Texto", lista(id(antes.get(0)), id(antes.get(2)))), Map.of());

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(List.of(antes.get(0), antes.get(2)), ids(id));
        assertEquals(List.of(0, 1), ordenes(id));
        assertEquals(List.of("b.png"), pendientes());
        verifyNoInteractions(almacen);
    }

    @Test
    void reordenarCambiaLaPortada() throws Exception {
        long id = novedad("Texto", "a.png", "b.png", "c.png");
        var antes = ids(id);

        Respuesta r = editar(id, datos("Texto", lista(id(antes.get(2)), id(antes.get(0)), id(antes.get(1)))), Map.of());

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(List.of(antes.get(2), antes.get(0), antes.get(1)), ids(id));
        assertEquals(List.of("c.png", "a.png", "b.png"), referencias(id));
        assertEquals(List.of(0, 1, 2), ordenes(id));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void mezclaDelEjemploDelContrato() throws Exception {
        long id = novedad("Texto", "a.png", "b.png", "c.png");
        var antes = ids(id);

        Respuesta r = editar(id, datos("Texto", lista(id(antes.get(0)), archivo("nueva1"), id(antes.get(2)))),
                pngs("nueva1"));

        assertEquals(204, r.estado(), r.cuerpo());
        var despues = ids(id);
        assertEquals(3, despues.size());
        assertEquals(antes.get(0), despues.get(0));
        assertEquals(antes.get(2), despues.get(2));
        assertEquals(List.of(0, 1, 2), ordenes(id));
        assertEquals(List.of("b.png"), pendientes());
    }

    @Test
    void unaListaVaciaEliminaTodasSiQuedaTexto() throws Exception {
        long id = novedad("Texto", "a.png", "b.png");

        Respuesta r = editar(id, datos("Texto", "[]"), Map.of());

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(0, ids(id).size());
        assertEquals(List.of("a.png", "b.png"), pendientes());
    }

    @Test
    void unaListaVaciaSinTextoEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png");

        Respuesta r = editar(id, datos(null, "[]"), Map.of());

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        sinCambios(id, List.of("a.png"));
    }

    @Test
    void sinImagenesEnDatosNoSeTocanLasImagenes() throws Exception {
        long id = novedad("Texto", "a.png", "b.png");

        Respuesta r = editar(id, datos("Texto nuevo", null), Map.of());

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(List.of("a.png", "b.png"), referencias(id));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void masDeCincoImagenesEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png", "b.png", "c.png");
        var existentes = ids(id);

        Respuesta r = editar(id, datos("Texto", lista(id(existentes.get(0)), id(existentes.get(1)), id(existentes.get(2)),
                archivo("n1"), archivo("n2"), archivo("n3"))), pngs("n1", "n2", "n3"));

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        sinCambios(id, List.of("a.png", "b.png", "c.png"));
        verifyNoInteractions(almacen);
    }

    @Test
    void cincoEnTotalSeAceptan() throws Exception {
        long id = novedad("Texto", "a.png", "b.png", "c.png");
        var existentes = ids(id);

        Respuesta r = editar(id, datos("Texto", lista(id(existentes.get(0)), id(existentes.get(1)), id(existentes.get(2)),
                archivo("n1"), archivo("n2"))), pngs("n1", "n2"));

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals(5, ids(id).size());
    }

    @Test
    void unArchivoQueNoEsJpegNiPngEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png");

        Respuesta r = editar(id, datos("Texto", lista(archivo("nueva1"))),
                Map.of("nueva1", new Archivo("image/gif", PNG)));

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        sinCambios(id, List.of("a.png"));
        verifyNoInteractions(almacen);
    }

    @Test
    void unArchivoDeMasDeCincoMegabytesEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png");

        Respuesta r = editar(id, datos("Texto", lista(archivo("nueva1"))),
                Map.of("nueva1", new Archivo("image/png", new byte[5 * 1024 * 1024 + 1])));

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("IMAGEN_INVALIDA", r.codigo());
        assertEquals("Cada imagen admite hasta 5 MB", r.json().path("message").asString());
        sinCambios(id, List.of("a.png"));
        verifyNoInteractions(almacen);
    }

    @Test
    void unArchivoDeMasDeSeisMilPixelesEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png");
        var salida = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(6001, 1, BufferedImage.TYPE_INT_RGB), "png", salida);

        Respuesta r = editar(id, datos("Texto", lista(archivo("nueva1"))),
                Map.of("nueva1", new Archivo("image/png", salida.toByteArray())));

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        sinCambios(id, List.of("a.png"));
        verifyNoInteractions(almacen);
    }

    @Test
    void unaImagenDeOtraNovedadEs400YNoCambiaNada() throws Exception {
        long id = novedad("Texto", "a.png");
        long otra = novedad("Otra", "z.png");
        long ajena = ids(otra).getFirst();

        Respuesta r = editar(id, datos("Texto", lista(id(ids(id).getFirst()), id(ajena))), Map.of());

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        assertEquals(List.of("a.png"), referencias(id));
        assertEquals(List.of("z.png"), referencias(otra));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void idsDuplicadosNombresDuplicadosYPartesSobrantesOFaltantesSon400() throws Exception {
        long id = novedad("Texto", "a.png");
        long existente = ids(id).getFirst();

        assertEquals(400, editar(id, datos("Texto", lista(id(existente), id(existente))), Map.of()).estado());
        assertEquals(400, editar(id, datos("Texto", lista(archivo("n1"), archivo("n1"))), pngs("n1")).estado());
        assertEquals(400, editar(id, datos("Texto", lista(archivo("n1"))), Map.of()).estado());
        assertEquals(400, editar(id, datos("Texto", lista(id(existente))), pngs("sobra")).estado());
        sinCambios(id, List.of("a.png"));
        verifyNoInteractions(almacen);
    }

    @Test
    void siFallaStorageResponde503SinCambiosParcialesNiDeTextoNiDeImagenes() throws Exception {
        long id = novedad("Texto", "a.png", "b.png");
        var existentes = ids(id);
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ALMACENAMIENTO_NO_DISPONIBLE",
                "No se pudo acceder a las imágenes")).when(almacen).guardar(anyString(), any(), anyString());

        Respuesta r = editar(id, datos("Texto nuevo", lista(id(existentes.get(1)), archivo("nueva1"))), pngs("nueva1"));

        assertEquals(503, r.estado(), r.cuerpo());
        assertEquals("ALMACENAMIENTO_NO_DISPONIBLE", r.codigo());
        assertEquals(existentes, ids(id));
        assertEquals(List.of("a.png", "b.png"), referencias(id));
        assertEquals("Texto", jdbc.queryForObject("SELECT texto FROM anuncio WHERE id_anuncio = ?", String.class, id));
        assertEquals("Titulo viejo", jdbc.queryForObject("SELECT titulo FROM anuncio WHERE id_anuncio = ?",
                String.class, id));
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void laEdicionDeImagenesNoCambiaVigenciaNiPosicion() throws Exception {
        long id = novedadEnCarrusel(3, "Texto", "a.png");
        var antes = jdbc.queryForMap("SELECT vigente_desde, vigente_hasta, posicion_carrusel, publicado_en "
                + "FROM anuncio WHERE id_anuncio = ?", id);

        Respuesta r = editar(id, datos("Texto", lista(archivo("nueva1"))), pngs("nueva1"));

        assertEquals(204, r.estado(), r.cuerpo());
        var despues = jdbc.queryForMap("SELECT vigente_desde, vigente_hasta, posicion_carrusel, publicado_en "
                + "FROM anuncio WHERE id_anuncio = ?", id);
        assertEquals(antes, despues);
        assertEquals(3, despues.get("posicion_carrusel"));
        assertTrue(pendientes().contains("a.png"));
    }

    @Test
    void unaNovedadInexistenteEs404ConImagenesYSinSubirNada() throws Exception {
        Respuesta r = editar(999999, datos("Texto", lista(archivo("nueva1"))), pngs("nueva1"));

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("NO_ENCONTRADO", r.codigo());
        verify(almacen, never()).guardar(anyString(), any(), anyString());
    }
}
