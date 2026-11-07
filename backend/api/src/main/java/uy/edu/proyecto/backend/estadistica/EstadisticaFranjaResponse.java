package uy.edu.proyecto.backend.estadistica;

import java.time.LocalDate;
import java.util.List;

public record EstadisticaFranjaResponse(
        LocalDate desde, LocalDate hasta, String vista, Long especialidadId, List<Celda> celdas
) {
    // ISO: lunes = 1, domingo = 7. Hora = comienzo de la franja [hora, hora + 1).
    public record Celda(int diaSemana, int hora, long cantidad) {}
}
