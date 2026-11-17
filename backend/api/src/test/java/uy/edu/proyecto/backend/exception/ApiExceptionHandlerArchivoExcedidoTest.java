package uy.edu.proyecto.backend.exception;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Un archivo que pasa el limite de multipart (5 MB) se rechaza antes de llegar al controlador. El codigo y el
 * mensaje dependen de la ruta: las imagenes de cartelera dicen IMAGEN_INVALIDA, con el mismo texto que la
 * validacion de tamano; la carga masiva de CSV sigue diciendo CSV_INVALIDO.
 */
class ApiExceptionHandlerArchivoExcedidoTest {
    private static final long CINCO_MB = 5L * 1024L * 1024L;

    private final ApiExceptionHandler handler = new ApiExceptionHandler();

    private org.springframework.http.ResponseEntity<ApiErrorResponse> excedido(String metodo, String ruta) {
        return handler.archivoExcedido(new MaxUploadSizeExceededException(CINCO_MB),
                new MockHttpServletRequest(metodo, ruta));
    }

    private void esImagenInvalida(String metodo, String ruta) {
        var respuesta = excedido(metodo, ruta);

        assertEquals(HttpStatus.BAD_REQUEST, respuesta.getStatusCode(), ruta);
        assertEquals("IMAGEN_INVALIDA", respuesta.getBody().code(), ruta);
        assertEquals("Cada imagen admite hasta 5 MB", respuesta.getBody().message(), ruta);
    }

    private void esCsvInvalido(String metodo, String ruta) {
        var respuesta = excedido(metodo, ruta);

        assertEquals(HttpStatus.BAD_REQUEST, respuesta.getStatusCode(), ruta);
        assertEquals("CSV_INVALIDO", respuesta.getBody().code(), ruta);
        assertEquals("El archivo supera el tamaño máximo permitido (1 MB)", respuesta.getBody().message(), ruta);
    }

    @Test
    void publicarUnaNovedadConUnaImagenGrandeDiceImagenInvalida() {
        esImagenInvalida("POST", "/api/anuncios");
    }

    @Test
    void editarUnaNovedadConUnaImagenGrandeDiceImagenInvalida() {
        esImagenInvalida("PUT", "/api/admin/anuncios/42");
    }

    @Test
    void elMismoMensajeDeLaValidacionDeTamanoDeLasImagenes() {
        // El texto que ya usa ValidadorImagen cuando un archivo supera 5 MB.
        assertEquals("Cada imagen admite hasta 5 MB", excedido("PUT", "/api/admin/anuncios/7").getBody().message());
    }

    @Test
    void laCargaMasivaDeCsvSigueDiciendoCsvInvalido() {
        for (String ruta : List.of(
                "/api/usuarios/importaciones/previsualizar",
                "/api/usuarios/importaciones/confirmar",
                "/api/especialidades/importaciones/previsualizar",
                "/api/especialidades/importaciones/confirmar",
                "/api/consultorios/importaciones/previsualizar",
                "/api/consultorios/importaciones/confirmar")) {
            esCsvInvalido("POST", ruta);
        }
    }

    @Test
    void unaRutaParecidaPeroDeOtraCosaNoEsDeCartelera() {
        esCsvInvalido("POST", "/api/anunciosfalsos");
        esCsvInvalido("POST", "/api/admin/anuncios-otros");
        esCsvInvalido("POST", "/api/anuncio");
    }

    @Test
    void otrasRutasSinCartelera() {
        esCsvInvalido("POST", "/api/admin/usuarios");
        esCsvInvalido("POST", "/api/auth/login");
    }

    @Test
    void elStatusEsSiempre400() {
        for (String ruta : List.of("/api/anuncios", "/api/admin/anuncios/1", "/api/usuarios/importaciones/confirmar")) {
            assertEquals(400, excedido("POST", ruta).getStatusCode().value());
        }
    }
}
