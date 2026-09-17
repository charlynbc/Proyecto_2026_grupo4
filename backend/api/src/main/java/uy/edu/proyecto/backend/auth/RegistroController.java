package uy.edu.proyecto.backend.auth;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.usuario.CrearUsuarioRequest;
import uy.edu.proyecto.backend.usuario.Usuario;
import uy.edu.proyecto.backend.usuario.UsuarioService;

@RestController
@RequestMapping("/api/auth")
public class RegistroController {

    private final UsuarioService usuarioService;

    public RegistroController(
            UsuarioService usuarioService
    ) {
        this.usuarioService = usuarioService;
    }


    @PostMapping("/registro")
    public ResponseEntity<Usuario> registrar(
            @Valid
            @RequestBody
            CrearUsuarioRequest request
    ) {

        Usuario usuario =
                usuarioService
                        .crearPaciente(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(usuario);
    }
}
