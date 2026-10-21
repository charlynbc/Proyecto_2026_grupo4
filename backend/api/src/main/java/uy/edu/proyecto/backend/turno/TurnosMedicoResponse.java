package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record TurnosMedicoResponse(List<TurnoMedicoItem> items) {

    public record TurnoMedicoItem(
            Long id,
            LocalDate fecha,
            String horaInicio,
            String horaFin,
            Especialidad especialidad,
            Consultorio consultorio,
            String estado,
            long cantidadNumeros,
            long cantidadReservados
    ) {
    }
}
