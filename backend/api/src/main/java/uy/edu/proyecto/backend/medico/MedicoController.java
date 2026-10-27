package uy.edu.proyecto.backend.medico;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MedicoController {

    private final MedicoService service;

    public MedicoController(MedicoService service) {
        this.service = service;
    }

    @GetMapping("/api/medicos")
    public List<MedicoDTO> listar(
            @RequestParam(name = "especialidadId", required = false)
            Long especialidadId
    ) {
        return service.listar(especialidadId);
    }
}
