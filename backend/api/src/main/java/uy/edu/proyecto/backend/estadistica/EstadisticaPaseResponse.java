package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record EstadisticaPaseResponse(
        LocalDate desde, LocalDate hasta, Long especialidadOrigenId, List<Item> items
) {
    public record Item(Especialidad especialidadDestino, long emitidos, long utilizados,
            long disponibles, long vencidos, BigDecimal porcentajeUtilizados,
            String utilizacion) {}
}
