package uy.edu.proyecto.backend.agenda;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/agendas")
public class AgendaConsultaController {

    private final AgendaConsultaService service;

    public AgendaConsultaController(AgendaConsultaService service) {
        this.service = service;
    }

    @GetMapping
    public AgendaOperativaPageResponse consultar(
            @RequestParam(required = false) String ci,
            @RequestParam(required = false) String consultaId,
            @RequestParam(required = false) String fecha,
            @RequestParam(required = false) String medicoId,
            @RequestParam(required = false) String estado,
            @RequestParam(required = false) String llegada,
            @RequestParam(required = false) String orden,
            @RequestParam(required = false) String sentido,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String size
    ) {
        return service.consultar(
                ci,
                consultaId,
                fecha,
                medicoId,
                estado,
                llegada,
                orden,
                sentido,
                page,
                size
        );
    }
}
