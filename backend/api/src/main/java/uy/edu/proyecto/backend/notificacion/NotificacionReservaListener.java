package uy.edu.proyecto.backend.notificacion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class NotificacionReservaListener {

    private static final Logger log =
            LoggerFactory.getLogger(
                    NotificacionReservaListener.class
            );

    @TransactionalEventListener(
            phase = TransactionPhase.AFTER_COMMIT
    )
    public void reservaConfirmada(
            ReservaCreadaEvent event
    ) {

        log.info(
                "NOTIFICACION_EVENTO reserva={} horario={}",
                event.reservaId(),
                event.horarioId()
        );
    }
}
