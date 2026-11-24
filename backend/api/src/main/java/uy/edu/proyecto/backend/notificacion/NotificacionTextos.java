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

    /** El aviso de historia clinica nunca lleva datos clinicos: es una regla de privacidad. */
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

    /** El nombre del medico en un aviso: nombre y apellido, como en el de agenda. */
    public static String medico(String nombre, String apellido) {
        return nombre + " " + apellido;
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

    /**
     * Recordatorio de una consulta agendada (RNF-25): especialidad, medico,
     * fecha, hora y consultorio. La ubicacion va entre parentesis solo si existe.
     */
    public static String cuerpoRecordatorio(
            String especialidad,
            String medicoNombre,
            String medicoApellido,
            LocalDate fecha,
            LocalTime hora,
            String consultorioNombre,
            String consultorioUbicacion
    ) {
        String consultorio = consultorioUbicacion == null || consultorioUbicacion.isBlank()
                ? consultorioNombre
                : consultorioNombre + " (" + consultorioUbicacion + ")";
        return "Recordatorio de consulta: " + especialidad + " con "
                + medicoNombre + " " + medicoApellido
                + ", el " + fecha(fecha) + " a las " + hora(hora)
                + ", en " + consultorio;
    }

    /** Cancelacion que hace un funcionario a pedido del socio (RF-19). */
    public static String cuerpoCancelacionASolicitudDelSocio(
            String especialidad,
            String medico,
            LocalDate fecha,
            LocalTime hora
    ) {
        return "Tu consulta de " + especialidad + " con " + medico
                + " del " + fecha(fecha) + " a las " + hora(hora)
                + " fue cancelada a tu solicitud.";
    }

    /**
     * Cancelacion de una consulta por la institucion: la hace un funcionario
     * por otro motivo (RF-19) o el medico (RF-27). Sin motivo no lleva la
     * oracion del motivo.
     */
    public static String cuerpoCancelacionPorInstitucion(
            String especialidad,
            String medico,
            LocalDate fecha,
            LocalTime hora,
            String motivo
    ) {
        return "Tu consulta de " + especialidad + " con " + medico
                + " del " + fecha(fecha) + " a las " + hora(hora)
                + " fue cancelada por la institución." + oracionMotivo(motivo);
    }

    /**
     * Consulta cancelada porque se suspendio el turno completo: lo hace el
     * medico (RF-27) o un funcionario (RF-14). Sin motivo no lleva la oracion
     * del motivo.
     */
    public static String cuerpoSuspension(
            String especialidad,
            String medico,
            LocalDate fecha,
            LocalTime horaInicio,
            LocalTime horaFin,
            int numero,
            String motivo
    ) {
        return "Tu consulta de " + especialidad + " con " + medico
                + " del " + fecha(fecha)
                + " fue cancelada por la institución. Horario: "
                + hora(horaInicio) + " a " + hora(horaFin)
                + " (número " + numero + ")." + oracionMotivo(motivo);
    }

    private static String oracionMotivo(String motivo) {
        return motivo == null || motivo.isBlank() ? "" : " Motivo: " + motivo;
    }

    public static String titulo(String tipo) {
        return TITULOS.getOrDefault(tipo == null ? "" : tipo, TITULO_GENERICO);
    }
}
