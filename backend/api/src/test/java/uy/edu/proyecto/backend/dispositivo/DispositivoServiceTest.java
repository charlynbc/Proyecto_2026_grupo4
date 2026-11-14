package uy.edu.proyecto.backend.dispositivo;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DispositivoServiceTest {

    private static final OffsetDateTime REGISTRADO =
            OffsetDateTime.parse("2026-10-14T10:20:00-03:00");
    private static final String MENSAJE_FALTA =
            "Falta el identificador del dispositivo para las notificaciones.";
    private static final String MENSAJE_LARGO =
            "El identificador del dispositivo para las notificaciones es demasiado largo "
                    + "(máximo 4096 caracteres).";

    @Mock
    private DispositivoRepository repository;

    private DispositivoService service() {
        return new DispositivoService(repository);
    }

    private static DispositivoRegistro registro(boolean creado) {
        return new DispositivoRegistro(new DispositivoDTO(61L, true, REGISTRADO), creado);
    }

    private static void assertValidacion(ApiException error, String mensaje) {
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        assertEquals(mensaje, error.getMessage());
    }

    @Test
    void registroNuevoDevuelveLoQueDaElRepositorioComoCreado() {
        when(repository.registrar(91L, "fcm-token-1")).thenReturn(registro(true));

        DispositivoRegistro resultado = service().registrar(91L, "fcm-token-1");

        assertTrue(resultado.creado());
        assertEquals(61L, resultado.dispositivo().id());
        assertTrue(resultado.dispositivo().habilitado());
        assertEquals(REGISTRADO, resultado.dispositivo().registradoEn());
    }

    @Test
    void registroDeUnaFilaExistenteNoEsCreado() {
        when(repository.registrar(91L, "fcm-token-1")).thenReturn(registro(false));

        assertFalse(service().registrar(91L, "fcm-token-1").creado());
    }

    @Test
    void elRegistroRecortaLosEspaciosDelPrincipioYDelFinal() {
        when(repository.registrar(91L, "fcm-token-1")).thenReturn(registro(true));

        service().registrar(91L, "  fcm-token-1 \t");

        verify(repository).registrar(91L, "fcm-token-1");
    }

    @Test
    void elRegistroRechazaTokenNuloVacioOSoloEspacios() {
        for (String token : new String[] {null, "", "   ", " \t "}) {
            ApiException error = assertThrows(ApiException.class,
                    () -> service().registrar(91L, token));
            assertValidacion(error, MENSAJE_FALTA);
        }

        verifyNoInteractions(repository);
    }

    @Test
    void elRegistroRechazaUnTokenDe4097Caracteres() {
        ApiException error = assertThrows(ApiException.class,
                () -> service().registrar(91L, "a".repeat(4097)));

        assertValidacion(error, MENSAJE_LARGO);
        verifyNoInteractions(repository);
    }

    @Test
    void elRegistroAceptaUnTokenDe4096Caracteres() {
        String token = "a".repeat(4096);
        when(repository.registrar(91L, token)).thenReturn(registro(true));

        assertTrue(service().registrar(91L, token).creado());
    }

    @Test
    void elLimiteSeMideDespuesDeRecortar() {
        String token = "a".repeat(4096);
        when(repository.registrar(91L, token)).thenReturn(registro(true));

        service().registrar(91L, "  " + token + "  ");

        verify(repository).registrar(91L, token);
    }

    @Test
    void unTokenDe4097DespuesDeRecortarSeRechaza() {
        ApiException error = assertThrows(ApiException.class,
                () -> service().registrar(91L, "  " + "a".repeat(4097) + "  "));

        assertValidacion(error, MENSAJE_LARGO);
        verifyNoInteractions(repository);
    }

    @Test
    void laBajaDeshabilitaElTokenRecortadoDelSocio() {
        service().darDeBaja(91L, "  fcm-token-1  ");

        verify(repository).deshabilitar(91L, "fcm-token-1");
    }

    @Test
    void laBajaDeUnTokenQueNoExisteNoFalla() {
        when(repository.deshabilitar(91L, "fcm-token-ajeno")).thenReturn(0);

        service().darDeBaja(91L, "fcm-token-ajeno");

        verify(repository).deshabilitar(91L, "fcm-token-ajeno");
    }

    @Test
    void laBajaAplicaLaMismaValidacionDelToken() {
        for (String token : new String[] {null, "", "   "}) {
            ApiException error = assertThrows(ApiException.class,
                    () -> service().darDeBaja(91L, token));
            assertValidacion(error, MENSAJE_FALTA);
        }
        ApiException largo = assertThrows(ApiException.class,
                () -> service().darDeBaja(91L, "a".repeat(4097)));
        assertValidacion(largo, MENSAJE_LARGO);

        verifyNoInteractions(repository);
    }
}
