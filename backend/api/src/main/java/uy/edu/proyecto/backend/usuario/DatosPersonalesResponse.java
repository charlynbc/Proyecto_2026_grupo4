package uy.edu.proyecto.backend.usuario;

/**
 * Datos de la cuenta del usuario autenticado (RF-06). Los campos protegidos
 * (ci, nombre, apellido, rol) se muestran pero solo los corrige el
 * Administrador (RF-38). correoPendiente es el correo nuevo a la espera de
 * confirmacion desde el enlace enviado, o null si no hay cambio pendiente.
 */
public record DatosPersonalesResponse(
        String ci,
        String nombre,
        String apellido,
        String rol,
        String correo,
        String correoPendiente,
        String telefono1,
        String telefono2,
        String direccion
) {
}
