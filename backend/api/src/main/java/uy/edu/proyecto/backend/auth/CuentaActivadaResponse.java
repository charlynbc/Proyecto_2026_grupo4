package uy.edu.proyecto.backend.auth;

public record CuentaActivadaResponse(
        Long id,
        String ci,
        String nombre,
        String apellido,
        String rol,
        String estado,
        boolean activada
) {
}
