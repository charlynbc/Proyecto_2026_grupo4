package uy.edu.proyecto.backend.anuncio;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.util.unit.DataSize;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Los limites de multipart tienen que dejar pasar lo que la cartelera admite (hasta 5 imagenes de 5 MB mas el JSON
 * de datos) y a la vez cortar antes de que un pedido enorme llegue a memoria. Si un limite queda por debajo, el
 * servidor rechaza antes de validar y la respuesta no es la de la validacion.
 */
class LimitesMultipartImagenesTest {
    private static Properties propiedades() throws IOException {
        var propiedades = new Properties();
        try (InputStream entrada = LimitesMultipartImagenesTest.class.getResourceAsStream("/application.properties")) {
            propiedades.load(entrada);
        }
        return propiedades;
    }

    private static DataSize tamano(String clave) throws IOException {
        return DataSize.parse(propiedades().getProperty(clave).trim());
    }

    @Test
    void elLimiteDeUnArchivoEsExactamenteLoQueAdmiteUnaImagen() throws IOException {
        // Escrito a mano: 5 MB por imagen, 5 * 1024 * 1024 bytes.
        assertEquals(5L * 1024L * 1024L, ValidadorImagen.MAX_BYTES);
        assertEquals(5L * 1024L * 1024L, tamano("spring.servlet.multipart.max-file-size").toBytes());
    }

    @Test
    void elLimiteDelPedidoAdmiteCincoImagenesDeCincoMegasYElJson() throws IOException {
        long cincoImagenes = 5L * 5L * 1024L * 1024L;
        long margenParaDatos = 1024L * 1024L;

        assertTrue(tamano("spring.servlet.multipart.max-request-size").toBytes() >= cincoImagenes + margenParaDatos);
    }

    @Test
    void elLimiteDelPedidoNoEsIlimitado() throws IOException {
        long treintaMegas = 30L * 1024L * 1024L;

        assertEquals(treintaMegas, tamano("spring.servlet.multipart.max-request-size").toBytes());
    }

    @Test
    void ningunLimiteQuedaSinDefinir() throws IOException {
        assertTrue(propiedades().containsKey("spring.servlet.multipart.max-file-size"));
        assertTrue(propiedades().containsKey("spring.servlet.multipart.max-request-size"));
    }
}
