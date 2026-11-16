package uy.edu.proyecto.backend.notificacion;

import java.util.List;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

/**
 * Crea los envios (un correo si el socio tiene correo y un push por cada
 * dispositivo habilitado) de una notificacion ya guardada, y pide su entrega.
 *
 * Se llama dentro de la transaccion de la operacion que origina el aviso. La
 * entrega real ocurre despues del commit (EnvioNotificacionListener), asi que
 * una falla del correo o del push no revierte ni bloquea la operacion (RNF-24).
 */
@Component
public class NotificacionEnvios {

    private final TurnoFechasRepository repository;
    private final ApplicationEventPublisher events;

    public NotificacionEnvios(
            TurnoFechasRepository repository,
            ApplicationEventPublisher events
    ) {
        this.repository = repository;
        this.events = events;
    }

    public void solicitar(Long notificacionId, Long socioId) {
        String correo = repository.correoDelSocio(socioId).orElse(null);
        List<Long> envios = repository.registrarEnviosNotificacion(
                notificacionId, socioId, correo);
        if (!envios.isEmpty()) {
            events.publishEvent(new EnviosNotificacionSolicitados(List.copyOf(envios)));
        }
    }
}
