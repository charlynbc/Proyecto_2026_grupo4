package uy.edu.proyecto.backend.usuario;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.auth.EmailVerificationService;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
        private final EmailVerificationService emailVerificationService;

    public UsuarioService(
            UsuarioRepository usuarioRepository,
            PasswordEncoder passwordEncoder,
            EmailVerificationService emailVerificationService
    ) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.emailVerificationService = emailVerificationService;
    }


        @Transactional
        public Usuario crearPaciente(
            CrearUsuarioRequest request
    ) {

        String nombre =
                request.nombre().trim();

        String cedula =
                normalizarCedula(
                        request.cedula()
                );

        String email = request.email().trim().toLowerCase();

        if (usuarioRepository.existeEmail(email)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "EMAIL_YA_REGISTRADO",
                    "Ya existe un usuario con ese email"
            );
        }

        String passwordHash =
                passwordEncoder.encode(
                        request.clave()
                );

        try {

            Usuario usuario = usuarioRepository.crear(
                    nombre,
                    cedula,
                    passwordHash,
                    email,
                    "PACIENTE"
            );

            emailVerificationService.enviarPara(
                    usuario.id(),
                    email
            );

            return usuario;

        } catch (DuplicateKeyException exception) {

            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CEDULA_YA_REGISTRADA",
                    "Ya existe un usuario con esa cedula"
            );
        }
    }


        @Transactional
        public void confirmarEmail(String token) {

                emailVerificationService.confirmar(token);
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
