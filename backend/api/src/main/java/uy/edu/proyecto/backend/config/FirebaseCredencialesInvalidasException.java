package uy.edu.proyecto.backend.config;

/** La variable con la clave de cuenta de servicio no se pudo interpretar. */
public class FirebaseCredencialesInvalidasException extends RuntimeException {

    public FirebaseCredencialesInvalidasException(String mensaje) {
        super(mensaje);
    }
}
