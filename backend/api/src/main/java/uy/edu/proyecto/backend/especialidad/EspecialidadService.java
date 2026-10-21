package uy.edu.proyecto.backend.especialidad;

import java.util.List;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class EspecialidadService {

    private final EspecialidadRepository repository;

    public EspecialidadService(EspecialidadRepository repository) {
        this.repository = repository;
    }

    public List<Especialidad> listar() {
        return repository.listar();
    }

    public Especialidad crear(String nombre, boolean requierePase) {
        if (nombre == null || nombre.isBlank()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El nombre es obligatorio"
            );
        }

        String nombreNormalizado = nombre.trim();

        if (nombreNormalizado.length() > 120) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El nombre no puede superar 120 caracteres"
            );
        }

        try {
            return repository.crear(nombreNormalizado, requierePase);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "ESPECIALIDAD_DUPLICADA",
                    "Ya existe una especialidad registrada con ese nombre."
            );
        }
    }
}
