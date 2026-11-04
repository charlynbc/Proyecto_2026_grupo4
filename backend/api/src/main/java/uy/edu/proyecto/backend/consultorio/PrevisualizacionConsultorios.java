package uy.edu.proyecto.backend.consultorio;

import java.util.List;

/** Respuesta de la previsualizacion: cuentas y detalle fila por fila. */
public record PrevisualizacionConsultorios(
        int total,
        int validas,
        int invalidas,
        List<FilaConsultorioCsv> filas,
        List<FilaConsultorioCsv> errores
) {
}
