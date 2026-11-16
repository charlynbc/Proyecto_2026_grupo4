package uy.edu.proyecto.backend.notificacion;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;

@Service
public class EnvioNotificacionDispatcher {

    private static final Logger log =
            LoggerFactory.getLogger(EnvioNotificacionDispatcher.class);

    private final TurnoFechasRepository repository;
    private final CorreoSender correoSender;
    private final PushSender pushSender;

    public EnvioNotificacionDispatcher(
            TurnoFechasRepository repository,
            CorreoSender correoSender,
            PushSender pushSender
    ) {
        this.repository = repository;
        this.correoSender = correoSender;
        this.pushSender = pushSender;
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
                        NotificacionTextos.titulo(envio.tipo()),
                        envio.contenido()
                ));
            } else if ("PUSH".equals(envio.canal())) {
                enviarPush(envio);
            } else {
                throw new IllegalStateException(
                        "Canal de notificación no soportado: " + envio.canal()
                );
            }
        } catch (RuntimeException exception) {
            // RNF-24: cualquier falla del proveedor queda registrada en el envio
            // (estado, intentos y ultimo intento) en vez de salir como excepcion;
            // si no, el envio quedaria PENDIENTE y el poller lo reintentaria para
            // siempre, frenando a los que vienen detras.
            marcar(envio.envioId(), "FALLIDO");
            log.error(
                    "No se pudo entregar la notificación {} de tipo {} por canal {}; tipo de error: {}",
                    envio.notificacionId(),
                    envio.tipo(),
                    envio.canal(),
                    exception.getClass().getSimpleName()
            );
            return;
        }
        marcar(envio.envioId(), "ENVIADO");
        log.info(
                "El proveedor aceptó la notificación {} de tipo {} por canal {}",
                envio.notificacionId(),
                envio.tipo(),
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

    private void enviarPush(EnvioNotificacion envio) {
        if (envio.token() == null || envio.token().isBlank()) {
            throw new IllegalStateException("El dispositivo no tiene un token push");
        }
        pushSender.enviar(
                envio.token(),
                NotificacionTextos.titulo(envio.tipo()),
                envio.contenido(),
                Map.of(
                        "tipo", envio.tipo(),
                        "notificacionId", envio.notificacionId().toString()
                )
        );
    }

}
