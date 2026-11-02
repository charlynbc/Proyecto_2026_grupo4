package uy.edu.proyecto.backend.usuario;

/**
 * Fila del CSV de usuarios ya validada; error != null si se rechaza.
 * Expone solo los datos identificadores de la cuenta (RF-32: cada fila es
 * una cuenta); el detalle completo lo corrige el administrador en el archivo.
 */
public record FilaUsuarioCsv(
        int numero,
        String ci,
        String nombre,
        String apellido,
        String rol,
        String error
) {
    public boolean valida() {
        return error == null;
    }
}
