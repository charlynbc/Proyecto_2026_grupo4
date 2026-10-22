package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository.CuentaAutenticacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.security.JwtService;

class AuthServiceTest {

    private final CuentaAuthRepository cuentaAuthRepository =
            mock(CuentaAuthRepository.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final JwtService jwtService = mock(JwtService.class);
    private final SesionTokenService sesionTokenService =
            mock(SesionTokenService.class);
    private final AuthService service = new AuthService(
            cuentaAuthRepository,
            passwordEncoder,
            jwtService,
            sesionTokenService
    );

    @Test
    void iniciaSesionDeSocioConDatosDelPadron() {
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

        AuthResult result = service.login(
                new LoginRequest("67890127", "secreto", "SOCIO", "ANDROID")
        );

        assertEquals("jwt", result.response().token());
        assertEquals("SOCIO", result.response().role());
        assertEquals("Ana", result.response().nombre());
        assertEquals("Perez", result.response().apellido());
        assertEquals("v2.refresh", result.refreshToken());
    }

    @Test
    void socioPuedeIniciarSesionSinPlataforma() {
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
        when(sesionTokenService.emitir(12L))
                .thenReturn(new SesionTokenService.Emitido("v2.refresh", 604800L));

        AuthResult result = service.login(
                new LoginRequest("67890127", "secreto", "SOCIO", null)
        );

        assertEquals("jwt", result.response().token());
    }

    @Test
    void empleadoDebeEntrarDesdeLaWeb() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(
                        new LoginRequest("67890127", "secreto", "EMPLEADO", "ANDROID")
                )
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        assertEquals("CREDENCIALES_INVALIDAS", error.getCode());
        verify(cuentaAuthRepository, never()).buscarParaLogin(
                "67890127",
                "EMPLEADO"
        );
    }

    @Test
    void empleadoSinPlataformaEsValidacionYNoConsultaCuentas() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(
                        new LoginRequest("67890127", "secreto", "EMPLEADO", null)
                )
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(cuentaAuthRepository);
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

        AuthResult result = service.login(
                new LoginRequest("67890127", "secreto", "EMPLEADO", "WEB")
        );

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
                () -> service.login(
                        new LoginRequest("67890127", "secreto", "SOCIO", "WEB")
                )
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
                () -> service.login(
                        new LoginRequest("67890128", "secreto", "SOCIO", "WEB")
                )
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
                () -> service.login(
                        new LoginRequest("67890127", "incorrecta", "SOCIO", "WEB")
                )
        );

        assertEquals(ciInvalida.getStatus(), claveIncorrecta.getStatus());
        assertEquals(ciInvalida.getCode(), claveIncorrecta.getCode());
        assertEquals(ciInvalida.getMessage(), claveIncorrecta.getMessage());
    }

    @Test
    void rechazaAccesoFueraDelContratoComoValidacion() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(
                        new LoginRequest("67890127", "secreto", "ADMINISTRADOR", "WEB")
                )
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void credencialesAntiguasCedulaYClaveNoHabilitanAcceso() {
        // Un cuerpo {"cedula","clave"} se deserializa con todos los campos del contrato nulos.
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.login(new LoginRequest(null, null, null, null))
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        verifyNoInteractions(cuentaAuthRepository, passwordEncoder, jwtService, sesionTokenService);
    }

    @Test
    void renuevaSesionYEmiteElRolActualDeLaCuenta() {
        CuentaAutenticacion cuenta = new CuentaAutenticacion(
                12L,
                "Ana",
                "Perez",
                "hash",
                "MEDICO"
        );
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
    }

    @Test
    void refreshSinTokenEsNoAutorizado() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.refresh(" ")
        );

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        verifyNoInteractions(sesionTokenService);
    }
}
