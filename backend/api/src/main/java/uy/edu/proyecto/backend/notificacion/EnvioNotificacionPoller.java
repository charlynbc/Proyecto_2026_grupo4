package uy.edu.proyecto.backend.notificacion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class EnvioNotificacionPoller {

    private static final Logger log =
            LoggerFactory.getLogger(EnvioNotificacionPoller.class);

    private static final int MAX_ENVIOS_POR_CICLO = 100;

    private final EnvioNotificacionDispatcher dispatcher;

    public EnvioNotificacionPoller(EnvioNotificacionDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Scheduled(fixedDelayString = "${app.notificaciones.intervalo-ms:30000}")
    public void despacharPendientes() {
        for (int enviados = 0; enviados < MAX_ENVIOS_POR_CICLO; enviados++) {
            try {
                if (!dispatcher.despacharSiguientePendiente()) {
                    return;
                }
            } catch (RuntimeException exception) {
                // Una falla de infraestructura (por ejemplo la base) corta este
                // ciclo; el siguiente lo reintenta. No debe tirar la tarea programada.
                log.error(
                        "No se pudo despachar el siguiente envío pendiente; se reintenta en el próximo ciclo; tipo de error: {}",
                        exception.getClass().getSimpleName()
                );
                return;
            }
        }
    }
}
