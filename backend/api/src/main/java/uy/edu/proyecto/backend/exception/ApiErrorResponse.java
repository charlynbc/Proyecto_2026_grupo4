package uy.edu.proyecto.backend.exception;

public record ApiErrorResponse(
        String code,
        String message
) {
}
