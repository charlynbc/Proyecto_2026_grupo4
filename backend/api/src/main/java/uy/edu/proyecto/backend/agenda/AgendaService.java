package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.VentanaAgendar;

@Service
public class AgendaService {

    private final AgendaRepository repository;
    private final ParametroService parametros;
    private final Clock clock;

    public AgendaService(AgendaRepository repository, ParametroService parametros,
            Clock clock) {
        this.repository = repository;
        this.parametros = parametros;
        this.clock = clock;
    }

    public List<NumeroDisponibleDTO> consultarDisponibilidad(
            String especialidadIdSolicitada,
            String medicoIdSolicitado,
            String fechaDesde,
            String fechaHasta,
            String orden,
            String sentido
    ) {
        Long especialidadId = parsearId(
                especialidadIdSolicitada,
                "especialidadId",
                false
        );
        Long medicoId = parsearId(
                medicoIdSolicitado,
                "medicoId",
                false
        );

        if (especialidadId == null && medicoId == null) {
            throw validacion("Debe indicar especialidadId o medicoId");
        }

        LocalDate desde = parsearFecha(fechaDesde, "fechaDesde");
        LocalDate hasta = parsearFecha(fechaHasta, "fechaHasta");
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw validacion("fechaDesde no puede ser posterior a fechaHasta");
        }

        String ordenNormalizado = orden == null ? "fecha" : orden.trim();
        if (!ordenNormalizado.equals("fecha")
                && !ordenNormalizado.equals("apellidoMedico")) {
            throw validacion("orden debe ser fecha o apellidoMedico");
        }

        String sentidoNormalizado = sentido == null ? "asc" : sentido.trim();
        if (!sentidoNormalizado.equals("asc")
                && !sentidoNormalizado.equals("desc")) {
            throw validacion("sentido debe ser asc o desc");
        }

        if (especialidadId != null && !repository.existeEspecialidad(especialidadId)) {
            throw noEncontrado("No existe la especialidad indicada");
        }
        if (medicoId != null && !repository.existeMedico(medicoId)) {
            throw noEncontrado("No existe el médico indicado");
        }

        VentanaAgendar ventana = parametros.ventanaAgendar(OffsetDateTime.now(clock));
        return repository.consultarDisponibilidad(new FiltroDisponibilidadDTO(
                especialidadId,
                medicoId,
                desde,
                hasta,
                ordenNormalizado,
                sentidoNormalizado
        ), ventana.minimoInicio(), ventana.maximoInicio());
    }

    private LocalDate parsearFecha(String valor, String campo) {
        if (valor == null) {
            return null;
        }
        try {
            return LocalDate.parse(valor);
        } catch (DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato YYYY-MM-DD");
        }
    }

    private Long parsearId(String valor, String campo, boolean obligatorio) {
        if (valor == null) {
            if (obligatorio) {
                throw validacion(campo + " es obligatorio");
            }
            return null;
        }
        try {
            long id = Long.parseLong(valor.trim());
            if (id <= 0) {
                throw validacion(campo + " debe ser mayor que cero");
            }
            return id;
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un entero válido");
        }
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }

    private ApiException noEncontrado(String mensaje) {
        return new ApiException(
                HttpStatus.NOT_FOUND,
                "NO_ENCONTRADO",
                mensaje
        );
    }
}
