package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record TurnoSemanalResponse(
        Long id,
        MedicoRef medico,
        Especialidad especialidad,
        Consultorio consultorio,
        int diaSemana,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        List<NumeroSemanalResponse> numeros,
        int cantidadTurnos
) {
    public record MedicoRef(
            Long id,
            String nombre,
            String apellido
    ) {
    }

    public record NumeroSemanalResponse(
            int numero,
            String horaInicio,
            String horaFin
    ) {
    }
}
