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
        OffsetDateTime fechaAlta
) {
}
