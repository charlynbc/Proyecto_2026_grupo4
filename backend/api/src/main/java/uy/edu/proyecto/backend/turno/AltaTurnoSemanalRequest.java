package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

public record AltaTurnoSemanalRequest(
        Long medicoId,
        Long especialidadId,
        Long consultorioId,
        Integer diaSemana,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        List<NumeroSemanalRequest> numeros
) {
    public record NumeroSemanalRequest(
            Integer numero,
            String horaInicio,
            String horaFin
    ) {
    }
}
