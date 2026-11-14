package uy.edu.proyecto.backend.dispositivo;

import java.time.OffsetDateTime;

public record DispositivoDTO(
        Long id,
        boolean habilitado,
        OffsetDateTime registradoEn
) {
}
