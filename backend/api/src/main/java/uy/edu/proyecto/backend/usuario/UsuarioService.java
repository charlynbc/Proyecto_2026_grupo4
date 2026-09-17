package uy.edu.proyecto.backend.usuario;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

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


    public Usuario crearPaciente(
            CrearUsuarioRequest request
    ) {

        String nombre =
                request.nombre().trim();

        String cedula =
                normalizarCedula(
                        request.cedula()
                );

        String passwordHash =
                passwordEncoder.encode(
                        request.clave()
                );

        try {

            return usuarioRepository.crear(
                    nombre,
                    cedula,
                    passwordHash,
                    "PACIENTE"
            );

        } catch (DuplicateKeyException exception) {

            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CEDULA_YA_REGISTRADA",
                    "Ya existe un usuario con esa cedula"
            );
        }
    }


    private String normalizarCedula(
            String cedula
    ) {

        return cedula.replaceAll(
                "[.\\-\\s]",
                ""
        );
    }
}
