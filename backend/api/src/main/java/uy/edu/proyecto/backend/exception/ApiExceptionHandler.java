package uy.edu.proyecto.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import uy.edu.proyecto.backend.anuncio.ErroresImagen;
import jakarta.servlet.http.HttpServletRequest;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiErrorResponse> archivoExcedido(
            MaxUploadSizeExceededException exception,
            HttpServletRequest request
    ) {
        boolean anuncio = esRutaDeAnuncios(request.getRequestURI());
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(
                        new ApiErrorResponse(
                                anuncio ? ErroresImagen.CODIGO : "CSV_INVALIDO",
                                anuncio ? ErroresImagen.TAMANO
                                        : "El archivo supera el tamaño máximo permitido (1 MB)"
                        )
                );
    }

    /**
     * El limite de multipart corta el pedido antes de que haya controlador, asi que la excepcion no dice a que
     * endpoint iba: se decide por la ruta (la publicacion y la edicion de novedades), por segmentos completos.
     */
    private static boolean esRutaDeAnuncios(String ruta) {
        return coincide(ruta, "/api/anuncios") || coincide(ruta, "/api/admin/anuncios");
    }

    private static boolean coincide(String ruta, String base) {
        return ruta.equals(base) || ruta.startsWith(base + "/");
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiErrorResponse> manejar(
            ApiException exception
    ) {

        return ResponseEntity
                .status(exception.getStatus())
                .body(
                        new ApiErrorResponse(
                                exception.getCode(),
                                exception.getMessage()
                        )
                );
    }


    @ExceptionHandler(
            MethodArgumentNotValidException.class
    )
    public ResponseEntity<ApiErrorResponse> validacion(
            MethodArgumentNotValidException exception
    ) {

        String mensaje =
                exception
                        .getBindingResult()
                        .getFieldErrors()
                        .stream()
                        .findFirst()
                        .map(error ->
                                error.getField()
                                + ": "
                                + error.getDefaultMessage()
                        )
                        .orElse(
                                "Solicitud invalida"
                        );

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(
                        new ApiErrorResponse(
                                "VALIDACION_ERROR",
                                mensaje
                        )
                );
    }
}
