package uy.edu.proyecto.backend.notificacion;

import java.util.Optional;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class FirebaseNotificationService {

    private static final Logger log =
            LoggerFactory.getLogger(
                    FirebaseNotificationService.class
            );

    private final FirebaseRegistrationStore store;

    public FirebaseNotificationService(
            FirebaseRegistrationStore store
    ) {
        this.store = store;
    }

    public void notificarReservaConfirmada(
            Long usuarioId,
            Long reservaId,
            Long horarioId
    ) {

        Optional<String> fidOptional =
                store.buscar(usuarioId);

        if (fidOptional.isEmpty()) {

            log.info(
                    "Usuario {} no tiene navegador registrado en Firebase",
                    usuarioId
            );

            return;
        }

        String fid = fidOptional.get();

        Message message =
                Message.builder()

                        .setFid(fid)

                        .setNotification(
                                Notification.builder()
                                        .setTitle(
                                                "Reserva confirmada"
                                        )
                                        .setBody(
                                                "Tu reserva fue realizada correctamente."
                                        )
                                        .build()
                        )

                        .putData(
                                "tipo",
                                "RESERVA_CONFIRMADA"
                        )

                        .putData(
                                "reservaId",
                                reservaId.toString()
                        )

                        .putData(
                                "horarioId",
                                horarioId.toString()
                        )

                        .build();

        try {

            String respuesta =
                    FirebaseMessaging
                            .getInstance()
                            .send(message);

            log.info(
                    "Notificacion Firebase enviada: {}",
                    respuesta
            );

        } catch (FirebaseMessagingException exception) {

            log.error(
                    "Error enviando notificacion Firebase",
                    exception
            );
        }
    }
}
