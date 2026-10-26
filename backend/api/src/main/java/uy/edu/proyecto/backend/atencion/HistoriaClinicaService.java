package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class HistoriaClinicaService {

    private final HistoriaClinicaRepository repository;

    public HistoriaClinicaService(HistoriaClinicaRepository repository) {
        this.repository = repository;
    }

    public List<HistoriaClinicaDTO> listar(
            Long socioId,
            String fechaDesde,
            String fechaHasta,
            String especialidadId,
            String medicoId,
            String texto,
            String orden,
            String sentido
    ) {
        LocalDate desde = parseFecha(fechaDesde, "fechaDesde");
        LocalDate hasta = parseFecha(fechaHasta, "fechaHasta");
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "fechaDesde no puede ser posterior a fechaHasta"
            );
        }

        String ordenNormalizado = orden == null || orden.isBlank() ? "fecha_atencion" : orden.trim().toLowerCase();
        String sentidoNormalizado = sentido == null || sentido.isBlank() ? "desc" : sentido.trim().toLowerCase();

        if (!"fecha_atencion".equals(ordenNormalizado)
                && !"especialidad".equals(ordenNormalizado)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ORDEN_INVALIDO",
                    "El campo de orden no es válido"
            );
        }
        if (!"asc".equals(sentidoNormalizado) && !"desc".equals(sentidoNormalizado)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "SENTIDO_INVALIDO",
                    "El sentido debe ser asc o desc"
            );
        }

        return repository.listar(
                socioId,
                desde,
                hasta,
                parseLong(especialidadId, "especialidadId"),
                parseLong(medicoId, "medicoId"),
                texto,
                ordenNormalizado,
                sentidoNormalizado
        );
    }

    public HistoriaClinicaDTO detalle(Long socioId, Long idAtencion) {
        if (idAtencion == null || idAtencion <= 0) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "idAtencion debe ser un identificador válido"
            );
        }

        HistoriaClinicaDTO item = repository.obtenerDetalle(socioId, idAtencion);
        if (item == null) {
            throw new ApiException(
                    HttpStatus.NOT_FOUND,
                    "HISTORIA_NO_ENCONTRADA",
                    "La atención no existe o no pertenece a este socio"
            );
        }
        return item;
    }

    private LocalDate parseFecha(String valor, String nombreCampo) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(valor);
        } catch (Exception exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    nombreCampo + " debe tener formato yyyy-MM-dd"
            );
        }
    }

    private Long parseLong(String valor, String nombreCampo) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        try {
            Long parsed = Long.parseLong(valor);
            if (parsed <= 0) {
                throw new NumberFormatException();
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    nombreCampo + " debe ser un identificador positivo"
            );
        }
    }
}
