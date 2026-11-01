package uy.edu.proyecto.backend.usuario;

public record CambioCorreoSolicitado(
        Long idCuenta,
        String correoNuevo,
        String nombre,
        String token,
        int validezHoras
) {

    // El token es un secreto de un solo uso: no debe salir en ningun log.
    @Override
    public String toString() {
        return "CambioCorreoSolicitado[idCuenta=" + idCuenta + "]";
    }
}
