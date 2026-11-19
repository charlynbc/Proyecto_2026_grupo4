package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

/**
 * Si una consulta de la agenda se puede cancelar ahora: su estado efectivo es
 * AGENDADA y el inicio no cae antes de ahora mas el plazo minimo. Un inicio
 * justo en el limite es cancelable.
 *
 * Esta es la misma comparacion que CancelacionFuncionarioService,
 * CancelacionService y CancelacionMedicoService hacen al cancelar; la regla
 * esta repetida en esos tres servicios y unificarla es una tarjeta aparte.
 * No cubre el conflicto de interes (403): quien consulta no es un dato de la
 * agenda.
 */
final class ReglaCancelableAgenda {

    private ReglaCancelableAgenda() {
    }

    /**
     * @param estado       estado efectivo de la consulta, el que muestra la agenda
     * @param fecha        dia de la consulta
     * @param horaInicio   hora de inicio, como la devuelve la agenda
     * @param zona         zona horaria del servidor
     * @param ahora        el instante actual
     * @param horasMinimas plazo minimo de anticipacion, en horas
     */
    static boolean evaluar(
            String estado,
            LocalDate fecha,
            String horaInicio,
            ZoneId zona,
            ZonedDateTime ahora,
            int horasMinimas
    ) {
        if (!"AGENDADA".equals(estado)) {
            return false;
        }
        ZonedDateTime inicio = fecha.atTime(LocalTime.parse(horaInicio)).atZone(zona);
        return !inicio.isBefore(ahora.plusHours(horasMinimas));
    }
}
