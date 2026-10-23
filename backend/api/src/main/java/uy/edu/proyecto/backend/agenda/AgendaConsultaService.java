package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Set;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CiUruguaya;

@Service
public class AgendaConsultaService {

    private static final Set<String> ESTADOS = Set.of(
            "AGENDADA",
            "ATENDIDA",
            "CANCELADA_SOCIO",
            "CANCELADA_INSTITUCION",
            "NO_SE_PRESENTO",
            "NO_ASISTIO",
            "NO_ATENDIDA"
    );

    private final AgendaConsultaRepository repository;
    private final Clock clock;

    public AgendaConsultaService(
            AgendaConsultaRepository repository,
            Clock clock
    ) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AgendaOperativaPageResponse consultar(
            String ciSolicitada,
            String consultaIdSolicitada,
            String fechaSolicitada,
            String medicoIdSolicitado,
            String estadoSolicitado,
            String llegadaSolicitada,
            String ordenSolicitado,
            String sentidoSolicitado,
            String pageSolicitada,
            String sizeSolicitado
    ) {
        String ci = ci(ciSolicitada);
        Long consultaId = id(consultaIdSolicitada, "consultaId");
        LocalDate fecha = fecha(fechaSolicitada);
        Long medicoId = id(medicoIdSolicitado, "medicoId");
        String estado = opcional(estadoSolicitado);
        if (estado != null && !ESTADOS.contains(estado)) {
            throw validacion("estado no es un estado de consulta válido");
        }

        Boolean llegada = booleano(llegadaSolicitada);
        String orden = opcion(
                ordenSolicitado,
                "fechaHora",
                Set.of("fechaHora", "horaLlegada"),
                "orden debe ser fechaHora o horaLlegada"
        );
        String sentido = opcion(
                sentidoSolicitado,
                "asc",
                Set.of("asc", "desc"),
                "sentido debe ser asc o desc"
        );
        int page = entero(pageSolicitada, "page", 0, Integer.MAX_VALUE);
        int size = entero(sizeSolicitado, "size", 20, 100);
        if (size < 1) {
            throw validacion("size debe estar entre 1 y 100");
        }

        FiltroAgendaDTO filtro = new FiltroAgendaDTO(
                ci,
                consultaId,
                fecha,
                medicoId,
                estado,
                llegada,
                orden,
                sentido,
                page,
                size
        );
        return repository.listar(filtro, LocalDate.now(clock));
    }

    private String ci(String raw) {
        String valor = opcional(raw);
        if (valor == null) {
            return null;
        }
        return CiUruguaya.normalizarValida(valor)
                .orElseThrow(() -> validacion("ci debe ser una cédula válida"));
    }

    private Long id(String raw, String campo) {
        String valor = opcional(raw);
        if (valor == null) {
            return null;
        }
        try {
            long id = Long.parseLong(valor);
            if (id > 0) {
                return id;
            }
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un entero positivo");
        }
        throw validacion(campo + " debe ser un entero positivo");
    }

    private LocalDate fecha(String raw) {
        String valor = opcional(raw);
        if (valor == null) {
            return null;
        }
        try {
            return LocalDate.parse(valor);
        } catch (DateTimeParseException exception) {
            throw validacion("fecha debe tener formato YYYY-MM-DD");
        }
    }

    private Boolean booleano(String raw) {
        String valor = opcional(raw);
        if (valor == null) {
            return null;
        }
        if ("true".equalsIgnoreCase(valor)) {
            return true;
        }
        if ("false".equalsIgnoreCase(valor)) {
            return false;
        }
        throw validacion("llegada debe ser true o false");
    }

    private int entero(String raw, String campo, int defecto, int maximo) {
        String valor = opcional(raw);
        if (valor == null) {
            return defecto;
        }
        try {
            int numero = Integer.parseInt(valor);
            if (numero >= 0 && numero <= maximo) {
                return numero;
            }
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un entero válido");
        }
        throw validacion(campo.equals("size")
                ? "size debe estar entre 1 y 100"
                : "page debe ser mayor o igual a cero");
    }

    private String opcion(
            String raw,
            String defecto,
            Set<String> permitidos,
            String error
    ) {
        String valor = opcional(raw);
        if (valor == null) {
            return defecto;
        }
        if (permitidos.contains(valor)) {
            return valor;
        }
        throw validacion(error);
    }

    private String opcional(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        return valor.trim();
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
