package uy.edu.proyecto.backend.usuario;

public record CuentaCreadaResponse(
        Long id,
        String ci,
        String nombre,
        String apellido,
        String rol,
        String estado,
        boolean activada
) {
}
