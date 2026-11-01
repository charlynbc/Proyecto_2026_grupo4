package uy.edu.proyecto.backend.auth;

public record CambiarContrasenaRequest(
        String passwordActual,
        String passwordNueva
) {

    // Las contrasenas nunca se imprimen (RNF-12).
    @Override
    public String toString() {
        return "CambiarContrasenaRequest[]";
    }
}
