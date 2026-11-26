package uy.edu.proyecto.backend.notificacion;

import java.util.Map;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
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
        Message mensaje = armarMensaje(token, titulo, cuerpo, datos);
        try {
            FirebaseMessaging.getInstance().send(mensaje);
        } catch (FirebaseMessagingException exception) {
            throw traducir(exception);
        }
    }

    /**
     * El mensaje de FCM: el aviso (titulo y cuerpo), los datos y la politica de
     * Android segun el tipo que viaja en datos.get("tipo"): canal, prioridad y TTL.
     */
    static Message armarMensaje(
            String token,
            String titulo,
            String cuerpo,
            Map<String, String> datos
    ) {
        PoliticaAndroidAviso politica = PoliticaAndroidAviso.de(datos.get("tipo"));
        Message.Builder mensaje = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder()
                        .setTitle(titulo)
                        .setBody(cuerpo)
                        .build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(politica.prioridad())
                        .setTtl(politica.ttlMilisegundos())
                        .setNotification(AndroidNotification.builder()
                                .setChannelId(politica.canal())
                                .build())
                        .build());
        datos.forEach(mensaje::putData);
        return mensaje.build();
    }

    /**
     * Solo UNREGISTERED es "el token ya no existe". Cualquier otro codigo, incluido
     * null, es un rechazo comun (INVALID_ARGUMENT, por ejemplo, tambien puede ser
     * un mensaje mal armado y no se trata como token invalido).
     */
    static PushException traducir(FirebaseMessagingException exception) {
        if (exception.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
            return new PushTokenNoRegistradoException(
                    "El dispositivo ya no está registrado en el proveedor del aviso push", exception);
        }
        return new PushException("El proveedor rechazó el aviso push", exception);
    }
}
