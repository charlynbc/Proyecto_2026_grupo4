package uy.edu.proyecto.backend.turno;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
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

@Service
public class TurnoSemanalService {

    private static final DateTimeFormatter HORA_FORMATO =
            DateTimeFormatter.ofPattern("HH:mm");

    private final TurnoSemanalRepository repository;

    public TurnoSemanalService(TurnoSemanalRepository repository) {
        this.repository = repository;
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
