package uy.edu.proyecto.backend.usuario;

/**
 * Campos editables por el propio usuario (RF-06). El controlador rechaza
 * cualquier otro campo (ci, nombre, apellido, fechaNacimiento, rol, estado,
 * id...) con 400 VALIDACION: esos solo los corrige el Administrador (RF-38).
 */
public record ActualizarDatosPersonalesRequest(
        String direccion,
        String telefono1,
        String telefono2,
        String correo
) {
}
