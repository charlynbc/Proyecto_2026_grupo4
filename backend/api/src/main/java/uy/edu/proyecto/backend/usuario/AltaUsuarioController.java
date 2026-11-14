package uy.edu.proyecto.backend.usuario;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/usuarios")
public class AltaUsuarioController {

    private final AltaUsuarioService service;
    private final UsuarioService usuarioService;

    public AltaUsuarioController(
            AltaUsuarioService service,
            UsuarioService usuarioService
    ) {
        this.service = service;
        this.usuarioService = usuarioService;
    }

    @GetMapping
    public UsuarioCuentaPageResponse listar(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(name = "rol", required = false) String rol,
            @RequestParam(name = "estado", required = false) String estado,
            @RequestParam(name = "texto", required = false) String texto,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size
    ) {
        // q es el contrato de Flutter; texto se conserva como alias.
        if (q != null && !q.isBlank() && texto != null && !texto.isBlank()
                && !q.trim().equals(texto.trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "q y texto no pueden contener búsquedas diferentes");
        }
        String busqueda = q != null && !q.isBlank() ? q : texto;
        if (orden == null && sentido == null) {
            return usuarioService.listar(idCuenta(jwt), rol, estado, busqueda, page, size);
        }
        return usuarioService.listar(
                idCuenta(jwt), rol, estado, busqueda, orden, sentido, page, size);
    }

    @PostMapping
    public ResponseEntity<CuentaCreadaResponse> crear(
            @RequestBody AltaUsuarioRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(service.crear(request));
    }

    private static long idCuenta(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException | NullPointerException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }
}
