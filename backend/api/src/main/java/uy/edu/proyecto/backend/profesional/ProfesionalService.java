package uy.edu.proyecto.backend.profesional;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class ProfesionalService {

    private final ProfesionalRepository repository;

    public ProfesionalService(ProfesionalRepository repository) {
        this.repository = repository;
    }

    public List<Profesional> listar() {
        return repository.listar();
    }

    public List<HorarioDisponible> horariosDisponibles(
            Long profesionalId,
            OffsetDateTime desde,
            OffsetDateTime hasta
    ) {
        if (!desde.isBefore(hasta)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "RANGO_FECHAS_INVALIDO",
                    "La fecha desde debe ser anterior a hasta"
            );
        }

        return repository.horariosDisponibles(profesionalId, desde, hasta);
    }
}