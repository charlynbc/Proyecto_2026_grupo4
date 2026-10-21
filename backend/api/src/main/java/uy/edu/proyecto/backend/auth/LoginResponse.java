package uy.edu.proyecto.backend.auth;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record LoginResponse(
        String token,
        String tokenType,
        long expiresIn,
        String role,
        String nombre,
        String apellido
) {
}
