package uy.edu.proyecto.backend.correo;

/** El mensaje describe el fallo sin incluir destinatario, contenido ni credenciales. */
public class CorreoException extends RuntimeException {

    public CorreoException(String mensaje) {
        super(mensaje);
    }
}
