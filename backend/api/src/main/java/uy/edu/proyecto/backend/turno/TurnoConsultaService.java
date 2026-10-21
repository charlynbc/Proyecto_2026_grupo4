package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class TurnoConsultaService {

    private final TurnoConsultaRepository repository;

    public TurnoConsultaService(TurnoConsultaRepository repository) {
        this.repository = repository;
    }

    public TurnosPageResponse listar(
            String medicoId,
            String especialidadId,
            String diaSemana,
            String fechaDesde,
            String fechaHasta,
            String estado,
            String orden,
            String sentido,
            String page,
            String size
    ) {
        Long medico = parsearLong(medicoId, "medicoId");
        Long especialidad = parsearLong(especialidadId, "especialidadId");
        Integer dia = parsearEntero(diaSemana, "diaSemana");
        LocalDate desde = parsearFecha(fechaDesde, "fechaDesde");
        LocalDate hasta = parsearFecha(fechaHasta, "fechaHasta");
        int numeroPagina = parsearEnteroOpcional(page, 0, "page");
        int tamanoPagina = parsearEnteroOpcional(size, 20, "size");
        String estadoNormalizado = estado == null ? null : estado.trim();
        String ordenNormalizado = orden == null ? "fecha" : orden.trim();
        String sentidoNormalizado = sentido == null ? "asc" : sentido.trim();

        if ((medico != null && medico <= 0)
                || (especialidad != null && especialidad <= 0)) {
            throw validacion("Los identificadores deben ser mayores que cero");
        }
        if (dia != null && (dia < 1 || dia > 7)) {
            throw validacion("diaSemana debe estar entre 1 y 7");
        }
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw validacion("fechaDesde no puede ser posterior a fechaHasta");
        }
        if (estadoNormalizado != null
                && !estadoNormalizado.equals("ACTIVO")
                && !estadoNormalizado.equals("SUSPENDIDO")) {
            throw validacion("estado debe ser ACTIVO o SUSPENDIDO");
        }
        if (!ordenNormalizado.equals("fecha")
                && !ordenNormalizado.equals("medico")
                && !ordenNormalizado.equals("especialidad")) {
            throw validacion("orden debe ser fecha, medico o especialidad");
        }
        if (!sentidoNormalizado.equals("asc")
                && !sentidoNormalizado.equals("desc")) {
            throw validacion("sentido debe ser asc o desc");
        }
        if (numeroPagina < 0) {
            throw validacion("page debe ser mayor o igual a cero");
        }
        if (tamanoPagina < 1 || tamanoPagina > 100) {
            throw validacion("size debe estar entre 1 y 100");
        }
        if (medico != null && !repository.existeMedico(medico)) {
            throw noEncontrado("No existe el médico indicado");
        }
        if (especialidad != null && !repository.existeEspecialidad(especialidad)) {
            throw noEncontrado("No existe la especialidad indicada");
        }

        return repository.listar(new FiltroTurnosDTO(
                medico,
                especialidad,
                dia,
                desde,
                hasta,
                estadoNormalizado,
                ordenNormalizado,
                sentidoNormalizado,
                numeroPagina,
                tamanoPagina
        ));
    }

    public TurnoSemanalResponse obtenerPatron(Long id) {
        if (id == null || id <= 0) {
            throw validacion("El id debe ser mayor que cero");
        }
        return repository.obtenerPatron(id).orElseThrow(
                () -> noEncontrado("No existe la configuración semanal indicada")
        );
    }

    private Long parsearLong(String valor, String campo) {
        if (valor == null) {
            return null;
        }
        try {
            return Long.parseLong(valor.trim());
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un entero válido");
        }
    }

    private Integer parsearEntero(String valor, String campo) {
        if (valor == null) {
            return null;
        }
        try {
            return Integer.parseInt(valor.trim());
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un entero válido");
        }
    }

    private int parsearEnteroOpcional(
            String valor,
            int defecto,
            String campo
    ) {
        Integer resultado = parsearEntero(valor, campo);
        return resultado == null ? defecto : resultado;
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
