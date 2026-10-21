package uy.edu.proyecto.backend.agenda;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/disponibilidad")
public class DisponibilidadController {

    private final AgendaService agendaService;

    public DisponibilidadController(AgendaService agendaService) {
        this.agendaService = agendaService;
    }

    @GetMapping
    public DisponibilidadResponse consultar(
            @RequestParam(name = "especialidadId", required = false)
            String especialidadId,
            @RequestParam(name = "medicoId", required = false)
            String medicoId,
            @RequestParam(name = "fechaDesde", required = false)
            String fechaDesde,
            @RequestParam(name = "fechaHasta", required = false)
            String fechaHasta,
            @RequestParam(name = "orden", required = false)
            String orden,
            @RequestParam(name = "sentido", required = false)
            String sentido
    ) {
        return new DisponibilidadResponse(
                agendaService.consultarDisponibilidad(
                        especialidadId,
                        medicoId,
                        fechaDesde,
                        fechaHasta,
                        orden,
                        sentido
                )
        );
    }
}
