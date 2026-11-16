package uy.edu.proyecto.backend.notificacion;

import java.util.Map;

/** Proveedor de notificaciones push, independiente de quien genera el contenido. */
public interface PushSender {

    /** @throws PushException si el proveedor no pudo entregar el mensaje. */
    void enviar(String token, String titulo, String cuerpo, Map<String, String> datos);
}
