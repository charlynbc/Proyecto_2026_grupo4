package uy.edu.proyecto.backend.notificacion;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class EnvioSuspensionPoller {

    private static final int MAX_ENVIOS_POR_CICLO = 100;

    private final EnvioSuspensionDispatcher dispatcher;

    public EnvioSuspensionPoller(EnvioSuspensionDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Scheduled(fixedDelayString = "${app.notificaciones.intervalo-ms:30000}")
    public void despacharPendientes() {
        for (int enviados = 0; enviados < MAX_ENVIOS_POR_CICLO; enviados++) {
            if (!dispatcher.despacharSiguientePendiente()) {
                return;
            }
        }
    }
}
