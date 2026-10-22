package uy.edu.proyecto.backend.auth;

public record PrimerIngresoLinkSolicitado(
        Long idCuenta,
        String correo,
        String nombre,
        String token
) {

    // El token es un secreto de un solo uso: no debe salir en ningun log.
    @Override
    public String toString() {
        return "PrimerIngresoLinkSolicitado[idCuenta=" + idCuenta + "]";
    }
}
