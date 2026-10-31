package uy.edu.proyecto.backend.pase;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

// RF-26: el médico consulta los pases que emitió a través de sus atenciones.
@Service
public class PaseMedicoService {

    private final PaseMedicoRepository repository;
    private final Clock clock;

    public PaseMedicoService(PaseMedicoRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<PaseEmitidoDTO> listar(
            Long medicoId,
            String situacion,
            String orden,
            String sentido
    ) {
        if (medicoId == null || medicoId <= 0) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO",
                    "La sesión no es válida");
        }
        String situacionNormalizada = situacion == null || situacion.isBlank()
                ? null
                : situacion.trim().toUpperCase();
        if (situacionNormalizada != null
                && !"DISPONIBLE".equals(situacionNormalizada)
                && !"UTILIZADO".equals(situacionNormalizada)
                && !"VENCIDO".equals(situacionNormalizada)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "situacion debe ser DISPONIBLE, UTILIZADO o VENCIDO");
        }
        String ordenNormalizado = orden == null || orden.isBlank()
                ? "vencimiento"
                : orden.trim().toLowerCase();
        if (!"vencimiento".equals(ordenNormalizado) && !"emision".equals(ordenNormalizado)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ORDEN_INVALIDO",
                    "El campo de orden no es válido");
        }
        String sentidoNormalizado = sentido == null || sentido.isBlank()
                ? "asc"
                : sentido.trim().toLowerCase();
        if (!"asc".equals(sentidoNormalizado) && !"desc".equals(sentidoNormalizado)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "SENTIDO_INVALIDO",
                    "El sentido debe ser asc o desc");
        }
        return repository.listarEmitidos(
                medicoId,
                situacionNormalizada,
                ordenNormalizado,
                sentidoNormalizado,
                LocalDate.now(clock)
        );
    }
}
