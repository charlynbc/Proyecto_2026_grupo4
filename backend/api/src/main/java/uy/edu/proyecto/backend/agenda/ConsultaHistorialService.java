package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Set;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class ConsultaHistorialService {

    private static final Set<String> ESTADOS = Set.of(
            "AGENDADA",
            "ATENDIDA",
            "CANCELADA_SOCIO",
            "CANCELADA_INSTITUCION",
            "NO_SE_PRESENTO",
            "NO_ASISTIO",
            "NO_ATENDIDA"
    );

    private final ConsultaRepository repository;
    private final Clock clock;

    public ConsultaHistorialService(ConsultaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public ConsultaHistorialPageResponse listar(
            Long socioId,
            String estado,
            String fechaDesde,
            String fechaHasta,
            String especialidadId,
            String medicoId,
            String orden,
            String sentido,
            String page,
            String size
    ) {
        if (socioId == null || socioId <= 0) {
            throw validacion("El identificador del socio debe ser positivo");
        }

        LocalDate desde = fecha(fechaDesde, "fechaDesde");
        LocalDate hasta = fecha(fechaHasta, "fechaHasta");
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw validacion("fechaDesde no puede ser posterior a fechaHasta");
        }

        String estadoNormalizado = opcional(estado);
        if (estadoNormalizado != null && !ESTADOS.contains(estadoNormalizado)) {
            throw validacion("estado no es un estado de consulta válido");
        }
        String ordenNormalizado = valor(orden, "fecha", Set.of("fecha", "especialidad"));
        String sentidoNormalizado = valor(sentido, "desc", Set.of("asc", "desc"));
        int pagina = entero(page, "page", 0, Integer.MAX_VALUE);
        int cantidad = entero(size, "size", 20, 100);
        if (cantidad < 1) {
            throw validacion("size debe estar entre 1 y 100");
        }

        ConsultaHistorialFiltro filtro = new ConsultaHistorialFiltro(
                estadoNormalizado,
                desde,
                hasta,
                identificador(especialidadId, "especialidadId"),
                identificador(medicoId, "medicoId"),
                ordenNormalizado,
                sentidoNormalizado,
                pagina,
                cantidad
        );
        return repository.listarHistorial(socioId, filtro, LocalDate.now(clock));
    }

    @Transactional(readOnly = true)
    public ConsultaDTO obtener(Long socioId, String id) {
        if (socioId == null || socioId <= 0) {
            throw validacion("El identificador del socio debe ser positivo");
        }
        long consultaId = identificador(id, "id");
        return repository.obtenerHistorialDelSocio(
                        socioId,
                        consultaId,
                        LocalDate.now(clock)
                )
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "NO_ENCONTRADO",
                        "No existe la consulta indicada"
                ));
    }

    private LocalDate fecha(String raw, String campo) {
        String value = opcional(raw);
        if (value == null) {
            return null;
        }
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato yyyy-MM-dd");
        }
    }

    private Long identificador(String raw, String campo) {
        String value = opcional(raw);
        if (value == null) {
            return null;
        }
        try {
            long parsed = Long.parseLong(value);
            if (parsed > 0) {
                return parsed;
            }
        } catch (NumberFormatException ignored) {
            // Invalid user input is reported through the contract error below.
        }
        throw validacion(campo + " debe ser un entero positivo");
    }

    private int entero(String raw, String campo, int defecto, int maximo) {
        String value = opcional(raw);
        if (value == null) {
            return defecto;
        }
        try {
            int parsed = Integer.parseInt(value);
            if (parsed >= 0 && parsed <= maximo) {
                return parsed;
            }
        } catch (NumberFormatException ignored) {
            // Invalid user input is reported through the contract error below.
        }
        throw validacion(
                campo + (campo.equals("size")
                        ? " debe estar entre 1 y 100"
                        : " debe ser un entero mayor o igual a 0")
        );
    }

    private String valor(String raw, String defecto, Set<String> permitidos) {
        String value = opcional(raw);
        if (value == null) {
            return defecto;
        }
        if (permitidos.contains(value)) {
            return value;
        }
        throw validacion("Valor no permitido: " + value);
    }

    private String opcional(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
