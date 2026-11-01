package uy.edu.proyecto.backend.agenda;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class CancelacionFuncionarioController {
    private final CancelacionFuncionarioService service;

    public CancelacionFuncionarioController(CancelacionFuncionarioService service) {
        this.service = service;
    }

    @PostMapping("/api/funcionario/consultas/{id}/cancelar")
    public CancelacionDTO cancelar(@PathVariable String id, @AuthenticationPrincipal Jwt jwt) {
        try {
            long funcionarioId = Long.parseLong(jwt.getSubject());
            return service.cancelar(funcionarioId, id);
        } catch (NumberFormatException exception) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO",
                    "La sesión no es válida");
        }
    }
}
