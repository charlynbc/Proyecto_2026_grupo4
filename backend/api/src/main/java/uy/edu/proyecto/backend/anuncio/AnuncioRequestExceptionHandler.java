package uy.edu.proyecto.backend.anuncio;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import uy.edu.proyecto.backend.exception.ApiErrorResponse;

@RestControllerAdvice(assignableTypes = AnuncioController.class)
public class AnuncioRequestExceptionHandler {
    @ExceptionHandler({MissingServletRequestPartException.class,
            HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    public ResponseEntity<ApiErrorResponse> solicitudInvalida(Exception error) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new ApiErrorResponse("VALIDACION", "Faltan datos o la solicitud tiene un formato inválido"));
    }
}
