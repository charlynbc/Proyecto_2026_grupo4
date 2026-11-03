package uy.edu.proyecto.backend.usuario;

import java.util.List;

/** Respuesta de la confirmacion: importadas, rechazadas y detalle por fila. */
public record ResultadoImportacionUsuarios(
        int total,
        int importadas,
        int rechazadas,
        List<FilaUsuarioCsv> filas,
        List<FilaUsuarioCsv> errores
) {
}
