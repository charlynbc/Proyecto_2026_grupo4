package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

class SesionTokenServiceTest {

    private final SesionRepository repository = mock(SesionRepository.class);
    private final SesionTokenService service = new SesionTokenService(
            repository,
            604800
    );

    @Test
    void emiteUnTokenOpacoYAlmacenaSoloSuHash() {
        SesionTokenService.Emitido emitido = service.emitir(15L);
        ArgumentCaptor<String> hash = ArgumentCaptor.forClass(String.class);

        verify(repository).crear(eq(15L), hash.capture(), any());
        assertTrue(emitido.token().startsWith("v2."));
        assertNotEquals(emitido.token(), hash.getValue());
        assertTrue(hash.getValue().matches("[0-9a-f]{64}"));
    }

    @Test
    void rotaTokenDeUsoUnico() {
        when(repository.rotar(any(), any(), any())).thenReturn(Optional.of(15L));

        SesionTokenService.Rotado rotado = service.rotar("v2.token-anterior");

        assertTrue(rotado.token().startsWith("v2."));
        assertNotEquals("v2.token-anterior", rotado.token());
        verify(repository).rotar(any(), any(), any());
    }

    @Test
    void rechazaUnTokenDeOtroFormato() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.rotar("token-legado")
        );

        assertTrue(error.getStatus() == HttpStatus.UNAUTHORIZED);
    }
}
