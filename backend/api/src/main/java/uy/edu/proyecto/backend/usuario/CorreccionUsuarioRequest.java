package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.util.List;

/**
 * Correccion administrativa de una cuenta (RF-38). Un campo null significa
 * "no se corrige"; en telefono2 y direccion la cadena vacia borra el dato
 * (mismo criterio que RF-06). El rol nunca se modifica. especialidadIds solo
 * aplica a cuentas de medico y reemplaza el conjunto completo.
 */
public record CorreccionUsuarioRequest(
        String ci,
        String nombre,
        String apellido,
        LocalDate fechaNacimiento,
        String correo,
        String telefono1,
        String telefono2,
        String direccion,
        List<Long> especialidadIds
) {
    public boolean sinCambios() {
        return ci == null && nombre == null && apellido == null
                && fechaNacimiento == null && correo == null
                && telefono1 == null && telefono2 == null
                && direccion == null && especialidadIds == null;
    }
}
