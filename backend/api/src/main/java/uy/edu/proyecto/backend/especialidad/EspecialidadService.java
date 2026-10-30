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

    public List<Especialidad> listar(String nombre, String requierePase, String orden) {
        if (nombre != null && nombre.length() > 120) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "El filtro nombre no puede superar 120 caracteres");
        }
        Boolean filtroPase = null;
        if (requierePase != null) {
            if (!"true".equalsIgnoreCase(requierePase.trim())
                    && !"false".equalsIgnoreCase(requierePase.trim())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                        "requierePase debe ser true o false");
            }
            filtroPase = Boolean.parseBoolean(requierePase.trim());
        }
        String ordenFinal = orden == null || orden.isBlank() ? "nombre" : orden.trim();
        if (!List.of("nombre", "fechaAlta").contains(ordenFinal)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "orden debe ser nombre o fechaAlta");
        }
        return repository.listarFiltradas(nombre == null ? null : nombre.trim(),
                filtroPase, ordenFinal);
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
