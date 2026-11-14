package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Map;

/**
 * Textos de los avisos al socio que dependen del tipo de notificacion. El
 * cuerpo es el contenido que se guardo con la notificacion; el titulo (asunto
 * del correo y titulo del push) sale del tipo.
 */
public final class NotificacionTextos {

    private static final String TITULO_GENERICO = "Aviso de tu consulta";

    private static final Map<String, String> TITULOS = Map.of(
            "AGENDA", "Consulta agendada",
            "CANCELACION", "Consulta cancelada",
            "SUSPENSION", "Turno suspendido",
            "HISTORIA_ACTUALIZADA", "Historia clínica actualizada",
            "RECORDATORIO", "Recordatorio de consulta"
    );

    /** El aviso de historia clinica nunca lleva datos clinicos (R-MDAT-20). */
    public static final String CUERPO_HISTORIA_ACTUALIZADA =
            "Tu historia clínica fue actualizada.";

    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private NotificacionTextos() {
    }

    /** Cuerpo del aviso de una consulta recien agendada (fecha dd/mm/aaaa y hora de 24 h). */
    public static String cuerpoAgenda(
            String especialidad,
            String medico,
            LocalDate fecha,
            String hora
    ) {
        return "Tu consulta de " + especialidad + " con " + medico
                + " quedó agendada para el " + FECHA.format(fecha)
                + " a las " + hora + ".";
    }

    public static String titulo(String tipo) {
        return TITULOS.getOrDefault(tipo == null ? "" : tipo, TITULO_GENERICO);
    }
}
