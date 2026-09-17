package uy.edu.proyecto.backend.auth;

public record LoginResponse(
        String token,
        String tokenType,
        long expiresIn,
        String role
) {
}
