package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZonedDateTime;
import java.util.List;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosSuspensionSolicitados;

@Service
public class CancelacionFuncionarioService {
    private final CancelacionFuncionarioRepository repository;
    private final ConsultaRepository consultaRepository;
    private final TurnoFechasRepository notificaciones;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public CancelacionFuncionarioService(CancelacionFuncionarioRepository repository,
            ConsultaRepository consultaRepository, TurnoFechasRepository notificaciones,
            ApplicationEventPublisher events, Clock clock) {
        this.repository = repository;
        this.consultaRepository = consultaRepository;
        this.notificaciones = notificaciones;
        this.events = events;
        this.clock = clock;
    }

    @Transactional
    public CancelacionDTO cancelar(Long funcionarioId, String id) {
        Long consultaId;
        try {
            consultaId = Long.valueOf(id);
        } catch (NumberFormatException exception) {
            throw validacion();
        }
        if (consultaId <= 0 || funcionarioId == null || funcionarioId <= 0) {
            throw validacion();
        }

        String ciFuncionario = repository.ciFuncionario(funcionarioId)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "ACCESO_DENEGADO",
                        "La cuenta no puede cancelar consultas"));
        Long socioId = repository.buscarSocio(consultaId).orElseThrow(this::noEncontrado);
        // Bloqueo en el mismo orden que el resto del circuito: socio, luego consulta.
        if (!consultaRepository.bloquearSocioHabilitado(socioId)) {
            throw noEncontrado();
        }
        var consulta = repository.bloquearConsulta(consultaId, socioId)
                .orElseThrow(this::noEncontrado);

        if (ciFuncionario.equals(consulta.ciSocio())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CONFLICTO_INTERES",
                    "Un funcionario no puede cancelar su propia consulta");
        }
        if (!"AGENDADA".equals(consulta.estado())) {
            throw new ApiException(HttpStatus.CONFLICT, "CONSULTA_NO_AGENDADA",
                    "Solo se puede cancelar una consulta agendada");
        }
        ZonedDateTime ahora = ZonedDateTime.now(clock);
        ZonedDateTime inicio = consulta.fecha().atTime(consulta.horaInicio())
                .atZone(clock.getZone());
        if (inicio.isBefore(ahora.plusHours(2))) {
            throw new ApiException(HttpStatus.CONFLICT, "CANCELACION_FUERA_DE_PLAZO",
                    "Faltan menos de 2 horas para la consulta");
        }

        OffsetDateTime canceladaEn = repository.cancelar(consultaId, funcionarioId)
                .orElseThrow(() -> new ApiException(HttpStatus.CONFLICT,
                        "CONSULTA_NO_AGENDADA", "La consulta ya no está agendada"));
        Long notificacionId = repository.crearNotificacion(consultaId, consulta.fecha());
        List<Long> envios = notificaciones.registrarEnviosNotificacion(
                notificacionId, consulta.socioId(), consulta.correo());
        if (!envios.isEmpty()) {
            events.publishEvent(new EnviosSuspensionSolicitados(List.copyOf(envios)));
        }
        boolean paseDevuelto = consulta.venceElPase() != null
                && !consulta.venceElPase().isBefore(ahora.toLocalDate());
        return new CancelacionDTO(consultaId, "CANCELADA_SOCIO", canceladaEn, paseDevuelto);
    }

    private ApiException validacion() {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                "El identificador de la consulta y el funcionario deben ser positivos");
    }

    private ApiException noEncontrado() {
        return new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO",
                "No existe la consulta indicada");
    }
}
