package uy.edu.proyecto.backend.notificacion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

@Component
public class EnvioNotificacionListener {

    private static final Logger log =
            LoggerFactory.getLogger(EnvioNotificacionListener.class);

    private final EnvioNotificacionDispatcher dispatcher;

    public EnvioNotificacionListener(EnvioNotificacionDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    /**
     * Entrega despues del commit de la operacion. Un envio que falla en el
     * proveedor no impide intentar los demas ni sale como excepcion (RNF-24):
     * el dispatcher lo deja FALLIDO, con sus intentos anotados. Solo si falla
     * la base de datos el dispatcher propaga la excepcion: aca se registra y
     * ese envio queda PENDIENTE, para que lo tome el poller.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void enviar(EnviosNotificacionSolicitados evento) {
        for (Long envioId : evento.envioIds()) {
            try {
                dispatcher.despachar(envioId);
            } catch (RuntimeException exception) {
                log.error(
                        "No se pudo despachar el envío {}; queda pendiente para el próximo ciclo; tipo de error: {}",
                        envioId,
                        exception.getClass().getSimpleName()
                );
            }
        }
    }
}
