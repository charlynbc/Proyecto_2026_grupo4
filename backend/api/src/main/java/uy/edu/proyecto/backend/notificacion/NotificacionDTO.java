package uy.edu.proyecto.backend.notificacion;

import java.time.OffsetDateTime;

/** Un aviso de la lista del socio (contrato, GET /api/notificaciones). */
public record NotificacionDTO(
        long id,
        String tipo,
        String titulo,
        String contenido,
        OffsetDateTime creadaEn,
        long consultaId,
        /** Solo para HISTORIA_ACTUALIZADA con atencion registrada; null en los demas casos (la clave siempre viaja). */
        Long atencionId
) {
}
