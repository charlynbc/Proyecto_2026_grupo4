package uy.edu.proyecto.backend.especialidad;

import java.util.List;

/** Respuesta de la previsualizacion: cuentas y detalle fila por fila. */
public record PrevisualizacionEspecialidades(
        int total,
        int validas,
        int invalidas,
        List<FilaEspecialidadCsv> filas,
        List<FilaEspecialidadCsv> errores
) {
}
