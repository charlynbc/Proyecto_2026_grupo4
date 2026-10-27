package uy.edu.proyecto.backend.correo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger LOGGER =
            LoggerFactory.getLogger(SinProveedorCorreoSender.class);

    public SinProveedorCorreoSender() {
        LOGGER.warn("MAIL_PROVIDER=none: el backend no enviara correos "
                + "(configurar smtp con Mailpit o resend)");
    }

    @Override
    public void enviar(CorreoMensaje mensaje) {
        throw new CorreoException(
                "No hay proveedor de correo configurado (MAIL_PROVIDER=none)"
        );
    }
}
