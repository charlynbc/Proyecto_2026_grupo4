package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.dispositivo.DispositivoRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;

@Service
public class EnvioNotificacionDispatcher {

    private static final Logger log =
            LoggerFactory.getLogger(EnvioNotificacionDispatcher.class);

    private final TurnoFechasRepository repository;
    private final CorreoSender correoSender;
    private final PushSender pushSender;
    private final DispositivoRepository dispositivos;
    private final Clock clock;

    public EnvioNotificacionDispatcher(
            TurnoFechasRepository repository,
            CorreoSender correoSender,
            PushSender pushSender,
            DispositivoRepository dispositivos,
            Clock clock
    ) {
        this.clock = clock;
        this.repository = repository;
        this.correoSender = correoSender;
        this.pushSender = pushSender;
        this.dispositivos = dispositivos;
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
        return repository.bloquearSiguienteEnvioPendiente(OffsetDateTime.now(clock))
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
        } catch (PushTokenNoRegistradoException exception) {
            // FCM dice que el token ya no existe (UNREGISTERED): el envio queda FALLIDO
            // y el dispositivo se deshabilita, en la misma transaccion, para no seguir
            // mandandole avisos. El token no se escribe en el log.
            deshabilitarElToken(envio);
            marcar(envio.envioId(), "FALLIDO");
            log.warn(
                    "El dispositivo del envío {} ya no está registrado en el proveedor; se deshabilitó (notificación de tipo {})",
                    envio.envioId(),
                    envio.tipo()
            );
            return;
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

    /** Un fallo al deshabilitar no impide dejar el envio como FALLIDO. */
    private void deshabilitarElToken(EnvioNotificacion envio) {
        try {
            dispositivos.deshabilitarPorToken(envio.token());
        } catch (RuntimeException exception) {
            log.error(
                    "No se pudo deshabilitar el dispositivo del envío {}; tipo de error: {}",
                    envio.envioId(),
                    exception.getClass().getSimpleName()
            );
        }
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
        Map<String, String> datos = new HashMap<>();
        datos.put("tipo", envio.tipo());
        datos.put("notificacionId", envio.notificacionId().toString());
        // Solo el aviso de historia lleva la atencion, y solo si existe. Firebase
        // exige valores de texto y no admite nulos.
        if ("HISTORIA_ACTUALIZADA".equals(envio.tipo()) && envio.atencionId() != null) {
            datos.put("atencionId", envio.atencionId().toString());
        }
        pushSender.enviar(
                envio.token(),
                NotificacionTextos.titulo(envio.tipo()),
                envio.contenido(),
                datos
        );
    }

}
