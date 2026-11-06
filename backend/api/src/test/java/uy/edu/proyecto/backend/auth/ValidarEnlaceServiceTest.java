package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.exception.ApiException;

class ValidarEnlaceServiceTest {

    private final PrimerIngresoRepository primerIngreso = mock(PrimerIngresoRepository.class);
    private final RecuperacionRepository recuperacion = mock(RecuperacionRepository.class);
    private final SesionRepository sesiones = mock(SesionRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final ApplicationEventPublisher eventos = mock(ApplicationEventPublisher.class);
    private final PrimerIngresoService primerIngresoService =
            new PrimerIngresoService(primerIngreso, encoder, eventos, 8, 24);
    private final RecuperacionService recuperacionService =
            new RecuperacionService(recuperacion, sesiones, encoder, eventos, 8, 24);

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void soloConsultaElHashSinConsumirNiPublicarEventos(boolean primero) {
        String token = "token-aleatorio";
        String hash = TokenHash.sha256(token);
        if (primero) {
            when(primerIngreso.existeEnlaceVigente(hash)).thenReturn(true);
        } else {
            when(recuperacion.existeEnlaceVigente(hash)).thenReturn(true);
        }

        validar(primero, new ValidarEnlaceRequest(token));

        if (primero) {
            verify(primerIngreso).existeEnlaceVigente(hash);
        } else {
            verify(recuperacion).existeEnlaceVigente(hash);
        }
        verifyNoMoreInteractions(primerIngreso, recuperacion);
        verifyNoInteractions(sesiones, encoder, eventos);
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void devuelveElErrorExistenteSiNoEstaVigente(boolean primero) {
        assertEnlaceInvalido(primero, new ValidarEnlaceRequest("inexistente"));
        verifyNoInteractions(sesiones, encoder, eventos);
    }

    @ParameterizedTest
    @ValueSource(booleans = {true, false})
    void tokenAusenteONuloOVacioTieneElMismoErrorSinConsultar(boolean primero) {
        assertEnlaceInvalido(primero, null);
        assertEnlaceInvalido(primero, new ValidarEnlaceRequest(null));
        assertEnlaceInvalido(primero, new ValidarEnlaceRequest(""));
        assertEnlaceInvalido(primero, new ValidarEnlaceRequest("   "));
        verifyNoInteractions(primerIngreso, recuperacion, sesiones, encoder, eventos);
    }

    private void validar(boolean primero, ValidarEnlaceRequest request) {
        if (primero) {
            primerIngresoService.validarEnlace(request);
        } else {
            recuperacionService.validarEnlace(request);
        }
    }

    private void assertEnlaceInvalido(boolean primero, ValidarEnlaceRequest request) {
        ApiException error = assertThrows(ApiException.class, () -> validar(primero, request));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("ENLACE_INVALIDO", error.getCode());
        assertEquals("El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.",
                error.getMessage());
    }
}
