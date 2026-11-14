package uy.edu.proyecto.backend.notificacion;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

@Component
public class EnvioNotificacionListener {

    private final EnvioNotificacionDispatcher dispatcher;

    public EnvioNotificacionListener(EnvioNotificacionDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void enviar(EnviosNotificacionSolicitados evento) {
        for (Long envioId : evento.envioIds()) {
            dispatcher.despachar(envioId);
        }
    }
}
