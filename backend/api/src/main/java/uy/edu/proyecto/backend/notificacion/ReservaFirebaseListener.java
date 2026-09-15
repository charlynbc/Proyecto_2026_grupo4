package uy.edu.proyecto.backend.notificacion;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ReservaFirebaseListener {

    private final FirebaseNotificationService
            firebaseNotificationService;

    public ReservaFirebaseListener(
            FirebaseNotificationService
                    firebaseNotificationService
    ) {

        this.firebaseNotificationService =
                firebaseNotificationService;
    }

    @TransactionalEventListener(
            phase = TransactionPhase.AFTER_COMMIT
    )
    public void reservaCreada(
            ReservaCreadaEvent event
    ) {

        firebaseNotificationService
                .notificarReservaConfirmada(
                        event.usuarioId(),
                        event.reservaId(),
                        event.horarioId()
                );
    }
}
