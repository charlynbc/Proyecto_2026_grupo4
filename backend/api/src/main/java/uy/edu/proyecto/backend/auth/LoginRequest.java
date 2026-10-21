package uy.edu.proyecto.backend.auth;

public record LoginRequest(
        String ci,
        String password,
        String acceso,
        String plataforma,
        String cedula,
        String clave
) {
}
