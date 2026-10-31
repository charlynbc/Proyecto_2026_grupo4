package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.CancelacionMedicoRepository.DatosConsulta;
import uy.edu.proyecto.backend.agenda.CancelacionMedicoRepository.ResumenCancelable;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.TurnoFecha;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosSuspensionSolicitados;

// RF-27: cancelación de una consulta propia o de todo un turno de una fecha por el médico.
@Service
public class CancelacionMedicoService {

    private static final long HORAS_MINIMAS = 2;
    private static final int MOTIVO_MAX_LENGTH = 1000;

    private final CancelacionMedicoRepository repository;
    private final ConsultaRepository consultaRepository;
    private final TurnoFechasRepository turnoFechas;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public CancelacionMedicoService(CancelacionMedicoRepository repository,
            ConsultaRepository consultaRepository, TurnoFechasRepository turnoFechas,
            ApplicationEventPublisher events, Clock clock) {
        this.repository = repository;
        this.consultaRepository = consultaRepository;
        this.turnoFechas = turnoFechas;
        this.events = events;
        this.clock = clock;
    }

    @Transactional
    public CancelacionDTO cancelarConsulta(Long medicoId, String id, String motivo) {
        String motivoValido = validarMotivo(motivo);
        long consultaId = parsearId(id, "la consulta");
        String ciMedico = ciMedicoHabilitado(medicoId);

        Long socioId = repository.buscarSocioEnConsultaDelMedico(consultaId, medicoId)
                .orElseThrow(this::noEncontrado);
        // Bloqueo en el mismo orden que el resto del circuito: socio, luego consulta.
        if (!consultaRepository.bloquearSocioHabilitado(socioId)) {
            throw noEncontrado();
        }
        DatosConsulta consulta = repository
                .bloquearConsultaDelMedico(consultaId, socioId, medicoId)
                .orElseThrow(this::noEncontrado);

        if (ciMedico.equals(consulta.ciSocio())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CONFLICTO_DE_INTERES",
                    "El médico no puede cancelar su propia consulta");
        }
        if (!"AGENDADA".equals(consulta.estado())) {
            throw conflicto("CONSULTA_NO_AGENDADA",
                    "Solo se puede cancelar una consulta agendada");
        }
        ZonedDateTime ahora = ZonedDateTime.now(clock);
        verificarAnticipacion(consulta.fecha().atTime(consulta.horaInicio())
                .atZone(clock.getZone()), ahora);

