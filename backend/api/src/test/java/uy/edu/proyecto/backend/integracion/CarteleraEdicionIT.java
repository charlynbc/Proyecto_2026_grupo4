package uy.edu.proyecto.backend.integracion;

import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.verifyNoInteractions;

/** PUT /api/admin/anuncios/{id}, tramo de texto, por HTTP y PostgreSQL real. */
class CarteleraEdicionIT extends BaseIntegracionIT {
    @MockitoBean
    AlmacenImagenes almacen;

    private static final String DESDE = "2026-01-01T00:00:00Z";
    private static final String HASTA = "2099-01-01T00:00:00Z";

    private long novedad(String titulo, String resumen, String texto, Integer posicion) {
        return jdbc.queryForObject("""
                INSERT INTO anuncio (id_administrador, titulo, resumen, texto, vigente_desde, vigente_hasta,
                                     posicion_carrusel)
                VALUES (?, ?, ?, ?, ?::timestamptz, ?::timestamptz, ?) RETURNING id_anuncio
                """, Long.class, idAdmin, titulo, resumen, texto, DESDE, HASTA, posicion);
    }

    private void imagen(long anuncio, String referencia, int orden) {
        jdbc.update("INSERT INTO imagen_anuncio (id_anuncio, referencia_archivo, orden) VALUES (?, ?, ?)",
                anuncio, referencia, orden);
    }

    private Map<String, Object> fila(long id) {
        return jdbc.queryForMap("""
                SELECT titulo, resumen, texto, publicado_en, id_administrador, vigente_desde, vigente_hasta,
                       posicion_carrusel FROM anuncio WHERE id_anuncio = ?
                """, id);
    }

    private Respuesta editar(String bearer, long id, String datos, String... archivosExtra) throws Exception {
        String boundary = "ProyectoEdicion" + System.nanoTime();
        var salida = new ByteArrayOutputStream();
        if (datos != null) parte(salida, boundary, "datos", "datos.json", "application/json",
                datos.getBytes(StandardCharsets.UTF_8));
        for (String nombre : archivosExtra) {
            parte(salida, boundary, nombre, nombre + ".png", "image/png", new byte[] {1, 2, 3});
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

    private static void parte(ByteArrayOutputStream salida, String boundary, String nombre,
                              String archivo, String tipo, byte[] bytes) {
        salida.writeBytes(("--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"" + nombre + "\"; filename=\""
                + archivo + "\"\r\nContent-Type: " + tipo + "\r\n\r\n").getBytes(StandardCharsets.UTF_8));
        salida.writeBytes(bytes);
        salida.writeBytes("\r\n".getBytes(StandardCharsets.UTF_8));
    }

    private static String datos(String titulo, String resumen, String texto) {
        return "{\"titulo\":" + json(titulo) + ",\"resumen\":" + json(resumen) + ",\"texto\":" + json(texto) + "}";
    }

    private static String json(String valor) {
        return valor == null ? "null" : "\"" + valor.replace("\"", "\\\"") + "\"";
    }

    @Test
    void editaSoloElTextoYResponde204() throws Exception {
        long id = novedad("Titulo viejo", "Resumen viejo", "Texto viejo", null);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos(" Titulo nuevo ", "Resumen nuevo", "**Texto** nuevo"));

        assertEquals(204, r.estado(), r.cuerpo());
        var fila = fila(id);
        assertEquals("Titulo nuevo", fila.get("titulo"));
        assertEquals("Resumen nuevo", fila.get("resumen"));
        assertEquals("**Texto** nuevo", fila.get("texto"));
        verifyNoInteractions(almacen);
    }

    @Test
    void laEdicionNoCambiaVigenciaPosicionNiAutorNiFechaDePublicacion() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", 2);
        var antes = fila(id);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos("Titulo nuevo", null, "Texto nuevo"));

        assertEquals(204, r.estado(), r.cuerpo());
        var despues = fila(id);
        assertEquals(antes.get("publicado_en"), despues.get("publicado_en"));
        assertEquals(antes.get("id_administrador"), despues.get("id_administrador"));
        assertEquals(antes.get("vigente_desde"), despues.get("vigente_desde"));
        assertEquals(antes.get("vigente_hasta"), despues.get("vigente_hasta"));
        assertEquals(2, despues.get("posicion_carrusel"));
    }

    @Test
    void validaElTituloYElResumenSinCambiarNada() throws Exception {
        long id = novedad("Titulo viejo", "Resumen viejo", "Texto viejo", null);
        String admin = tokenEmpleado(ciAdmin);

        for (String invalido : new String[] {
                datos("", null, "Texto"),
                datos("a".repeat(161), null, "Texto"),
                datos("Titulo", "r".repeat(301), "Texto")}) {
            Respuesta r = editar(admin, id, invalido);
            assertEquals(400, r.estado(), r.cuerpo());
            assertEquals("VALIDACION", r.codigo());
        }
        var fila = fila(id);
        assertEquals("Titulo viejo", fila.get("titulo"));
        assertEquals("Resumen viejo", fila.get("resumen"));
        assertEquals("Texto viejo", fila.get("texto"));
    }

    @Test
    void aceptaElLimiteDeLosLargos() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos("a".repeat(160), "r".repeat(300), "Texto"));

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals("a".repeat(160), fila(id).get("titulo"));
        assertEquals("r".repeat(300), fila(id).get("resumen"));
    }

    @Test
    void sinTextoNiImagenesNoSePuedeGuardar() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos("Titulo nuevo", null, "   "));

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        assertEquals("Titulo viejo", fila(id).get("titulo"));
        assertEquals("Texto viejo", fila(id).get("texto"));
    }

    @Test
    void sinTextoPeroConImagenesSeGuarda() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);
        imagen(id, "uno.png", 0);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos("Titulo nuevo", null, null));

        assertEquals(204, r.estado(), r.cuerpo());
        assertEquals("Titulo nuevo", fila(id).get("titulo"));
        assertNull(fila(id).get("texto"));
        assertEquals(1, contar("imagen_anuncio"));
    }

    @Test
    void archivosSinImagenesEnDatosEs400YNoCambiaNada() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, datos("Titulo nuevo", null, "Texto"), "nueva1");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        assertEquals("Titulo viejo", fila(id).get("titulo"));
        verifyNoInteractions(almacen);
    }

    @Test
    void sinLaParteDatosEs400() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);

        Respuesta r = editar(tokenEmpleado(ciAdmin), id, null, "nueva1");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }

    @Test
    void unaNovedadInexistenteEs404() throws Exception {
        Respuesta r = editar(tokenEmpleado(ciAdmin), 999999, datos("Titulo", null, "Texto"));

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("NO_ENCONTRADO", r.codigo());
    }

    @Test
    void sinTokenRecibe401YLosDemasRolesRecibe403() throws Exception {
        long id = novedad("Titulo viejo", null, "Texto viejo", null);
        String cuerpo = datos("Titulo nuevo", null, "Texto");

        assertEquals(401, editar(null, id, cuerpo).estado());
        assertEquals(403, editar(tokenSocio(ciSocio1), id, cuerpo).estado());
        assertEquals(403, editar(tokenEmpleado(ciMedico), id, cuerpo).estado());
        assertEquals(403, editar(tokenEmpleado(ciFuncionario), id, cuerpo).estado());
        assertEquals("Titulo viejo", fila(id).get("titulo"));
    }
}
