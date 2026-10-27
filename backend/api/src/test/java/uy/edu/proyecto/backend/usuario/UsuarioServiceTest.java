package uy.edu.proyecto.backend.usuario;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UsuarioServiceTest {

    @Mock
    private UsuarioPadronRepository repository;

    @Test
    void normalizaFiltrosYDelegaLaPaginacion() {
        UsuarioService service = new UsuarioService(repository);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(
                List.of(), 1, 10, 0
        );
        when(repository.listar("ADMINISTRADOR", "INACTIVA", "  45678911 ", "apellido", "asc", 1, 10))
                .thenReturn(expected);

        assertEquals(
                expected,
                service.listar(" administrador ", " inactiva ", "  45678911 ", 1, 10)
        );

        verify(repository).listar("ADMINISTRADOR", "INACTIVA", "  45678911 ", "apellido", "asc", 1, 10);
    }

    @Test
    void permiteListadoVacioSinFiltros() {
        UsuarioService service = new UsuarioService(repository);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(
                List.of(), 0, 20, 0
        );
        when(repository.listar(null, null, null, "apellido", "asc", 0, 20)).thenReturn(expected);

        assertEquals(expected, service.listar(null, null, null, 0, 20));
    }

    @Test
    void rechazaOrdenYSentidoInvalidos() {
        UsuarioService service = new UsuarioService(repository);

        assertThrows(ApiException.class,
                () -> service.listar(null, null, null, "contrasena", "asc", 0, 20));
        assertThrows(ApiException.class,
                () -> service.listar(null, null, null, "apellido", "arriba", 0, 20));

        verifyNoInteractions(repository);
    }

    @Test
    void ordenYSentidoPorDefectoSeConservanEnLaFirmaHistorica() {
        UsuarioService service = new UsuarioService(repository);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(List.of(), 0, 20, 0);
        when(repository.listar(null, null, null, "fechaAlta", "desc", 0, 20)).thenReturn(expected);

        assertEquals(expected, service.listar(null, null, null, "fechaAlta", " DESC ", 0, 20));
    }

    @Test
    void rechazaFiltrosYPaginacionInvalidosAntesDeConsultar() {
        UsuarioService service = new UsuarioService(repository);

        assertThrows(ApiException.class, () -> service.listar("ROOT", null, null, 0, 20));
        assertThrows(ApiException.class, () -> service.listar(null, "BORRADA", null, 0, 20));
        assertThrows(ApiException.class, () -> service.listar(null, null, null, -1, 20));
        assertThrows(ApiException.class, () -> service.listar(null, null, null, 0, 101));

        verifyNoInteractions(repository);
    }
}
