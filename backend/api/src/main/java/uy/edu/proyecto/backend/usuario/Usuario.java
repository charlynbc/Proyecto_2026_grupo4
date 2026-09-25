package uy.edu.proyecto.backend.usuario;

public record Usuario(
        Long id,
        String nombre,
        String cedula,
        String email,
        boolean emailVerificado,
        String rol
) {
}
