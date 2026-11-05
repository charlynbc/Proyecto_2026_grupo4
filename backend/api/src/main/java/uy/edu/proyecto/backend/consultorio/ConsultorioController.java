package uy.edu.proyecto.backend.consultorio;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/consultorios")
public class ConsultorioController {

    private final ConsultorioService service;

    public ConsultorioController(ConsultorioService service) {
        this.service = service;
    }

    @GetMapping
    public Map<String, List<Consultorio>> listar(
            @RequestParam(required = false) String nombre,
            @RequestParam(required = false) String ubicacion,
            @RequestParam(required = false) String orden
    ) {
        if (nombre == null && ubicacion == null && orden == null) {
            return Map.of("items", service.listar());
        }
        return Map.of("items", service.listar(nombre, ubicacion, orden));
    }

    @PostMapping
    public ResponseEntity<Consultorio> crear(
            @RequestBody CrearConsultorioRequest request
    ) {
        Consultorio nuevo = service.crear(
                request.nombre(),
                request.ubicacion()
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(nuevo);
    }

    /** Correccion administrativa de nombre y/o ubicacion (RF-38). */
    @PatchMapping("/{id}")
    public Consultorio corregir(
            @PathVariable long id,
            @RequestBody CorregirConsultorioRequest request
    ) {
        if (request == null) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El cuerpo de la solicitud es obligatorio"
            );
        }
        return service.corregir(id, request.nombre(), request.ubicacion());
    }
}
