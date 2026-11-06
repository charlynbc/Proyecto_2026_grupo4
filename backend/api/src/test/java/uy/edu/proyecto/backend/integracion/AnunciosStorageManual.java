package uy.edu.proyecto.backend.integracion;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;
import uy.edu.proyecto.backend.anuncio.AnuncioDTO;
import uy.edu.proyecto.backend.anuncio.AnuncioService;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Prueba manual con Storage real; se ejecuta solo con -Dtest=AnunciosStorageManual. */
class AnunciosStorageManual extends BaseIntegracionIT {
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l5sAAAAASUVORK5CYII=");

    @Autowired AnuncioService anuncios;
    @Autowired AlmacenImagenes almacen;

    @Test
    void publicaEnPostgresSubeImagenYAbreEnlaceTemporal() throws Exception {
        String referencia = null;
        try {
            var imagen = new MockMultipartFile("imagenes", "prueba.png", "image/png", PNG);
            var detalle = anuncios.publicar(idAdmin,
                    new AnuncioDTO.Datos("Prueba de novedades", null, "**Texto de prueba**"),
                    List.of(imagen));
            assertEquals(1, detalle.imagenes().size());
            assertEquals(1, contar("anuncio"));
            referencia = jdbc.queryForObject("SELECT referencia_archivo FROM imagen_anuncio "
                    + "WHERE id_anuncio = ?", String.class, detalle.id());

            var respuesta = http.send(HttpRequest.newBuilder(URI.create(detalle.imagenes().getFirst().url()))
                    .GET().build(), HttpResponse.BodyHandlers.ofByteArray());
            assertEquals(200, respuesta.statusCode());
            assertArrayEquals(PNG, respuesta.body());
            assertTrue(detalle.imagenes().getFirst().url().contains("/object/sign/anuncios/"));
        } finally {
            if (referencia != null) almacen.borrar(referencia);
        }
    }
}
