package uy.edu.proyecto.backend.correo;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Proveedor por defecto: no envia nada y lo declara como fallo, nunca como exito. */
@Component
@ConditionalOnProperty(
        name = "app.mail.provider",
        havingValue = "none",
        matchIfMissing = true
)
public class SinProveedorCorreoSender implements CorreoSender {

    @Override
    public void enviar(CorreoMensaje mensaje) {
        throw new CorreoException(
                "No hay proveedor de correo configurado (MAIL_PROVIDER=none)"
        );
    }
}
