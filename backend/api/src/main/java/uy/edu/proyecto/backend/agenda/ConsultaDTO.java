package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record ConsultaDTO(
        Long id,
        String estado,
        LocalDate fecha,
        int numero,
        String horaInicio,
        String horaFin,
        MedicoRef medico,
        Especialidad especialidad,
        Consultorio consultorio,
        Long paseId,
        OffsetDateTime agendadaEn,
        OffsetDateTime canceladaEn,
        String motivoCancelacion,
        boolean cancelable
) {
    /**
     * La misma consulta con {@code cancelable} resuelto por el servicio. Los
     * repositorios arman el DTO con false y no calculan nada: el valor sale de
     * {@link ReglaCancelableSocio} con el reloj y el plazo del servidor.
     */
    public ConsultaDTO conCancelable(boolean valor) {
        return new ConsultaDTO(id, estado, fecha, numero, horaInicio, horaFin, medico,
                especialidad, consultorio, paseId, agendadaEn, canceladaEn,
                motivoCancelacion, valor);
    }

    public record MedicoRef(
            Long id,
            String nombre,
            String apellido
    ) {
    }
}
