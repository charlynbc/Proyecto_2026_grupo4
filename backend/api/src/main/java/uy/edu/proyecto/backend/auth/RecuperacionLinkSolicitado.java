package uy.edu.proyecto.backend.auth;

public record RecuperacionLinkSolicitado(
        Long idCuenta,
        String correo,
        String nombre,
        String token,
        int validezHoras
) {

    // El token es un secreto de un solo uso: no debe salir en ningun log.
    @Override
    public String toString() {
        return "RecuperacionLinkSolicitado[idCuenta=" + idCuenta + "]";
    }
}
