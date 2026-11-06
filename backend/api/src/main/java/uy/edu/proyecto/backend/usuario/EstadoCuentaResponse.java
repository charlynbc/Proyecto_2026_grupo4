package uy.edu.proyecto.backend.usuario;

import java.time.OffsetDateTime;

/**
 * Resultado de la inactivacion o reactivacion administrativa de una cuenta
 * de empleado (RF-45). estado es ACTIVA o INACTIVA; los campos ultima*En e
 * ultimo*Por registran quien realizo cada operacion y cuando.
 */
public record EstadoCuentaResponse(
        long id,
        String ci,
        String nombre,
        String apellido,
        String rol,
        String estado,
        OffsetDateTime ultimaInactivacionEn,
        Long ultimaInactivacionPor,
        OffsetDateTime ultimaReactivacionEn,
        Long ultimaReactivacionPor
) {
}
