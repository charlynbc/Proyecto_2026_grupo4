package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;

/**
 * Si el socio puede cancelar hoy una consulta suya: se presenta AGENDADA, el
 * socio no registro llegada y el inicio no cae antes de ahora mas el plazo
 * minimo. Es el campo cancelable de la consulta del socio, y da false
 * exactamente cuando la cancelacion del socio respondería 409 por
 * CONSULTA_NO_AGENDADA, LLEGADA_YA_REGISTRADA o CANCELACION_FUERA_DE_PLAZO.
 *
 * El estado y el plazo son los de {@link ReglaCancelableAgenda}. Lo propio de
 * esta clase es la llegada: hoy se evalua por socio y dia (RF-10), y el valor
 * que llega en {@code llegadaRegistrada} sale de un fragmento SQL unico en
 * ConsultaRepository. Si la regla pasa a ser por consulta, se cambia aca y en
 * ese fragmento, nada mas.
 */
public final class ReglaCancelableSocio {

    private ReglaCancelableSocio() {
    }

    /**
     * @param estado           estado efectivo de la consulta, el que se presenta
     * @param fecha            dia de la consulta
     * @param horaInicio       hora de inicio, como la devuelve la consulta
     * @param zona             zona horaria del servidor
     * @param ahora            el instante actual
     * @param horasMinimas     plazo minimo de anticipacion, en horas
     * @param llegadaRegistrada el socio ya registro su llegada (hoy, ese dia)
     */
    public static boolean evaluar(
            String estado,
            LocalDate fecha,
            String horaInicio,
            ZoneId zona,
            ZonedDateTime ahora,
            int horasMinimas,
            boolean llegadaRegistrada
    ) {
        if (llegadaRegistrada) {
            return false;
        }
        return ReglaCancelableAgenda.evaluar(estado, fecha, horaInicio, zona, ahora, horasMinimas);
    }
}
