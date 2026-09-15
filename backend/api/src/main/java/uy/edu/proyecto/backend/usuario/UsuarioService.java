package uy.edu.proyecto.backend.usuario;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;

    public UsuarioService(
            UsuarioRepository usuarioRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public Usuario crear(CrearUsuarioRequest request) {

        String nombre = request.nombre().trim();

        String cedula = normalizarCedula(
                request.cedula()
        );

        String passwordHash = passwordEncoder.encode(
                request.clave()
        );

        return usuarioRepository.crear(
                nombre,
                cedula,
                passwordHash
        );
    }

    private String normalizarCedula(String cedula) {
        return cedula.replaceAll("[.\\-\\s]", "");
    }
}