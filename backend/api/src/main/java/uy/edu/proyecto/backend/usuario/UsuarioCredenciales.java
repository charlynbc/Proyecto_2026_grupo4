package uy.edu.proyecto.backend.usuario;

public record UsuarioCredenciales(
        Long id,
        String nombre,
        String cedula,
        String passwordHash,
        boolean emailVerificado,
        String rol
) {
}
