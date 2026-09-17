package uy.edu.proyecto.backend.auth;

public record AuthResult(
        LoginResponse response,
        String refreshToken
) {
}
