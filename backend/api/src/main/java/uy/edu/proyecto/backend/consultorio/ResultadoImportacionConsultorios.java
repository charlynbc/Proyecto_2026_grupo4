package uy.edu.proyecto.backend.consultorio;

import java.util.List;

/** Respuesta de la confirmacion: importadas, rechazadas y detalle por fila. */
public record ResultadoImportacionConsultorios(
        int total,
        int importadas,
        int rechazadas,
        List<FilaConsultorioCsv> filas,
        List<FilaConsultorioCsv> errores
) {
}
