package uy.edu.proyecto.backend.auth;

public record CuentaActivaPrimerIngresoSolicitada(
        Long idCuenta,
        String correo,
        String nombre
) {

    @Override
    public String toString() {
        return "CuentaActivaPrimerIngresoSolicitada[idCuenta=" + idCuenta + "]";
    }
}
