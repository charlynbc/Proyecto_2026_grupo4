package uy.edu.proyecto.backend.auth;

public record CompletarPrimerIngresoRequest(
        String token,
        String direccion,
        String telefono1,
        String telefono2,
        String password
) {
}
