package uy.edu.proyecto.backend.notificacion;

/**
 * FCM respondio UNREGISTERED: el token ya no sirve (la app se desinstalo o el
 * token vencio). Quien la atrape puede deshabilitar el dispositivo. Como el
 * resto de las PushException, no lleva el token ni el contenido del aviso.
 */
public class PushTokenNoRegistradoException extends PushException {

    public PushTokenNoRegistradoException(String mensaje, Throwable causa) {
        super(mensaje, causa);
    }
}
