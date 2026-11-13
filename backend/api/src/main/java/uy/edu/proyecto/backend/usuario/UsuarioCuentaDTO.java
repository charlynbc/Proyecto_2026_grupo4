package uy.edu.proyecto.backend.usuario;

import java.time.OffsetDateTime;

public record UsuarioCuentaDTO(
        Long id,
        String ci,
        String nombre,
        String apellido,
        String rol,
        String correo,
        String estado,
        boolean activada,
        OffsetDateTime fechaAlta,
        boolean puedeInactivar
) {

    /** La misma fila con puedeInactivar decidido por la regla de inactivacion. */
    public UsuarioCuentaDTO conPuedeInactivar(boolean valor) {
        return new UsuarioCuentaDTO(
                id, ci, nombre, apellido, rol, correo, estado, activada, fechaAlta, valor);
    }
}
