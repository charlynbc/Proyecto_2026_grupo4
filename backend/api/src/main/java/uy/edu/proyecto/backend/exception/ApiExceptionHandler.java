package uy.edu.proyecto.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

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
