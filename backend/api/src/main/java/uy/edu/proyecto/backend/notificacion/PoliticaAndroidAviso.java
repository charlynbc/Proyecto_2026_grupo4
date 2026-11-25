package uy.edu.proyecto.backend.notificacion;

import java.time.Duration;

import com.google.firebase.messaging.AndroidConfig;

/**
 * Como se entrega un aviso push en Android: canal, prioridad y cuanto tiempo
 * lo guarda FCM si el dispositivo esta apagado o sin conexion (TTL).
 *
 * El recordatorio dura 2 horas: pasado ese tiempo ya no sirve. Los demas avisos
 * (y un tipo desconocido o nulo) duran 7 dias. Todos con prioridad alta.
 */
public record PoliticaAndroidAviso(String canal, AndroidConfig.Priority prioridad, long ttlMilisegundos) {

    /**
     * Id del canal de notificaciones de Android. La app (frontend) tiene que
     * crear un canal con este mismo id: si cambia aca, cambia alla.
     */
    public static final String CANAL_AVISOS = "avisos_consultas";

    private static final long TTL_RECORDATORIO_MS = Duration.ofHours(2).toMillis();
    private static final long TTL_GENERAL_MS = Duration.ofDays(7).toMillis();

    public static PoliticaAndroidAviso de(String tipo) {
        long ttl = "RECORDATORIO".equals(tipo) ? TTL_RECORDATORIO_MS : TTL_GENERAL_MS;
        return new PoliticaAndroidAviso(CANAL_AVISOS, AndroidConfig.Priority.HIGH, ttl);
    }
}
