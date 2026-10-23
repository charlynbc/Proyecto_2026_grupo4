package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.context.ApplicationEventPublisher;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.NumeroExistente;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.RecursoTurno;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.TurnoFecha;

@Service
public class TurnoFechasService {

    private static final int OBSERVACION_MAX_LENGTH = 1000;

    private final TurnoFechasRepository repository;
    private final Clock clock;
    private final ApplicationEventPublisher eventPublisher;

    public TurnoFechasService(
            TurnoFechasRepository repository,
            Clock clock,
            ApplicationEventPublisher eventPublisher
    ) {
        this.repository = repository;
        this.clock = clock;
        this.eventPublisher = eventPublisher;
    }

    @Transactional(readOnly = true)
    public VistaPreviaSuspensionDTO previsualizar(
            PrevisualizarSuspensionRequest request
    ) {
        List<Long> ids = validarIds(request == null ? null : request.ids());
        List<TurnoFecha> turnos = repository.buscarTurnos(ids);
        validarTodosExisten(ids, turnos.stream().map(TurnoFecha::id).toList());
        validarSuspendibles(turnos);
        List<VistaPreviaSuspensionDTO.FechaAfectada> fechas = turnos.stream()
                .map(turno -> new VistaPreviaSuspensionDTO.FechaAfectada(
                        turno.id(),
                        turno.fecha(),
                        turno.horaInicio(),
                        turno.horaFin(),
                        turno.consultasAgendadas()
                ))
                .toList();
        return new VistaPreviaSuspensionDTO(
                fechas,
                sumarConsultas(turnos)
        );
    }

