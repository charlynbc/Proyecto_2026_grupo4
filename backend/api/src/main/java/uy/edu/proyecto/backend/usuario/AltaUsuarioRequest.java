package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.util.List;

public record AltaUsuarioRequest(
        String ci,
        String nombre,
        String apellido,
        LocalDate fechaNacimiento,
        String correo,
        String telefono1,
        String telefono2,
        String direccion,
        String rol,
        List<Long> especialidadIds
) {
}
