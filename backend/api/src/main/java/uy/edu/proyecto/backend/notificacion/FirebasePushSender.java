package uy.edu.proyecto.backend.notificacion;

import java.util.Map;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;

import org.springframework.stereotype.Component;

/**
 * Entrega por Firebase Cloud Messaging. No toca el SDK hasta que se envia algo:
 * con Firebase deshabilitado (APP_FIREBASE_ENABLED=false) el envio falla con
 * IllegalStateException y el dispatcher deja el envio en FALLIDO.
 */
@Component
public class FirebasePushSender implements PushSender {

    @Override
    public void enviar(
            String token,
            String titulo,
            String cuerpo,
            Map<String, String> datos
    ) {
        Message.Builder mensaje = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder()
                        .setTitle(titulo)
                        .setBody(cuerpo)
                        .build());
        datos.forEach(mensaje::putData);
        try {
            FirebaseMessaging.getInstance().send(mensaje.build());
        } catch (FirebaseMessagingException exception) {
            throw new PushException("El proveedor rechazó el aviso push", exception);
        }
    }
}
