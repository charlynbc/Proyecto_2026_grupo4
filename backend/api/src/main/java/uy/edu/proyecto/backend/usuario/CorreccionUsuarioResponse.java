package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.util.List;

/**
 * Estado completo de la cuenta tras la correccion administrativa (RF-38).
 * especialidadIds solo se completa para cuentas de medico (vacio en otro
 * caso). estado es ACTIVA o INACTIVA; activada indica que el primer ingreso
 * se completo.
 */
public record CorreccionUsuarioResponse(
        long id,
        String ci,
        String nombre,
        String apellido,
        LocalDate fechaNacimiento,
        String rol,
        String correo,
        String telefono1,
        String telefono2,
        String direccion,
        List<Long> especialidadIds,
        String estado,
        boolean activada
) {
}
