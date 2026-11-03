package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.exception.ApiException;

class CambioContrasenaServiceTest {

    private final CuentaAuthRepository cuentaRepository =
            mock(CuentaAuthRepository.class);
    private final SesionRepository sesionRepository =
            mock(SesionRepository.class);
    private final PasswordEncoder passwordEncoder =
            mock(PasswordEncoder.class);
    private final CambioContrasenaService service = new CambioContrasenaService(
            cuentaRepository,
            sesionRepository,
            passwordEncoder,
            8
    );

    @Test
    void cambioCorrectoActualizaHashYRevocaLasDemasSesiones() {
        when(cuentaRepository.bloquearCredencial(42L))
                .thenReturn(Optional.of("hash-actual"));
        when(passwordEncoder.matches("Clave-Vieja-1", "hash-actual"))
                .thenReturn(true);
        when(passwordEncoder.encode("Clave-Nueva-1")).thenReturn("hash-nuevo");

        service.cambiar(
                42L,
                new CambiarContrasenaRequest("Clave-Vieja-1", "Clave-Nueva-1"),
                "v2.refresh-actual"
        );

        verify(cuentaRepository).actualizarContrasena(42L, "hash-nuevo");
        verify(sesionRepository).revocarOtrasSesiones(
                42L,
                TokenHash.sha256("v2.refresh-actual")
        );
    }

    @Test
    void sinCookieDeRenovacionRevocaTodasLasSesiones() {
        when(cuentaRepository.bloquearCredencial(42L))
                .thenReturn(Optional.of("hash-actual"));
        when(passwordEncoder.matches("Clave-Vieja-1", "hash-actual"))
                .thenReturn(true);
        when(passwordEncoder.encode("Clave-Nueva-1")).thenReturn("hash-nuevo");

        service.cambiar(
                42L,
                new CambiarContrasenaRequest("Clave-Vieja-1", "Clave-Nueva-1"),
                null
        );

        verify(sesionRepository).revocarOtrasSesiones(42L, null);
    }

    @Test
    void contrasenaActualIncorrectaRechazaSinTocarNada() {
        when(cuentaRepository.bloquearCredencial(42L))
                .thenReturn(Optional.of("hash-actual"));
        when(passwordEncoder.matches("no-es", "hash-actual"))
                .thenReturn(false);

        ApiException error = assertThrows(ApiException.class, () ->
                service.cambiar(
                        42L,
                        new CambiarContrasenaRequest("no-es", "Clave-Nueva-1"),
                        null
                ));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("CONTRASENA_ACTUAL_INCORRECTA", error.getCode());
        verify(cuentaRepository, never()).actualizarContrasena(eq(42L), anyString());
        verify(sesionRepository, never()).revocarOtrasSesiones(eq(42L), anyString());
    }

    @Test
    void cuentaInactivaOInexistenteRechazaComoNoAutenticado() {
        when(cuentaRepository.bloquearCredencial(42L))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.cambiar(
                        42L,
                        new CambiarContrasenaRequest("Clave-Vieja-1", "Clave-Nueva-1"),
                        null
                ));

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        assertEquals("NO_AUTENTICADO", error.getCode());
    }

    @Test
    void contrasenaNuevaCortaRechazaAntesDeTocarLaBase() {
        ApiException error = assertThrows(ApiException.class, () ->
                service.cambiar(
                        42L,
                        new CambiarContrasenaRequest("Clave-Vieja-1", "corta"),
                        null
                ));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractionsWithLaBase();
    }

    @Test
    void contrasenaNuevaDeMasDe72BytesRechaza() {
        String larga = "a".repeat(73);

        ApiException error = assertThrows(ApiException.class, () ->
                service.cambiar(
                        42L,
                        new CambiarContrasenaRequest("Clave-Vieja-1", larga),
                        null
                ));

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractionsWithLaBase();
    }

    @Test
    void camposFaltantesRechazan() {
        for (CambiarContrasenaRequest request : new CambiarContrasenaRequest[]{
                null,
                new CambiarContrasenaRequest(null, "Clave-Nueva-1"),
                new CambiarContrasenaRequest("  ", "Clave-Nueva-1"),
                new CambiarContrasenaRequest("Clave-Vieja-1", null),
                new CambiarContrasenaRequest("Clave-Vieja-1", " ")
        }) {
            ApiException error = assertThrows(ApiException.class, () ->
                    service.cambiar(42L, request, null));
            assertEquals("VALIDACION", error.getCode());
        }
        verifyNoInteractionsWithLaBase();
    }

    private void verifyNoInteractionsWithLaBase() {
        verify(cuentaRepository, never()).bloquearCredencial(42L);
        verify(cuentaRepository, never()).actualizarContrasena(eq(42L), anyString());
        verify(sesionRepository, never()).revocarOtrasSesiones(eq(42L), anyString());
    }
}
