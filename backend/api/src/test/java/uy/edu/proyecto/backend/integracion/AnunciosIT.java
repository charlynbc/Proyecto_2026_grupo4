package uy.edu.proyecto.backend.integracion;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** RF-28 y RF-07 por HTTP y PostgreSQL real; Storage se sustituye por un doble. */
class AnunciosIT extends BaseIntegracionIT {
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l5sAAAAASUVORK5CYII=");

    @MockitoBean
    AlmacenImagenes almacen;

    @BeforeEach
    void enlacesTemporales() {
        when(almacen.enlaceTemporal(anyString()))
                .thenAnswer(llamada -> "https://imagenes.test/" + llamada.getArgument(0));
    }

    @Test
    void administradorPublicaYSocioConsultaPortadaYDetalle() throws Exception {
        String admin = tokenEmpleado(ciAdmin);
        String socio = tokenSocio(ciSocio1);

        Respuesta publicada = publicar(admin, true);
        assertEquals(201, publicada.estado(), publicada.cuerpo());
        long id = publicada.json().path("id").asLong();
        assertEquals("/api/anuncios/" + id,
                publicada.cabeceras().firstValue("location").orElse(null));
        assertEquals(2, publicada.json().path("imagenes").size());
        assertEquals(0, publicada.json().path("imagenes").get(0).path("orden").asInt());
        assertEquals(1, publicada.json().path("imagenes").get(1).path("orden").asInt());

        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM anuncio WHERE id_anuncio = ? AND id_administrador = ? "
                        + "AND titulo = ? AND texto = ?", Integer.class,
                id, idAdmin, "Campaña de vacunación", "**Comienza** el lunes"));
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM imagen_anuncio WHERE id_anuncio = ?", Integer.class, id));

        Respuesta lista = get("/api/anuncios?size=5", socio);
        assertEquals(200, lista.estado(), lista.cuerpo());
        assertEquals(1, lista.json().path("total").asInt());
        assertEquals(id, lista.json().path("items").get(0).path("id").asLong());
        assertTrue(lista.json().path("items").get(0).path("imagenPortada")
                .path("url").asString().startsWith("https://imagenes.test/"));

        Respuesta detalle = get("/api/anuncios/" + id, socio);
        assertEquals(200, detalle.estado(), detalle.cuerpo());
        assertEquals("**Comienza** el lunes", detalle.json().path("texto").asString());
        assertNotNull(detalle.json().path("publicadoEn").asString());
        assertEquals(2, detalle.json().path("imagenes").size());
    }

    @Test
    void rechazaAnonimosYSociosAlPublicarSinGuardarFilas() throws Exception {
        assertEquals(401, publicar(null, true).estado());
        assertEquals(403, publicar(tokenSocio(ciSocio1), true).estado());
        assertEquals(0, contar("anuncio"));
    }

    @Test
    void exigeImagenYNoGuardaPublicacionIncompleta() throws Exception {
        Respuesta respuesta = publicar(tokenEmpleado(ciAdmin), false);

        assertEquals(400, respuesta.estado(), respuesta.cuerpo());
        assertEquals("VALIDACION", respuesta.codigo());
        assertEquals(0, contar("anuncio"));
        verifyNoInteractions(almacen);
    }

    private Respuesta publicar(String bearer, boolean conImagen) throws IOException, InterruptedException {
        String boundary = "ProyectoAnuncio" + System.nanoTime();
        var salida = new ByteArrayOutputStream();
        parte(salida, boundary, "datos", "datos.json", "application/json",
                "{\"titulo\":\"Campaña de vacunación\",\"texto\":\"**Comienza** el lunes\"}"
                        .getBytes(StandardCharsets.UTF_8));
        if (conImagen) {
            parte(salida, boundary, "imagenes", "primera.png", "image/png", PNG);
            parte(salida, boundary, "imagenes", "segunda.png", "image/png", PNG);
        }
        salida.writeBytes(("--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));
        var peticion = HttpRequest.newBuilder(URI.create("http://localhost:" + puerto + "/api/anuncios"))
                .timeout(Duration.ofSeconds(30))
                .header("Content-Type", "multipart/form-data; boundary=" + boundary);
        if (bearer != null) peticion.header("Authorization", "Bearer " + bearer);
        var respuesta = http.send(peticion.POST(HttpRequest.BodyPublishers.ofByteArray(salida.toByteArray()))
                .build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        return new Respuesta(respuesta.statusCode(), respuesta.body(), respuesta.headers());
    }

    private static void parte(ByteArrayOutputStream salida, String boundary, String nombre,
                              String archivo, String tipo, byte[] bytes) {
        salida.writeBytes(("--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"" + nombre + "\"; filename=\""
                + archivo + "\"\r\nContent-Type: " + tipo + "\r\n\r\n")
                .getBytes(StandardCharsets.UTF_8));
        salida.writeBytes(bytes);
        salida.writeBytes("\r\n".getBytes(StandardCharsets.UTF_8));
    }
}
