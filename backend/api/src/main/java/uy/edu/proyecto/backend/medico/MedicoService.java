package uy.edu.proyecto.backend.medico;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class MedicoService {

    private final MedicoRepository repository;

    public MedicoService(MedicoRepository repository) {
        this.repository = repository;
    }

    public List<MedicoDTO> listar(Long especialidadId) {
        if (especialidadId != null && especialidadId <= 0) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "especialidadId debe ser un identificador positivo"
            );
        }
        return repository.listar(especialidadId);
    }
}
