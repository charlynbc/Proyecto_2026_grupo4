package uy.edu.proyecto.backend.usuario;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

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
            @RequestParam(name = "rol", required = false) String rol,
            @RequestParam(name = "estado", required = false) String estado,
            @RequestParam(name = "texto", required = false) String texto,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size
    ) {
        return usuarioService.listar(rol, estado, texto, page, size);
    }

    @PostMapping
    public ResponseEntity<CuentaCreadaResponse> crear(
            @RequestBody AltaUsuarioRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(service.crear(request));
    }
}
