package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import uy.edu.proyecto.backend.consultorio.Consultorio;

/** RF-20: vista previa estrictamente de lectura, ordenada por fecha. */
public record VistaPreviaConsultorioResponse(List<Fecha> fechas) {
    public record Fecha(
            Long turnoId,
            LocalDate fecha,
            String estado,
            int consultasAgendadas,
            Consultorio consultorioActual,
            List<Solapamiento> solapamientos
    ) {
    }

    public record Solapamiento(
            int numeroPropio,
            int numeroExistente
    ) {
    }
}
