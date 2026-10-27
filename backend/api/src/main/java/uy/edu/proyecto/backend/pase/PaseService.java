package uy.edu.proyecto.backend.pase;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class PaseService {

    private final PaseRepository repository;
    private final Clock clock;

    public PaseService(PaseRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public List<PaseDTO> listarDisponibles(Long socioId) {
        if (socioId == null || socioId <= 0) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
        return repository.listarDisponibles(socioId, LocalDate.now(clock));
    }
}
