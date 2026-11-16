package uy.edu.proyecto.backend.notificacion;

/** El mensaje describe el fallo sin incluir el token del dispositivo ni el contenido. */
public class PushException extends RuntimeException {

    public PushException(String mensaje) {
        super(mensaje);
    }

    public PushException(String mensaje, Throwable causa) {
        super(mensaje, causa);
    }
}
