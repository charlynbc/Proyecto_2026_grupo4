package uy.edu.proyecto.backend.auth;

public record PrimerIngresoLinkSolicitado(
        Long idCuenta,
        String correo,
        String nombre,
        String token
) {
}
