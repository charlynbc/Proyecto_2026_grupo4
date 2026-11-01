package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

// RF-25: el médico busca y consulta exclusivamente las atenciones que él mismo registró.
@Service
public class AtencionMedicoService {

    private static final int PACIENTE_MAX_LENGTH = 100;

    private final AtencionMedicoRepository repository;

    public AtencionMedicoService(AtencionMedicoRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public List<AtencionMedicaDTO> listar(
            Long medicoId,
            String fechaDesde,
            String fechaHasta,
            String paciente,
            String especialidadId,
            String orden,
            String sentido
    ) {
        validarMedicoId(medicoId);
        LocalDate desde = parsearFechaObligatoria(fechaDesde, "fechaDesde");
        LocalDate hasta = parsearFechaObligatoria(fechaHasta, "fechaHasta");
        if (desde.isAfter(hasta)) {
            throw validacion("fechaDesde no puede ser posterior a fechaHasta");
        }
        Long especialidad = parsearLongOpcional(especialidadId, "especialidadId");
        String pacienteNormalizado = normalizarPaciente(paciente);

        String ordenNormalizado = orden == null || orden.isBlank()
                ? "fecha"
                : orden.trim().toLowerCase();
        if (!"fecha".equals(ordenNormalizado) && !"apellido".equals(ordenNormalizado)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ORDEN_INVALIDO",
                    "El campo de orden no es válido");
        }
        String sentidoNormalizado = sentido == null || sentido.isBlank()
                ? ("apellido".equals(ordenNormalizado) ? "asc" : "desc")
                : sentido.trim().toLowerCase();
        if (!"asc".equals(sentidoNormalizado) && !"desc".equals(sentidoNormalizado)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "SENTIDO_INVALIDO",
                    "El sentido debe ser asc o desc");
        }

        return repository.listar(
                medicoId,
                desde,
                hasta,
                pacienteNormalizado,
                especialidad,
                ordenNormalizado,
                sentidoNormalizado
        );
    }

    @Transactional(readOnly = true)
    public AtencionMedicaDTO detalle(Long medicoId, Long idAtencion) {
        validarMedicoId(medicoId);
        if (idAtencion == null || idAtencion <= 0) {
            throw validacion("El identificador de la atención debe ser positivo");
        }
        AtencionMedicaDTO item = repository.obtenerDetallePropio(medicoId, idAtencion);
        if (item == null) {
            // Atención ajena e inexistente responden igual para no revelar su existencia.
            throw new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO",
                    "No existe la atención indicada para este médico");
        }
        return item;
    }

    private void validarMedicoId(Long medicoId) {
        if (medicoId == null || medicoId <= 0) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO",
                    "La sesión no es válida");
        }
    }

    private LocalDate parsearFechaObligatoria(String valor, String campo) {
        if (valor == null || valor.isBlank()) {
            throw validacion(campo + " es obligatoria");
        }
        try {
            return LocalDate.parse(valor.trim());
        } catch (DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato YYYY-MM-DD");
        }
    }

    private Long parsearLongOpcional(String valor, String campo) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        try {
            long parsed = Long.parseLong(valor.trim());
            if (parsed <= 0) {
                throw new NumberFormatException();
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw validacion(campo + " debe ser un identificador positivo");
        }
    }

    private String normalizarPaciente(String paciente) {
        if (paciente == null || paciente.isBlank()) {
            return null;
        }
        String limpio = paciente.trim();
        if (limpio.length() > PACIENTE_MAX_LENGTH) {
            throw validacion("paciente no puede superar 100 caracteres");
        }
        return limpio;
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
