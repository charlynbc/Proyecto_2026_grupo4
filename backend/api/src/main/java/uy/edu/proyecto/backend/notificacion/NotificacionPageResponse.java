package uy.edu.proyecto.backend.notificacion;

import java.util.List;

public record NotificacionPageResponse(
        List<NotificacionDTO> items,
        int page,
        int size,
        long total
) {
}