    @Transactional
    public ResultadoFechasDTO suspender(
            SuspenderFechasRequest request,
            Long funcionarioId
    ) {
        validarFuncionario(funcionarioId);
        if (request == null || request.cantidadConfirmada() == null
                || request.cantidadConfirmada() < 0) {
            throw validacion("cantidadConfirmada debe ser un entero mayor o igual a cero");
        }
        FiltroFechas filtro = validarFiltro(request.filtro());
        List<Long> ids = validarIds(request.ids());
        String observacion = normalizarObservacion(request.observacion());

        bloquearSeleccion(ids);
        List<TurnoFecha> turnos = repository.buscarTurnos(ids);
        validarTodosExisten(ids, turnos.stream().map(TurnoFecha::id).toList());
        validarFiltroCoincide(filtro, turnos);
        validarSuspendibles(turnos);

        repository.bloquearNumerosDeTurnos(ids);
        List<ConsultaParaCancelar> consultas =
                repository.bloquearConsultasAgendadas(ids);
        if (consultas.size() != request.cantidadConfirmada()) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONFIRMACION_DESACTUALIZADA",
                    "La cantidad de consultas cambió. Actualizá la vista previa."
            );
        }

        OffsetDateTime ahora = OffsetDateTime.now(clock);
        List<Long> envios = new ArrayList<>();
        for (TurnoFecha turno : turnos) {
            Long eventoId = repository.crearEvento(
                    turno.id(),
                    funcionarioId,
                    "SUSPENSION",
                    observacion
            );
            repository.actualizarEstadoTurno(turno.id(), "SUSPENDIDO");
            for (ConsultaParaCancelar consulta : consultas) {
                if (!consulta.turnoId().equals(turno.id())) {
                    continue;
                }
                if (repository.cancelarConsulta(
                        consulta.id(),
                        funcionarioId,
                        ahora,
                        observacion,
                        eventoId
                ) != 1) {
                    throw new IllegalStateException(
                            "La consulta dejó de estar AGENDADA mientras se suspendía"
                    );
                }
                String contenido = contenidoNotificacion(
                        consulta,
                        turno,
                        observacion
                );
                Long notificacionId = repository.crearNotificacionSuspension(
                        consulta.id(),
                        contenido
                );
                envios.addAll(repository.registrarEnviosNotificacion(
                        notificacionId,
                        consulta.socioId(),
                        consulta.correo()
                ));
            }
        }

        if (!envios.isEmpty()) {
            eventPublisher.publishEvent(new EnviosSuspensionSolicitados(List.copyOf(envios)));
        }
        return new ResultadoFechasDTO(
                turnos.stream()
                        .map(turno -> new ResultadoFechasDTO.TurnoProcesado(
                                turno.id(),
                                turno.fecha()
                        ))
                        .toList(),
                consultas.size()
        );
    }

    @Transactional
    public ResultadoFechasDTO rehabilitar(
            RehabilitarFechasRequest request,
            Long funcionarioId
    ) {
        validarFuncionario(funcionarioId);
        if (request == null) {
            throw validacion("La solicitud es obligatoria");
        }
        FiltroFechas filtro = validarFiltro(request.filtro());
        List<Long> ids = validarIds(request.ids());

        List<TurnoFecha> iniciales = repository.buscarTurnos(ids);
        validarTodosExisten(ids, iniciales.stream().map(TurnoFecha::id).toList());
        validarFiltroCoincide(filtro, iniciales);

        List<RecursoTurno> recursosIniciales = repository.buscarRecursos(ids);
        List<Long> medicos = repository.idsMedicos(recursosIniciales);
        List<Long> consultorios = repository.idsConsultorios(recursosIniciales);
        repository.bloquearMedicos(medicos);
        repository.bloquearConsultorios(consultorios);
        bloquearSeleccion(ids);

        List<TurnoFecha> turnos = repository.buscarTurnos(ids);
        validarTodosExisten(ids, turnos.stream().map(TurnoFecha::id).toList());
        validarFiltroCoincide(filtro, turnos);
        validarRehabilitables(turnos);

        List<RecursoTurno> recursos = repository.buscarRecursos(ids);
        validarMedicosActivos(recursos);
        validarSolapamientos(ids, recursos);

        for (TurnoFecha turno : turnos) {
            repository.crearEvento(
                    turno.id(),
                    funcionarioId,
                    "REHABILITACION",
                    null
            );
            repository.actualizarEstadoTurno(turno.id(), "ACTIVO");
        }
        return new ResultadoFechasDTO(
                turnos.stream()
                        .map(turno -> new ResultadoFechasDTO.TurnoProcesado(
                                turno.id(),
                                turno.fecha()
                        ))
                        .toList(),
                0
        );
    }

    private void bloquearSeleccion(List<Long> ids) {
        List<Long> bloqueados = repository.bloquearTurnos(ids);
        validarTodosExisten(ids, bloqueados);
    }

    private List<Long> validarIds(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            throw validacion("ids debe contener al menos un turno");
        }
        Set<Long> unicos = new HashSet<>();
        for (Long id : ids) {
            if (id == null || id <= 0) {
                throw validacion("Cada id debe ser un entero positivo");
            }
            if (!unicos.add(id)) {
                throw validacion("ids no puede contener valores duplicados");
            }
        }
        return ids.stream().sorted().toList();
    }

    private FiltroFechas validarFiltro(FiltroFechasRequest request) {
        if (request == null || request.medicoId() == null
                || request.medicoId() <= 0
                || request.especialidadId() == null
                || request.especialidadId() <= 0
                || request.fechaDesde() == null
                || request.fechaHasta() == null) {
            throw validacion("filtro requiere médico, especialidad y rango de fechas");
        }
        LocalDate desde = parsearFecha(request.fechaDesde(), "fechaDesde");
        LocalDate hasta = parsearFecha(request.fechaHasta(), "fechaHasta");
        if (desde.isAfter(hasta)) {
            throw validacion("fechaDesde no puede ser posterior a fechaHasta");
        }
        return new FiltroFechas(
                request.medicoId(),
                request.especialidadId(),
                desde,
                hasta
        );
    }

    private LocalDate parsearFecha(String value, String campo) {
        try {
            return LocalDate.parse(value);
        } catch (java.time.format.DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato YYYY-MM-DD");
        }
    }

    private void validarFiltroCoincide(FiltroFechas filtro, List<TurnoFecha> turnos) {
        if (turnos.stream().anyMatch(turno ->
                !turno.medicoId().equals(filtro.medicoId())
                        || !turno.especialidadId().equals(filtro.especialidadId())
                        || turno.fecha().isBefore(filtro.fechaDesde())
                        || turno.fecha().isAfter(filtro.fechaHasta()))) {
            throw validacion("Todos los turnos deben coincidir con filtro");
        }
    }

    private void validarSuspendibles(List<TurnoFecha> turnos) {
        LocalDate hoy = LocalDate.now(clock);
        if (turnos.stream().anyMatch(turno ->
                !"ACTIVO".equals(turno.estado()) || turno.fecha().isBefore(hoy))) {
            throw conflicto(
                    "TURNO_NO_SUSPENDIBLE",
                    "Todos los turnos deben estar activos y ser de hoy o una fecha futura"
            );
        }
    }

    private void validarRehabilitables(List<TurnoFecha> turnos) {
        LocalDate hoy = LocalDate.now(clock);
        if (turnos.stream().anyMatch(turno ->
                !"SUSPENDIDO".equals(turno.estado()) || turno.fecha().isBefore(hoy))) {
            throw conflicto(
                    "TURNO_NO_REHABILITABLE",
                    "Todos los turnos deben estar suspendidos y ser de hoy o una fecha futura"
            );
        }
    }

    private void validarMedicosActivos(List<RecursoTurno> recursos) {
        if (recursos.stream().anyMatch(recurso -> !recurso.medicoHabilitado())) {
            throw conflicto(
                    "MEDICO_INACTIVO",
                    "No se puede rehabilitar una fecha de un médico inactivo"
            );
        }
    }

    private void validarSolapamientos(List<Long> ids, List<RecursoTurno> recursos) {
        Set<Long> seleccionados = Set.copyOf(ids);
        Set<Long> medicos = recursos.stream()
                .map(RecursoTurno::medicoId)
                .collect(java.util.stream.Collectors.toSet());
        Set<Long> consultorios = recursos.stream()
                .map(RecursoTurno::consultorioId)
                .collect(java.util.stream.Collectors.toSet());
        if (recursos.isEmpty()) {
            return;
        }
        LocalDate desde = recursos.stream().map(RecursoTurno::fecha).min(LocalDate::compareTo)
                .orElseThrow();
        LocalDate hasta = recursos.stream().map(RecursoTurno::fecha).max(LocalDate::compareTo)
                .orElseThrow();
        List<NumeroExistente> existentes = repository.buscarNumerosActivosEnFechas(
                ids,
                medicos.stream().sorted().toList(),
                consultorios.stream().sorted().toList(),
                desde,
                hasta
        );

        for (int i = 0; i < recursos.size(); i++) {
            RecursoTurno actual = recursos.get(i);
            if (actual.numeroId() == null) {
                continue;
            }
            for (int j = i + 1; j < recursos.size(); j++) {
                RecursoTurno otro = recursos.get(j);
                if (!seleccionados.contains(otro.turnoId())
                        || actual.turnoId().equals(otro.turnoId())
                        || otro.numeroId() == null) {
                    continue;
                }
                if (seSolapan(actual.fecha(), actual.medicoId(), actual.consultorioId(),
                        actual.horaInicio(), actual.horaFin(), otro.fecha(),
                        otro.medicoId(), otro.consultorioId(),
                        otro.horaInicio(), otro.horaFin())) {
                    throw solapamiento();
                }
            }
            for (NumeroExistente otro : existentes) {
                if (seSolapan(actual.fecha(), actual.medicoId(), actual.consultorioId(),
                        actual.horaInicio(), actual.horaFin(), otro.fecha(),
                        otro.medicoId(), otro.consultorioId(),
                        otro.horaInicio(), otro.horaFin())) {
                    throw solapamiento();
                }
            }
        }
    }

    private boolean seSolapan(
            LocalDate fechaA,
            Long medicoA,
            Long consultorioA,
            java.time.LocalTime inicioA,
            java.time.LocalTime finA,
            LocalDate fechaB,
            Long medicoB,
            Long consultorioB,
            java.time.LocalTime inicioB,
            java.time.LocalTime finB
    ) {
        return fechaA.equals(fechaB)
                && (medicoA.equals(medicoB) || consultorioA.equals(consultorioB))
                && inicioA.isBefore(finB)
                && inicioB.isBefore(finA);
    }

    private ApiException solapamiento() {
        return conflicto(
                "SOLAPAMIENTO_TURNO",
                "Los números se solapan con otro turno activo"
        );
    }

    private String normalizarObservacion(String observacion) {
        if (observacion == null || observacion.isBlank()) {
            return null;
        }
        String limpia = observacion.trim();
        if (limpia.length() > OBSERVACION_MAX_LENGTH) {
            throw validacion("observacion no puede superar 1000 caracteres");
        }
        return limpia;
    }

    private String contenidoNotificacion(
            ConsultaParaCancelar consulta,
            TurnoFecha turno,
            String observacion
    ) {
        StringBuilder contenido = new StringBuilder(
                "Tu consulta del " + turno.fecha()
                        + " fue cancelada por la institución."
        );
        if (consulta.horaInicio() != null) {
            contenido.append(" Horario: ")
                    .append(consulta.horaInicio())
                    .append(" a ")
                    .append(consulta.horaFin())
                    .append(" (número ")
                    .append(consulta.numero())
                    .append(").");
        }
        if (observacion != null) {
            contenido.append(" ").append(observacion);
        }
        return contenido.toString();
    }

    private int sumarConsultas(List<TurnoFecha> turnos) {
        return Math.toIntExact(
                turnos.stream()
                        .mapToLong(TurnoFecha::consultasAgendadas)
                        .sum()
        );
    }

    private void validarFuncionario(Long funcionarioId) {
        if (funcionarioId == null || funcionarioId <= 0) {
            throw validacion("El funcionario autenticado no es válido");
        }
    }

    private void validarTodosExisten(List<Long> solicitados, List<Long> encontrados) {
        if (encontrados.size() != solicitados.size()
                || !new HashSet<>(encontrados).containsAll(solicitados)) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND,
                    "NO_ENCONTRADO",
                    "No existe uno o más turnos indicados"
            );
        }
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }

    private ApiException conflicto(String codigo, String mensaje) {
        return new ApiException(HttpStatus.CONFLICT, codigo, mensaje);
    }

    private record FiltroFechas(
            Long medicoId,
            Long especialidadId,
            LocalDate fechaDesde,
            LocalDate fechaHasta
    ) {
    }

    public record EnviosSuspensionSolicitados(List<Long> envioIds) {
    }
}
