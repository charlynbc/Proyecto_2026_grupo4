package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;
import java.time.LocalTime;
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
    private static final DateTimeFormatter HORA = DateTimeFormatter.ofPattern("HH:mm");

    private NotificacionTextos() {
    }

    /** La unica forma de escribir una fecha en un aviso: dd/mm/aaaa (RNF-16). */
    public static String fecha(LocalDate fecha) {
        return FECHA.format(fecha);
    }

    /** La unica forma de escribir una hora en un aviso: HH:mm de 24 h (RNF-16). */
    public static String hora(LocalTime hora) {
        return HORA.format(hora);
    }

    /** Cuerpo del aviso de una consulta recien agendada (fecha dd/mm/aaaa y hora de 24 h). */
    public static String cuerpoAgenda(
            String especialidad,
            String medico,
            LocalDate fecha,
            LocalTime hora
    ) {
        return "Tu consulta de " + especialidad + " con " + medico
                + " quedó agendada para el " + fecha(fecha)
                + " a las " + hora(hora) + ".";
    }

    /** Cancelacion que hace un funcionario a pedido del socio (RF-19). */
    public static String cuerpoCancelacionASolicitudDelSocio(LocalDate fecha) {
        return "Tu consulta del " + fecha(fecha) + " fue cancelada a tu solicitud.";
    }

    /** Cancelacion que hace un funcionario por otro motivo, administrativo u otro (RF-19). */
    public static String cuerpoCancelacionPorOtroMotivo(LocalDate fecha, String motivo) {
        return "Tu consulta del " + fecha(fecha)
                + " fue cancelada por la institución. Motivo: " + motivo;
    }

    /** Cancelacion de una consulta por el medico (RF-27). */
    public static String cuerpoCancelacionPorMedico(LocalDate fecha, String motivo) {
        return "Tu consulta del " + fecha(fecha)
                + " fue cancelada por la institución. Motivo: " + motivo;
    }

    /** Consulta cancelada porque el medico cancelo todo su turno (RF-27). */
    public static String cuerpoSuspensionPorMedico(
            LocalDate fecha,
            LocalTime horaInicio,
            LocalTime horaFin,
            int numero,
            String motivo
    ) {
        return "Tu consulta del " + fecha(fecha)
                + " fue cancelada por la institución. Horario: "
                + hora(horaInicio) + " a " + hora(horaFin)
                + " (número " + numero + "). Motivo: " + motivo;
    }

    /**
     * Consulta cancelada por la suspension del turno que hace un funcionario
     * (RF-14). El horario y la observacion son opcionales.
     */
    public static String cuerpoSuspensionPorFuncionario(
            LocalDate fecha,
            LocalTime horaInicio,
            LocalTime horaFin,
            int numero,
            String observacion
    ) {
        StringBuilder cuerpo = new StringBuilder(
                "Tu consulta del " + fecha(fecha) + " fue cancelada por la institución."
        );
        if (horaInicio != null) {
            cuerpo.append(" Horario: ")
                    .append(hora(horaInicio))
                    .append(" a ")
                    .append(hora(horaFin))
                    .append(" (número ")
                    .append(numero)
                    .append(").");
        }
        if (observacion != null) {
            cuerpo.append(" ").append(observacion);
        }
        return cuerpo.toString();
    }

    public static String titulo(String tipo) {
        return TITULOS.getOrDefault(tipo == null ? "" : tipo, TITULO_GENERICO);
    }
}
