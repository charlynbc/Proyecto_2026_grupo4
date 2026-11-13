package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.CuentaMedica;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroExistente;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroInstancia;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.PatronSemanal;

@Service
public class TurnoSemanalService {

    private static final DateTimeFormatter HORA_FORMATO =
            DateTimeFormatter.ofPattern("HH:mm");
    private static final ZoneId ZONA = ZoneId.of("America/Montevideo");

    private final TurnoSemanalRepository repository;
    private final TurnoConsultaRepository consultaRepository;
    private final Clock clock;

    public TurnoSemanalService(
            TurnoSemanalRepository repository,
            TurnoConsultaRepository consultaRepository,
            Clock clock
    ) {
        this.repository = repository;
        this.consultaRepository = consultaRepository;
        this.clock = clock;
    }

    @Transactional
    public TurnoSemanalResponse crear(
            AltaTurnoSemanalRequest request,
            Long idFuncionario
    ) {
        validarSolicitud(request, idFuncionario);

        List<NumeroValidado> numeros = validarNumeros(request.numeros());
        List<LocalDate> fechas = generarFechas(request);
        CuentaMedica medico = repository.bloquearMedico(request.medicoId())
                .orElseThrow(() -> noEncontrado("No existe el médico indicado"));

        if (!"MEDICO".equals(medico.rol())) {
            throw noEncontrado("No existe el médico indicado");
        }
        if (!medico.habilitada()) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "MEDICO_INACTIVO",
                    "El médico no está activo"
            );
        }

        Consultorio consultorio = repository
                .bloquearConsultorio(request.consultorioId())
                .orElseThrow(() -> noEncontrado(
                        "No existe el consultorio indicado"
                ));
        Especialidad especialidad = repository
                .buscarEspecialidadDelMedico(
                        request.medicoId(),
                        request.especialidadId()
                )
                .orElseThrow(() -> new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "ESPECIALIDAD_NO_DEL_MEDICO",
                        "La especialidad no está asociada al médico"
                ));

        validarSolapamientos(request, numeros, fechas);

        Long idPatron = repository.crearPatron(
                request.medicoId(),
                request.especialidadId(),
                request.consultorioId(),
                idFuncionario,
                request.diaSemana(),
                request.fechaInicio(),
                request.fechaFin()
        );

        List<TurnoSemanalResponse.NumeroSemanalResponse> respuestaNumeros =
                new ArrayList<>();
        List<NumeroInstancia> instancias = new ArrayList<>();
        for (NumeroValidado numero : numeros) {
            Long idNumeroSemanal = repository.crearNumeroSemanal(
                    idPatron,
                    numero.numero(),
                    numero.horaInicio(),
                    numero.horaFin()
            );
            instancias.add(new NumeroInstancia(
                    idNumeroSemanal,
                    numero.numero(),
                    numero.horaInicio(),
                    numero.horaFin()
            ));
            respuestaNumeros.add(
                    new TurnoSemanalResponse.NumeroSemanalResponse(
                            numero.numero(),
                            numero.horaInicio().format(HORA_FORMATO),
                            numero.horaFin().format(HORA_FORMATO)
                    )
            );
        }

        for (LocalDate fecha : fechas) {
            Long idTurno = repository.crearTurno(
                    idPatron,
                    request.consultorioId(),
                    fecha
            );
            repository.crearNumeros(idTurno, instancias);
        }

        return new TurnoSemanalResponse(
                idPatron,
                new TurnoSemanalResponse.MedicoRef(
                        medico.id(),
                        medico.nombre(),
                        medico.apellido()
                ),
                especialidad,
                consultorio,
                request.diaSemana(),
                request.fechaInicio(),
                request.fechaFin(),
                List.copyOf(respuestaNumeros),
                fechas.size()
        );
    }

    /**
     * RF-20: vista previa no persistente, válida para turnos ACTIVOS y
     * SUSPENDIDOS. Los cruces de fechas suspendidas se revalidan en RF-15.
     */
    @Transactional(readOnly = true)
    public VistaPreviaConsultorioResponse vistaPreviaConsultorio(
            Long idPatron, ModificarTurnoSemanalRequest request
    ) {
        validarCambioConsultorio(idPatron, request);
        PatronSemanal patron = repository.obtenerPatronSinBloqueo(idPatron)
                .orElseThrow(() -> noEncontrado(
                        "No existe el turno semanal indicado"
                ));
        repository.obtenerConsultorioSinBloqueo(request.consultorioId())
                .orElseThrow(() -> noEncontrado(
                        "No existe el consultorio indicado"
                ));
        LocalDate hoy = LocalDate.now(clock.withZone(ZONA));
        List<TurnoSemanalRepository.FechaTurno> fechas =
                repository.listarFechasDesde(idPatron, hoy, false);
        java.util.Map<Long, Integer> agendadas =
                repository.contarAgendadasPorFecha(idPatron, hoy);
        var solapamientos = solapamientosPorFecha(
                patron, request.consultorioId(), fechas
        );
        List<VistaPreviaConsultorioResponse.Fecha> respuesta = new ArrayList<>();
        for (var fecha : fechas) {
            respuesta.add(new VistaPreviaConsultorioResponse.Fecha(
                    fecha.turnoId(),
                    fecha.fecha(),
                    fecha.estado(),
                    agendadas.getOrDefault(fecha.turnoId(), 0),
                    fecha.consultorio(),
                    solapamientos.getOrDefault(fecha.fecha(), List.of())
            ));
        }
        return new VistaPreviaConsultorioResponse(List.copyOf(respuesta));
    }

    private void validarCambioConsultorio(
            Long idPatron, ModificarTurnoSemanalRequest request
    ) {
        if (idPatron == null || idPatron <= 0
                || request == null || request.consultorioId() == null
                || request.consultorioId() <= 0) {
            throw validacion("Faltan datos obligatorios o no son válidos");
        }
    }

    /**
     * Cambio parcial atómico: no se aceptan IDs de otras configuraciones,
     * fechas pasadas, duplicados ni conflictos. No cancela consultas.
     */
    private TurnoSemanalResponse modificarConsultorioPorFechas(
            Long idPatron, ModificarTurnoSemanalRequest request
    ) {
        PatronSemanal patron = repository.bloquearPatron(idPatron)
                .orElseThrow(() -> noEncontrado(
                        "No existe el turno semanal indicado"
                ));
        Consultorio consultorioNuevo = repository
                .bloquearConsultorio(request.consultorioId())
                .orElseThrow(() -> noEncontrado(
                        "No existe el consultorio indicado"
                ));
        LocalDate hoy = LocalDate.now(clock.withZone(ZONA));
        // Bloqueo FOR UPDATE de las mismas filas que la reserva de consultas.
        List<TurnoSemanalRepository.FechaTurno> futuras =
                repository.listarFechasDesde(idPatron, hoy, true);
        if (futuras.isEmpty()) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "TURNO_NO_MODIFICABLE",
                    "El turno semanal ya finalizó; no tiene fechas actuales"
                            + " ni futuras por modificar"
            );
        }

        List<Long> solicitados = request.turnoIds();
        if (solicitados != null) {
            if (solicitados.isEmpty()
                    || solicitados.stream().anyMatch(
                            id -> id == null || id <= 0
                    )
                    || new HashSet<>(solicitados).size() != solicitados.size()) {
                throw validacion("turnoIds debe incluir IDs válidos y únicos");
            }
            Set<Long> disponibles = futuras.stream()
                    .map(TurnoSemanalRepository.FechaTurno::turnoId)
                    .collect(Collectors.toSet());
            if (!disponibles.containsAll(solicitados)) {
                throw validacion(
                        "Los turnoIds deben pertenecer al patrón y ser de hoy en adelante"
                );
            }
        }

        Set<Long> elegidos = solicitados == null
                ? futuras.stream()
                    .map(TurnoSemanalRepository.FechaTurno::turnoId)
                    .collect(Collectors.toSet())
                : new HashSet<>(solicitados);
        List<TurnoSemanalRepository.FechaTurno> seleccionadas = futuras
                .stream().filter(fecha -> elegidos.contains(fecha.turnoId()))
                .toList();
        List<TurnoSemanalRepository.FechaTurno> modificadas = seleccionadas
                .stream()
                .filter(fecha -> !fecha.consultorio().id()
                        .equals(consultorioNuevo.id()))
                .toList();

        // La confirmación no autoriza forzar solapamientos.
        var cruces = solapamientosPorFecha(
                patron, consultorioNuevo.id(), modificadas
        );
        if (!cruces.isEmpty()) {
            String detalles = cruces.entrySet().stream()
                    .flatMap(entrada -> entrada.getValue().stream().map(
                            numero -> "fecha " + entrada.getKey()
                                    + ", número " + numero.numeroPropio()
                                    + " con número existente "
                                    + numero.numeroExistente()
                    ))
                    .collect(Collectors.joining("; "));
            throw new ApiException(
                    HttpStatus.CONFLICT, "SOLAPAMIENTO_TURNO",
                    "Se encontraron solapamientos: " + detalles
            );
        }

        java.util.Map<Long, Integer> agendadas =
                repository.contarAgendadasPorFecha(idPatron, hoy);
        List<LocalDate> fechasConConsultas = modificadas.stream()
                .filter(fecha -> agendadas.getOrDefault(
                        fecha.turnoId(), 0
                ) > 0)
                .map(TurnoSemanalRepository.FechaTurno::fecha)
                .toList();
        if (!fechasConConsultas.isEmpty()
                && !Boolean.TRUE.equals(request.confirmarConConsultas())) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "TURNO_NO_MODIFICABLE",
                    "Hay consultas agendadas en las fechas "
                            + fechasConConsultas + ". Confirmá el cambio"
                            + " para continuar."
            );
        }

        repository.actualizarConsultorioDeFechas(
                idPatron,
                consultorioNuevo.id(),
                modificadas.stream()
                        .map(TurnoSemanalRepository.FechaTurno::turnoId)
                        .toList(),
                hoy
        );
        // Una secuencia de cambios parciales también puede terminar dejando
        // todas las fechas futuras en el mismo consultorio. En ese caso
        // sincronizamos el patrón, aunque esta solicitud elija solo algunas.
        boolean todasEnDestino = futuras.stream().allMatch(fecha ->
                elegidos.contains(fecha.turnoId())
                        || fecha.consultorio().id().equals(consultorioNuevo.id())
        );
        if (todasEnDestino
                && !patron.idConsultorio().equals(consultorioNuevo.id())) {
            repository.actualizarConsultorioDelPatron(
                    idPatron, consultorioNuevo.id()
            );
        }
        return consultaRepository.obtenerPatron(idPatron)
                .orElseThrow(() -> noEncontrado(
                        "No existe el turno semanal indicado"
                ));
    }

    private java.util.Map<LocalDate,
            List<VistaPreviaConsultorioResponse.Solapamiento>>
            solapamientosPorFecha(
                    PatronSemanal patron,
                    Long consultorioNuevo,
                    List<TurnoSemanalRepository.FechaTurno> fechas
            ) {
        List<LocalDate> fechasActivas = fechas.stream()
                .filter(fecha -> "ACTIVO".equals(fecha.estado()))
                .map(TurnoSemanalRepository.FechaTurno::fecha)
                .distinct().sorted().toList();
        if (fechasActivas.isEmpty()) {
            return java.util.Map.of();
        }
        List<NumeroInstancia> propios =
                repository.numerosDelPatron(patron.id());
        List<NumeroExistente> existentes =
                repository.buscarNumerosActivosDeOtrosPatrones(
                        patron.idMedico(), consultorioNuevo,
                        fechasActivas.getFirst(),
                        fechasActivas.getLast(),
                        patron.id()
                );
        Set<LocalDate> fechasElegidas = new HashSet<>(fechasActivas);
        java.util.Map<LocalDate,
                java.util.Set<VistaPreviaConsultorioResponse.Solapamiento>>
                conflictos = new java.util.LinkedHashMap<>();
        for (NumeroExistente existente : existentes) {
            if (!fechasElegidas.contains(existente.fecha())) {
                continue;
            }
            if (!existente.idMedico().equals(patron.idMedico())
                    && !existente.idConsultorio().equals(consultorioNuevo)) {
                continue;
            }
            for (NumeroInstancia propio : propios) {
                boolean seCruzan = propio.horaInicio()
                        .isBefore(existente.horaFin())
                        && existente.horaInicio().isBefore(propio.horaFin());
                if (!seCruzan) {
                    continue;
                }
                conflictos.computeIfAbsent(existente.fecha(),
                        key -> new java.util.LinkedHashSet<>())
                        .add(new VistaPreviaConsultorioResponse.Solapamiento(
                                propio.numero(), existente.numero()
                        ));
            }
        }
        java.util.Map<LocalDate,
                List<VistaPreviaConsultorioResponse.Solapamiento>> respuesta =
                new java.util.LinkedHashMap<>();
        conflictos.forEach(
                (fecha, numeros) -> respuesta.put(fecha, List.copyOf(numeros))
        );
        return respuesta;
    }

    /**
     * RF-20: modifica el consultorio de fechas actuales y futuras. Si
     * existen consultas agendadas en las fechas elegidas exige confirmacion
     * expresa; los solapamientos no pueden forzarse. Conserva fechas pasadas,
     * estados suspendidos y consultas existentes.
     */
    @Transactional
    public TurnoSemanalResponse modificarConsultorio(
            Long idPatron,
            ModificarTurnoSemanalRequest request
    ) {
        validarCambioConsultorio(idPatron, request);
        if (request.turnoIds() != null
                || Boolean.TRUE.equals(request.confirmarConConsultas())) {
            return modificarConsultorioPorFechas(idPatron, request);
        }

        if (idPatron == null || idPatron <= 0
                || request == null || request.consultorioId() == null
                || request.consultorioId() <= 0) {
            throw validacion("Faltan datos obligatorios o no son válidos");
        }

        PatronSemanal patron = repository.bloquearPatron(idPatron)
                .orElseThrow(() -> noEncontrado(
                        "No existe el turno semanal indicado"
                ));

        if (patron.idConsultorio().equals(request.consultorioId())) {
            // El patrón puede coincidir aunque una fecha concreta tenga otro
            // consultorio tras un cambio parcial anterior.
            LocalDate hoy = LocalDate.now(clock.withZone(ZONA));
            boolean todasEnDestino = repository.listarFechasDesde(
                    idPatron, hoy, false
            ).stream().allMatch(fecha -> fecha.consultorio().id()
                    .equals(request.consultorioId()));
            if (todasEnDestino) {
                return consultaRepository.obtenerPatron(idPatron)
                        .orElseThrow(() -> noEncontrado(
                                "No existe el turno semanal indicado"
                        ));
            }
            return modificarConsultorioPorFechas(idPatron, request);
        }

        Consultorio consultorioNuevo = repository
                .bloquearConsultorio(request.consultorioId())
                .orElseThrow(() -> noEncontrado(
                        "No existe el consultorio indicado"
                ));

        LocalDate hoy = LocalDate.now(clock.withZone(ZONA));

        // Bloquea las filas de turno vigentes: la agenda toma el mismo
        // bloqueo al reservar, asi que ninguna consulta nueva puede
        // colarse entre la verificacion y la modificacion.
        List<LocalDate> fechasActivas = repository.bloquearFechasActivasDesde(
                idPatron, hoy
        );
        if (fechasActivas.isEmpty()) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "TURNO_NO_MODIFICABLE",
                    "El turno semanal ya finalizó; no tiene fechas actuales"
                            + " ni futuras por modificar"
            );
        }

        int agendadas = repository.contarConsultasAgendadasDesde(
                idPatron, hoy
        );
        if (agendadas > 0) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "TURNO_NO_MODIFICABLE",
                    "El turno tiene " + agendadas
                            + " consulta(s) agendada(s) en fechas vigentes."
                            + " Confirmá el cambio para continuar, o elegí"
                            + " otras fechas."
            );
        }

        validarSolapamientosDeModificacion(patron, consultorioNuevo,
                fechasActivas);

        repository.actualizarConsultorio(
                idPatron, consultorioNuevo.id(), hoy
        );

        return consultaRepository.obtenerPatron(idPatron)
                .orElseThrow(() -> noEncontrado(
                        "No existe el turno semanal indicado"
                ));
    }

    /**
     * Revalida RF-13 sobre la configuracion resultante: los numeros del
     * patron (que no cambian) no pueden solaparse, en las fechas activas
     * vigentes, con numeros de otros turnos activos del mismo medico o del
     * consultorio nuevo.
     */
    private void validarSolapamientosDeModificacion(
            PatronSemanal patron,
            Consultorio consultorioNuevo,
            List<LocalDate> fechasActivas
    ) {
        List<NumeroInstancia> numeros = repository.numerosDelPatron(patron.id());
        List<NumeroExistente> existentes =
                repository.buscarNumerosActivosDeOtrosPatrones(
                        patron.idMedico(),
                        consultorioNuevo.id(),
                        fechasActivas.getFirst(),
                        fechasActivas.getLast(),
                        patron.id()
                );
        Set<LocalDate> fechasPropias = new HashSet<>(fechasActivas);
        Set<String> conflictos = new java.util.LinkedHashSet<>();

        for (NumeroExistente existente : existentes) {
            if (!fechasPropias.contains(existente.fecha())) {
                continue;
            }
            boolean mismoRecurso = existente.idMedico().equals(patron.idMedico())
                    || existente.idConsultorio().equals(consultorioNuevo.id());
            if (!mismoRecurso) {
                continue;
            }
            for (NumeroInstancia propio : numeros) {
                boolean seSolapan = propio.horaInicio()
                        .isBefore(existente.horaFin())
                        && existente.horaInicio().isBefore(propio.horaFin());
                if (seSolapan) {
                    conflictos.add(
                            "fecha " + existente.fecha()
                                    + ", número " + propio.numero()
                                    + " con número existente "
                                    + existente.numero()
                    );
                }
            }
        }
        if (!conflictos.isEmpty()) {
            String detalle = conflictos.stream()
                    .collect(Collectors.joining("; "));
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "SOLAPAMIENTO_TURNO",
                    "Se encontraron solapamientos: " + detalle
            );
        }
    }

    private void validarSolicitud(
            AltaTurnoSemanalRequest request,
            Long idFuncionario
    ) {
        if (request == null || idFuncionario == null || idFuncionario <= 0
                || request.medicoId() == null || request.medicoId() <= 0
                || request.especialidadId() == null
                || request.especialidadId() <= 0
                || request.consultorioId() == null
                || request.consultorioId() <= 0
                || request.diaSemana() == null
                || request.fechaInicio() == null
                || request.fechaFin() == null
                || request.numeros() == null
                || request.numeros().isEmpty()) {
            throw validacion("Faltan datos obligatorios o no son válidos");
        }
        if (request.diaSemana() < 1 || request.diaSemana() > 7) {
            throw validacion("diaSemana debe estar entre 1 y 7");
        }
        if (request.fechaFin().isBefore(request.fechaInicio())) {
            throw validacion("fechaFin no puede ser anterior a fechaInicio");
        }
    }

    private List<NumeroValidado> validarNumeros(
            List<AltaTurnoSemanalRequest.NumeroSemanalRequest> solicitados
    ) {
        List<NumeroValidado> numeros = new ArrayList<>();
        Set<Integer> identificadores = new HashSet<>();
        for (var solicitado : solicitados) {
            if (solicitado == null || solicitado.numero() == null
                    || solicitado.numero() < 1
                    || solicitado.horaInicio() == null
                    || solicitado.horaFin() == null) {
                throw validacion("Cada número requiere número y horarios");
            }
            if (!identificadores.add(solicitado.numero())) {
                throw validacion("Los números no pueden repetirse");
            }

            LocalTime inicio = parsearHora(solicitado.horaInicio());
            LocalTime fin = parsearHora(solicitado.horaFin());
            if (!inicio.isBefore(fin)) {
                throw validacion("horaInicio debe ser anterior a horaFin");
            }
            if (inicio.getSecond() != 0 || fin.getSecond() != 0
                    || inicio.getNano() != 0 || fin.getNano() != 0
                    || inicio.getMinute() % 5 != 0
                    || fin.getMinute() % 5 != 0) {
                throw validacion("Los horarios deben estar en múltiplos de 5 minutos");
            }
            long duracion = java.time.Duration.between(inicio, fin).toMinutes();
            if (duracion < 10 || duracion > 60) {
                throw validacion("La duración debe estar entre 10 y 60 minutos");
            }
            numeros.add(new NumeroValidado(
                    solicitado.numero(),
                    inicio,
                    fin
            ));
        }

        numeros.sort(Comparator.comparing(NumeroValidado::horaInicio));
        for (int i = 1; i < numeros.size(); i++) {
            NumeroValidado anterior = numeros.get(i - 1);
            NumeroValidado actual = numeros.get(i);
            if (actual.horaInicio().isBefore(anterior.horaFin())) {
                throw validacion("Los horarios de los números no pueden solaparse");
            }
        }
        numeros.sort(Comparator.comparingInt(NumeroValidado::numero));
        return numeros;
    }

    private LocalTime parsearHora(String valor) {
        try {
            return LocalTime.parse(valor);
        } catch (java.time.format.DateTimeParseException exception) {
            throw validacion("Las horas deben tener formato HH:mm");
        }
    }

    private List<LocalDate> generarFechas(AltaTurnoSemanalRequest request) {
        DayOfWeek diaSemana = DayOfWeek.of(request.diaSemana());
        LocalDate primera = request.fechaInicio();
        while (primera.getDayOfWeek() != diaSemana) {
            primera = primera.plusDays(1);
            if (primera.isAfter(request.fechaFin())) {
                throw validacion(
                        "El rango no contiene fechas del día de semana indicado"
                );
            }
        }

        List<LocalDate> fechas = new ArrayList<>();
        for (LocalDate fecha = primera;
                !fecha.isAfter(request.fechaFin());
                fecha = fecha.plusWeeks(1)) {
            fechas.add(fecha);
        }
        return fechas;
    }

    private void validarSolapamientos(
            AltaTurnoSemanalRequest request,
            List<NumeroValidado> numeros,
            List<LocalDate> fechas
    ) {
        List<NumeroExistente> existentes = repository.buscarNumerosActivos(
                request.medicoId(),
                request.consultorioId(),
                fechas.getFirst(),
                fechas.getLast()
        );
        Set<LocalDate> fechasProgramadas = new HashSet<>(fechas);
        Set<String> conflictos = new java.util.LinkedHashSet<>();

        for (NumeroExistente existente : existentes) {
            for (NumeroValidado propuesto : numeros) {
                boolean mismoRecurso = existente.idMedico().equals(request.medicoId())
                        || existente.idConsultorio().equals(request.consultorioId());
                boolean seSolapan = propuesto.horaInicio()
                        .isBefore(existente.horaFin())
                        && existente.horaInicio().isBefore(propuesto.horaFin());
                if (mismoRecurso && fechasProgramadas.contains(existente.fecha())
                        && seSolapan) {
                    conflictos.add(
                            "fecha " + existente.fecha()
                                    + ", número nuevo " + propuesto.numero()
                                    + " con número existente "
                                    + existente.numero()
                    );
                }
            }
        }
        if (!conflictos.isEmpty()) {
            String detalle = conflictos.stream()
                    .collect(Collectors.joining("; "));
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "SOLAPAMIENTO_TURNO",
                    "Se encontraron solapamientos: " + detalle
            );
        }
    }

    private ApiException noEncontrado(String mensaje) {
        return new ApiException(
                HttpStatus.NOT_FOUND,
                "NO_ENCONTRADO",
                mensaje
        );
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }

    private record NumeroValidado(
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
    }
}
