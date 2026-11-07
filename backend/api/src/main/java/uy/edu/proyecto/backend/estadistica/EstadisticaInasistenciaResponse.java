package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record EstadisticaInasistenciaResponse(
        LocalDate desde, LocalDate hasta, String agruparPor, List<Item> items
) {
    public record Item(
            long id, String nombre, String apellido, long atendidas, long noAsistio,
            long noSePresento, long noAtendidas, long total,
            BigDecimal porcentajeInasistencia, String inasistencia
    ) {}
}