        OffsetDateTime canceladaEn = repository
                .cancelarConsulta(consultaId, medicoId, motivoValido)
                .orElseThrow(() -> conflicto("CONSULTA_NO_AGENDADA",
                        "La consulta ya no está agendada"));
        String contenido = "Tu consulta del " + consulta.fecha()
                + " fue cancelada por la institución. Motivo: " + motivoValido;
        Long notificacionId = repository.crearNotificacionCancelacion(consultaId, contenido);
        List<Long> envios = turnoFechas.registrarEnviosNotificacion(
                notificacionId, consulta.socioId(), consulta.correo());
        if (!envios.isEmpty()) {
            events.publishEvent(new EnviosSuspensionSolicitados(List.copyOf(envios)));
        }
        boolean paseDevuelto = consulta.venceElPase() != null
                && !consulta.venceElPase().isBefore(ahora.toLocalDate());
        return new CancelacionDTO(consultaId, "CANCELADA_INSTITUCION", canceladaEn, paseDevuelto);
    }

    @Transactional
    public CancelacionTurnoMedicoDTO cancelarTurno(Long medicoId, String id, String motivo) {
        String motivoValido = validarMotivo(motivo);
        long turnoId = parsearId(id, "el turno");
        String ciMedico = ciMedicoHabilitado(medicoId);

        // Mismo orden de bloqueo que la suspensión del funcionario: turno, números, consultas.
        List<Long> ids = List.of(turnoId);
        if (turnoFechas.bloquearTurnos(ids).isEmpty()) {
            throw noEncontrado();
        }
        TurnoFecha turno = turnoFechas.buscarTurnos(ids).getFirst();
        if (!turno.medicoId().equals(medicoId)) {
            throw noEncontrado();
        }
        LocalDate hoy = LocalDate.now(clock);
        if (!"ACTIVO".equals(turno.estado()) || turno.fecha().isBefore(hoy)) {
            throw conflicto("TURNO_NO_SUSPENDIBLE",
                    "El turno debe estar activo y ser de hoy o una fecha futura");
        }

        turnoFechas.bloquearNumerosDeTurnos(ids);
        List<ConsultaParaCancelar> consultas = turnoFechas.bloquearConsultasAgendadas(ids);

        Map<Long, ResumenCancelable> resumen = consultas.isEmpty()
                ? Map.of()
                : repository.resumenCancelables(
                        consultas.stream().map(ConsultaParaCancelar::id).toList())
                        .stream()
                        .collect(Collectors.toMap(ResumenCancelable::consultaId,
                                Function.identity()));
        for (ConsultaParaCancelar consulta : consultas) {
            ResumenCancelable datos = resumen.get(consulta.id());
            if (datos != null && ciMedico.equals(datos.ciSocio())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "CONFLICTO_DE_INTERES",
                        "El médico no puede cancelar sus propias consultas");
            }
        }
        // Se verifica la anticipación de todas las consultas antes de modificar cualquier dato.
        ZonedDateTime ahora = ZonedDateTime.now(clock);
        for (ConsultaParaCancelar consulta : consultas) {
            verificarAnticipacion(
                    consulta.fecha().atTime(consulta.horaInicio()).atZone(clock.getZone()),
                    ahora);
        }

        Long eventoId = turnoFechas.crearEvento(turnoId, medicoId, "SUSPENSION", motivoValido);
        turnoFechas.actualizarEstadoTurno(turnoId, "SUSPENDIDO");

        OffsetDateTime canceladaEn = OffsetDateTime.now(clock);
        List<Long> envios = new ArrayList<>();
        int pasesDevueltos = 0;
        for (ConsultaParaCancelar consulta : consultas) {
            if (turnoFechas.cancelarConsulta(consulta.id(), medicoId, canceladaEn,
                    motivoValido, eventoId) != 1) {
                throw new IllegalStateException(
                        "La consulta dejó de estar AGENDADA mientras se cancelaba");
            }
            String contenido = "Tu consulta del " + consulta.fecha()
                    + " fue cancelada por la institución. Horario: "
                    + consulta.horaInicio() + " a " + consulta.horaFin()
                    + " (número " + consulta.numero() + "). Motivo: " + motivoValido;
            Long notificacionId = turnoFechas.crearNotificacionSuspension(
                    consulta.id(), contenido);
            envios.addAll(turnoFechas.registrarEnviosNotificacion(
                    notificacionId, consulta.socioId(), consulta.correo()));
            ResumenCancelable datos = resumen.get(consulta.id());
            if (datos != null && datos.venceElPase() != null
                    && !datos.venceElPase().isBefore(hoy)) {
                pasesDevueltos++;
            }
        }
        if (!envios.isEmpty()) {
            events.publishEvent(new EnviosSuspensionSolicitados(List.copyOf(envios)));
        }
        return new CancelacionTurnoMedicoDTO(
                turnoId, turno.fecha(), "SUSPENDIDO", consultas.size(), pasesDevueltos);
    }

    private void verificarAnticipacion(ZonedDateTime inicio, ZonedDateTime ahora) {
        if (inicio.isBefore(ahora.plusHours(HORAS_MINIMAS))) {
            throw conflicto("CANCELACION_FUERA_DE_PLAZO",
                    "Faltan menos de 2 horas para la hora del número");
        }
    }

    private String validarMotivo(String motivo) {
        if (motivo == null || motivo.isBlank()) {
            throw validacion("motivo es obligatorio");
        }
        String limpio = motivo.trim();
        if (limpio.length() > MOTIVO_MAX_LENGTH) {
            throw validacion("motivo no puede superar 1000 caracteres");
        }
        return limpio;
    }

    private long parsearId(String id, String recurso) {
        long valor;
        try {
            valor = Long.parseLong(id);
        } catch (NumberFormatException exception) {
            throw validacion("El identificador de " + recurso + " debe ser positivo");
        }
        if (valor <= 0) {
            throw validacion("El identificador de " + recurso + " debe ser positivo");
        }
        return valor;
    }

    private String ciMedicoHabilitado(Long medicoId) {
        if (medicoId == null || medicoId <= 0) {
            throw validacion("El médico autenticado no es válido");
        }
        return repository.ciMedico(medicoId)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "ACCESO_DENEGADO",
                        "La cuenta no puede cancelar consultas"));
    }

    // Consulta o turno ajeno e inexistente responden igual para no revelar su existencia.
    private ApiException noEncontrado() {
        return new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO",
                "No existe la consulta o el turno indicado para este médico");
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }

    private ApiException conflicto(String codigo, String mensaje) {
        return new ApiException(HttpStatus.CONFLICT, codigo, mensaje);
    }
}
