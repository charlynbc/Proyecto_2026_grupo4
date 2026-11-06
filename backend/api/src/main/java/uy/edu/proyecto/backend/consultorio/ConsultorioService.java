package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class ConsultorioService {

    private final ConsultorioRepository repository;

    public ConsultorioService(ConsultorioRepository repository) {
        this.repository = repository;
    }

    public List<Consultorio> listar() {
        return repository.listar();
    }

    public List<Consultorio> listar(String nombre, String ubicacion, String orden) {
        if ((nombre != null && nombre.length() > 120)
                || (ubicacion != null && ubicacion.length() > 200)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "Los filtros superan la longitud permitida");
        }
        String ordenFinal = orden == null || orden.isBlank() ? "nombre" : orden.trim();
        if (!List.of("nombre", "ubicacion").contains(ordenFinal)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "orden debe ser nombre o ubicacion");
        }
        return repository.listarFiltrados(nombre == null ? null : nombre.trim(),
                ubicacion == null ? null : ubicacion.trim(), ordenFinal);
    }

    /**
     * Correccion administrativa (RF-38): nombre y/o ubicacion. El nombre se
     * mantiene unico sin distinguir mayusculas (mismo criterio que la carga
     * masiva RF-34). Las relaciones con turnos y consultas se conservan,
     * porque referencian al consultorio por id.
     */
    public Consultorio corregir(long id, String nombre, String ubicacion) {
        if (nombre == null && ubicacion == null) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "Debe indicar al menos un campo a corregir (nombre o ubicacion)"
            );
        }

        Consultorio actual = repository.buscarPorId(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "CONSULTORIO_NO_ENCONTRADO",
                        "No existe un consultorio con ese identificador"
                ));

        String nombreFinal = actual.nombre();
        if (nombre != null) {
            nombreFinal = nombre.trim();
            if (nombreFinal.isBlank()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "El nombre del consultorio es obligatorio"
                );
            }
            if (nombreFinal.length() > 120) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "El nombre no puede superar 120 caracteres"
                );
            }
            String nombreBuscado = nombreFinal;
            repository.buscarPorNombresLower(List.of(nombreBuscado))
                    .values()
                    .stream()
                    .filter(existente -> existente.id() != id)
                    .findFirst()
                    .ifPresent(existente -> {
                        throw new ApiException(
                                HttpStatus.CONFLICT,
                                "CONSULTORIO_DUPLICADO",
                                "Ya existe un consultorio registrado con ese nombre."
                        );
                    });
        }

        String ubicacionFinal = actual.ubicacion();
        if (ubicacion != null) {
            ubicacionFinal = ubicacion.trim();
            if (ubicacionFinal.isBlank()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "La ubicación del consultorio es obligatoria"
                );
            }
            if (ubicacionFinal.length() > 200) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "La ubicación no puede superar 200 caracteres"
                );
            }
        }

        try {
            return repository.actualizar(id, nombreFinal, ubicacionFinal);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONSULTORIO_DUPLICADO",
                    "Ya existe un consultorio registrado con ese nombre."
            );
        }
    }

    public Consultorio crear(String nombre, String ubicacion) {
        if (nombre == null || nombre.isBlank()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El nombre del consultorio es obligatorio"
            );
        }

        if (ubicacion == null || ubicacion.isBlank()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "La ubicación del consultorio es obligatoria"
            );
        }

        String nombreNormalizado = nombre.trim();
        String ubicacionNormalizada = ubicacion.trim();

        if (nombreNormalizado.length() > 120) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El nombre no puede superar 120 caracteres"
            );
        }

        if (ubicacionNormalizada.length() > 200) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "La ubicación no puede superar 200 caracteres"
            );
        }

        try {
            return repository.crear(
                    nombreNormalizado,
                    ubicacionNormalizada
            );
        } catch (DuplicateKeyException exception) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONSULTORIO_DUPLICADO",
                    "Ya existe un consultorio registrado con ese nombre."
            );
        }
    }
}
