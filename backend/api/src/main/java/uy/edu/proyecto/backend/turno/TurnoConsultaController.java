package uy.edu.proyecto.backend.turno;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TurnoConsultaController {

    private final TurnoConsultaService service;

    public TurnoConsultaController(TurnoConsultaService service) {
        this.service = service;
    }

    @GetMapping("/api/turnos")
    public TurnosPageResponse listar(
            @RequestParam(name = "medicoId", required = false) String medicoId,
            @RequestParam(name = "especialidadId", required = false)
            String especialidadId,
            @RequestParam(name = "diaSemana", required = false) String diaSemana,
            @RequestParam(name = "fechaDesde", required = false) String fechaDesde,
            @RequestParam(name = "fechaHasta", required = false) String fechaHasta,
            @RequestParam(name = "estado", required = false) String estado,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @RequestParam(name = "page", required = false) String page,
            @RequestParam(name = "size", required = false) String size
    ) {
        return service.listar(
                medicoId,
                especialidadId,
                diaSemana,
                fechaDesde,
                fechaHasta,
                estado,
                orden,
                sentido,
                page,
                size
        );
    }

    @GetMapping("/api/turnos-semanales/{id}")
    public TurnoSemanalResponse obtenerPatron(@PathVariable Long id) {
        return service.obtenerPatron(id);
    }
}
