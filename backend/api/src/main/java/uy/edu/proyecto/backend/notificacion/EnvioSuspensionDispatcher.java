package uy.edu.proyecto.backend.notificacion;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;

@Service
public class EnvioSuspensionDispatcher {

    private static final Logger log =
            LoggerFactory.getLogger(EnvioSuspensionDispatcher.class);

    private final TurnoFechasRepository repository;
    private final CorreoSender correoSender;

    public EnvioSuspensionDispatcher(
            TurnoFechasRepository repository,
            CorreoSender correoSender
    ) {
        this.repository = repository;
        this.correoSender = correoSender;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void despachar(Long envioId) {
        var envio = repository.buscarEnvio(envioId);
        if (envio.isPresent()) {
            enviar(envio.get());
        } else if (!repository.existeEnvio(envioId)) {
            throw new IllegalStateException(
                    "No existe el envío de notificación " + envioId
            );
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean despacharSiguientePendiente() {
        return repository.bloquearSiguienteEnvioPendiente()
                .flatMap(repository::buscarEnvio)
                .map(envio -> {
                    enviar(envio);
                    return true;
                })
                .orElse(false);
    }

    private void enviar(EnvioNotificacion envio) {
        try {
            if ("CORREO".equals(envio.canal())) {
                correoSender.enviar(new CorreoMensaje(
                        envio.correo(),
                        "Turno suspendido",
                        envio.contenido()
                ));
            } else if ("PUSH".equals(envio.canal())) {
                enviarPush(envio);
            } else {
                throw new IllegalStateException(
                        "Canal de notificación no soportado: " + envio.canal()
                );
            }
        } catch (CorreoException | FirebaseMessagingException
                 | IllegalArgumentException | IllegalStateException exception) {
            marcar(envio.envioId(), "FALLIDO");
            log.error(
                    "No se pudo entregar la notificación de suspensión {} por canal {}; tipo de error: {}",
                    envio.notificacionId(),
                    envio.canal(),
                    exception.getClass().getSimpleName()
            );
            return;
        }
        marcar(envio.envioId(), "ENVIADO");
        log.info(
                "El proveedor aceptó la notificación de suspensión {} por canal {}",
                envio.notificacionId(),
                envio.canal()
        );
    }

    private void marcar(Long envioId, String estado) {
        if (repository.marcarEnvio(envioId, estado) != 1) {
            throw new IllegalStateException(
                    "No se pudo registrar el estado del envío " + envioId
            );
        }
    }

    private void enviarPush(EnvioNotificacion envio)
            throws FirebaseMessagingException {
        if (envio.token() == null || envio.token().isBlank()) {
            throw new IllegalStateException("El dispositivo no tiene un token push");
        }
        Message mensaje = Message.builder()
                .setToken(envio.token())
                .setNotification(Notification.builder()
                        .setTitle("Turno suspendido")
                        .setBody(envio.contenido())
                        .build())
                .putData("tipo", "SUSPENSION")
                .putData("notificacionId", envio.notificacionId().toString())
                .build();
        FirebaseMessaging.getInstance().send(mensaje);
    }

}
