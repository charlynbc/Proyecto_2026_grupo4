package uy.edu.proyecto.backend.especialidad;

import java.util.List;

/** Respuesta de la confirmacion: importadas, rechazadas y detalle por fila. */
public record ResultadoImportacionEspecialidades(
        int total,
        int importadas,
        int rechazadas,
        List<FilaEspecialidadCsv> filas,
        List<FilaEspecialidadCsv> errores
) {
}
