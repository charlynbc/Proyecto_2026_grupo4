package uy.edu.proyecto.backend.notificacion;

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

    private NotificacionTextos() {
    }

    public static String titulo(String tipo) {
        return TITULOS.getOrDefault(tipo == null ? "" : tipo, TITULO_GENERICO);
    }
}
