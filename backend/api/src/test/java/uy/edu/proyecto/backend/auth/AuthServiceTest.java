package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository.CuentaAutenticacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.security.JwtService;
import uy.edu.proyecto.backend.usuario.UsuarioCredenciales;
import uy.edu.proyecto.backend.usuario.UsuarioRepository;

class AuthServiceTest {

    private final UsuarioRepository usuarioRepository = mock(UsuarioRepository.class);
    private final CuentaAuthRepository cuentaAuthRepository =
            mock(CuentaAuthRepository.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final JwtService jwtService = mock(JwtService.class);
    private final RefreshTokenService refreshTokenService =
            mock(RefreshTokenService.class);
    private final SesionTokenService sesionTokenService =
            mock(SesionTokenService.class);
    private final AuthService service = new AuthService(
            usuarioRepository,
            cuentaAuthRepository,
            passwordEncoder,
            jwtService,
            refreshTokenService,
            sesionTokenService
    );

    @Test
    void iniciaSesionDeSocioConContratoNuevoYDatosDelPadron() {
        CuentaAutenticacion cuenta = new CuentaAutenticacion(
                12L,
                "Ana",
                "Perez",
                "hash",
                "SOCIO"
        );
        when(cuentaAuthRepository.buscarParaLogin("67890127", "SOCIO"))
                .thenReturn(Optional.of(cuenta));
        when(passwordEncoder.matches("secreto", "hash")).thenReturn(true);
        when(jwtService.generar(12L, "SOCIO")).thenReturn("jwt");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);
        when(sesionTokenService.emitir(12L))
                .thenReturn(new SesionTokenService.Emitido("v2.refresh", 604800L));

        AuthResult result = service.login(new LoginRequest(
                "67890127",
                "secreto",
                "SOCIO",
                "ANDROID",
                null,
                null
        ));

        assertEquals("jwt", result.response().token());
        assertEquals("SOCIO", result.response().role());
        assertEquals("Ana", result.response().nombre());
        assertEquals("Perez", result.response().apellido());
        assertEquals("v2.refresh", result.refreshToken());
        verify(refreshTokenService, never()).emitir(12L);
    }

    @Test
    void empleadoDebeEntrarDesdeLaWeb() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(
                        "67890127",
                        "secreto",
                        "EMPLEADO",
                        "ANDROID",
                        null,
                        null
                ))
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        assertEquals("CREDENCIALES_INVALIDAS", error.getCode());
        verify(cuentaAuthRepository, never()).buscarParaLogin(
                "67890127",
                "EMPLEADO"
        );
    }

    @Test
    void empleadoActivoPuedeIniciarSesionDesdeWebConSuRolReal() {
        CuentaAutenticacion cuenta = new CuentaAutenticacion(
                25L,
                "Luis",
                "Lopez",
                "hash",
                "FUNCIONARIO"
        );
        when(cuentaAuthRepository.buscarParaLogin("67890127", "EMPLEADO"))
                .thenReturn(Optional.of(cuenta));
        when(passwordEncoder.matches("secreto", "hash")).thenReturn(true);
        when(jwtService.generar(25L, "FUNCIONARIO")).thenReturn("jwt-empleado");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);
        when(sesionTokenService.emitir(25L))
                .thenReturn(new SesionTokenService.Emitido("v2.refresh", 604800L));

        AuthResult result = service.login(new LoginRequest(
                "67890127",
                "secreto",
                "EMPLEADO",
                "WEB",
                null,
                null
        ));

        assertEquals("FUNCIONARIO", result.response().role());
        assertEquals("Luis", result.response().nombre());
        verify(jwtService).generar(25L, "FUNCIONARIO");
    }

    @Test
    void rechazaCuentaPendienteConRespuestaGenerica() {
        when(cuentaAuthRepository.buscarParaLogin("67890127", "SOCIO"))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(
                        "67890127",
                        "secreto",
                        "SOCIO",
                        "WEB",
                        null,
                        null
                ))
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        assertEquals("CREDENCIALES_INVALIDAS", error.getCode());
        assertEquals(
                "La cedula o la contrasena no son correctas. Revisa los datos e intenta de nuevo.",
                error.getMessage()
        );
    }

    @Test
    void ciInvalidaYContrasenaIncorrectaTienenElMismoError() {
        ApiException ciInvalida = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(
                        "67890128",
                        "secreto",
                        "SOCIO",
                        "WEB",
                        null,
                        null
                ))
        );

        when(cuentaAuthRepository.buscarParaLogin("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaAutenticacion(
                        12L,
                        "Ana",
                        "Perez",
                        "hash",
                        "SOCIO"
                )));
        when(passwordEncoder.matches("incorrecta", "hash")).thenReturn(false);
        ApiException claveIncorrecta = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(
                        "67890127",
                        "incorrecta",
                        "SOCIO",
                        "WEB",
                        null,
                        null
                ))
        );

        assertEquals(ciInvalida.getStatus(), claveIncorrecta.getStatus());
        assertEquals(ciInvalida.getCode(), claveIncorrecta.getCode());
        assertEquals(ciInvalida.getMessage(), claveIncorrecta.getMessage());
    }

    @Test
    void rechazaAccesoFueraDelContratoComoValidacion() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(
                        "67890127",
                        "secreto",
                        "ADMINISTRADOR",
                        "WEB",
                        null,
                        null
                ))
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void mantieneElLoginLegadoParaUsuariosExistentes() {
        UsuarioCredenciales usuario = new UsuarioCredenciales(
                3L,
                "Usuario legado",
                "1234567",
                "hash-legado",
                true,
                "PACIENTE"
        );
        when(usuarioRepository.buscarParaLogin("1234567"))
                .thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("clave", "hash-legado")).thenReturn(true);
        when(jwtService.generar(3L, "PACIENTE")).thenReturn("jwt-legado");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);
        when(refreshTokenService.emitir(3L))
                .thenReturn(new RefreshTokenService.Emitido("refresh-legado", 604800L));

        AuthResult result = service.login(new LoginRequest(
                null,
                null,
                null,
                null,
                "1234567",
                "clave"
        ));

        assertEquals("jwt-legado", result.response().token());
        assertEquals("PACIENTE", result.response().role());
        assertEquals("refresh-legado", result.refreshToken());
        verify(sesionTokenService, never()).emitir(3L);
    }

    @Test
    void renuevaSesionNuevaYEmiteElRolActualDeLaCuenta() {
        CuentaAutenticacion cuenta = new CuentaAutenticacion(
                12L,
                "Ana",
                "Perez",
                "hash",
                "MEDICO"
        );
        when(sesionTokenService.reconoceToken("v2.refresh-anterior"))
                .thenReturn(true);
        when(sesionTokenService.rotar("v2.refresh-anterior"))
                .thenReturn(new SesionTokenService.Rotado(12L, "v2.refresh-nuevo"));
        when(cuentaAuthRepository.buscarHabilitadaPorId(12L))
                .thenReturn(Optional.of(cuenta));
        when(jwtService.generar(12L, "MEDICO")).thenReturn("jwt-renovado");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);

        AuthResult result = service.refresh("v2.refresh-anterior");

        assertEquals("jwt-renovado", result.response().token());
        assertEquals("MEDICO", result.response().role());
        assertEquals("v2.refresh-nuevo", result.refreshToken());
        verify(refreshTokenService, never()).rotar("v2.refresh-anterior");
    }
}
