package uy.edu.proyecto.backend.correo;

/** Proveedor de envio de correo, independiente de quien genera el contenido. */
public interface CorreoSender {

    /** @throws CorreoException si el proveedor no pudo entregar el mensaje. */
    void enviar(CorreoMensaje mensaje);
}
