package uy.edu.proyecto.backend.medico;

import java.util.List;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.annotation.CurrentSecurityContext;
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
    public List<?> listar(
            @RequestParam(name = "especialidadId", required = false)
            Long especialidadId,
            @CurrentSecurityContext(expression = "authentication")
            Authentication authentication
    ) {
        List<MedicoDTO> medicos = service.listar(especialidadId);
        boolean esSocio = authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .anyMatch("ROLE_SOCIO"::equals);
        return esSocio
                ? medicos.stream().map(MedicoSocioDTO::desde).toList()
                : medicos;
    }
}
