package uy.edu.proyecto.backend.notificacion;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosSuspensionSolicitados;

@Component
public class EnvioSuspensionListener {

    private final EnvioSuspensionDispatcher dispatcher;

    public EnvioSuspensionListener(EnvioSuspensionDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void enviar(EnviosSuspensionSolicitados evento) {
        for (Long envioId : evento.envioIds()) {
            dispatcher.despachar(envioId);
        }
    }
}
