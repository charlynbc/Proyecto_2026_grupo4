package uy.edu.proyecto.backend.auth;

public record CompletarRecuperacionRequest(
        String token,
        String password
) {

    // El token y la contrasena son secretos: nunca se imprimen (RNF-12).
    @Override
    public String toString() {
        return "CompletarRecuperacionRequest[]";
    }
}
