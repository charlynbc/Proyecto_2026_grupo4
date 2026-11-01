package uy.edu.proyecto.backend.usuario;

public record ConfirmarCambioCorreoRequest(String token) {

    // El token es un secreto de un solo uso: no debe salir en ningun log.
    @Override
    public String toString() {
        return "ConfirmarCambioCorreoRequest[]";
    }
}
