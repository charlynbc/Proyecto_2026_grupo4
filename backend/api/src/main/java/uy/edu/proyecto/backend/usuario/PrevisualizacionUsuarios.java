package uy.edu.proyecto.backend.usuario;

import java.util.List;

/** Respuesta de la previsualizacion: cuentas y detalle fila por fila. */
public record PrevisualizacionUsuarios(
        int total,
        int validas,
        int invalidas,
        List<FilaUsuarioCsv> filas,
        List<FilaUsuarioCsv> errores
) {
}
