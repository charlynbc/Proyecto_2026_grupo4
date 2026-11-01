package uy.edu.proyecto.backend.auth;

/**
 * RF-05: la CI existe pero la cuenta todavia no completo el primer ingreso;
 * el correo le indica que debe usar "Es mi primera vez" en lugar de un
 * enlace de recuperacion.
 */
public record CuentaPendienteRecuperacionSolicitada(
        Long idCuenta,
        String correo,
        String nombre
) {
}
