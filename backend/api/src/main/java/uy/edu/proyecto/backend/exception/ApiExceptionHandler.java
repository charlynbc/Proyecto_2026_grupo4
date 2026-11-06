package uy.edu.proyecto.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import jakarta.servlet.http.HttpServletRequest;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiErrorResponse> archivoExcedido(
            MaxUploadSizeExceededException exception,
            HttpServletRequest request
    ) {
        boolean anuncio = request.getRequestURI().startsWith("/api/anuncios");
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(
                        new ApiErrorResponse(
                                anuncio ? "IMAGEN_INVALIDA" : "CSV_INVALIDO",
                                anuncio ? "Las imágenes superan el tamaño máximo permitido"
                                        : "El archivo supera el tamaño máximo permitido (1 MB)"
                        )
                );
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
