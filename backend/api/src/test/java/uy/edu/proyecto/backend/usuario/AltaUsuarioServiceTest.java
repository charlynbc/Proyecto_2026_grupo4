package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

class AltaUsuarioServiceTest {

    private final CuentaRepository repository = mock(CuentaRepository.class);
    private final AltaUsuarioService service = new AltaUsuarioService(repository);

    @Test
    void creaPersonaYCuentaSocioPendienteSinAsignarContrasena() {
        AltaUsuarioRequest request = request("SOCIO", List.of());
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.crearCuenta(
                "67890127",
                "SOCIO",
                "ana@example.org",
                "099111222",
                null,
                null
        )).thenReturn(12L);

        CuentaCreadaResponse response = service.crear(request);

        assertEquals(12L, response.id());
        assertEquals("SOCIO", response.rol());
        assertEquals("ACTIVA", response.estado());
        assertFalse(response.activada());
        verify(repository).crearPersonaSiNoExiste(
                "67890127",
                "Ana",
                "Perez",
                LocalDate.of(1990, 1, 1)
        );
    }

    @Test
    void normalizaCiCorreoYCamposOpcionales() {
        AltaUsuarioRequest request = new AltaUsuarioRequest(
                "6.789.012-7",
                " Ana ",
                " Perez ",
                LocalDate.of(1990, 1, 1),
                " ANA@Example.org ",
                " 099111222 ",
                " ",
                " ",
                "SOCIO",
                null
        );
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.crearCuenta(
                "67890127",
                "SOCIO",
                "ana@example.org",
                "099111222",
                null,
                null
        )).thenReturn(12L);

        service.crear(request);

        verify(repository).crearCuenta(
                "67890127",
                "SOCIO",
                "ana@example.org",
                "099111222",
                null,
                null
        );
    }

    @Test
    void rechazaCiInvalidaAntesDeConsultarRepositorio() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(new AltaUsuarioRequest(
                        "67890128",
                        "Ana",
                        "Perez",
                        LocalDate.of(1990, 1, 1),
                        "ana@example.org",
                        "099111222",
                        null,
                        null,
                        "SOCIO",
                        List.of()
                ))
        );

        assertEquals("CI_INVALIDA", error.getCode());
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaDatosPersonalesQueNoCoinciden() {
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(new CuentaRepository.PersonaRegistrada(
                        "67890127",
                        "Ana",
                        "Gomez",
                        LocalDate.of(1990, 1, 1)
                )));

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("SOCIO", List.of()))
        );

        assertEquals("DATOS_PERSONA_DISCORDANTES", error.getCode());
        assertEquals(HttpStatus.CONFLICT, error.getStatus());
    }

    @Test
    void rechazaSocioDuplicado() {
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.existeCuentaSocio("67890127")).thenReturn(true);

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("SOCIO", List.of()))
        );

        assertEquals("SOCIO_DUPLICADO", error.getCode());
        assertEquals(HttpStatus.CONFLICT, error.getStatus());
    }

    @Test
    void rechazaEmpleadoPendienteYaHabilitado() {
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.especialidadesExistentes(List.of(5L))).thenReturn(List.of(5L));
        when(repository.existeCuentaEmpleadoHabilitada("67890127")).thenReturn(true);

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("MEDICO", List.of(5L)))
        );

        assertEquals("EMPLEADO_DUPLICADO", error.getCode());
    }

    @Test
    void medicoRequiereEspecialidadExistenteYLaAsocia() {
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.especialidadesExistentes(List.of(5L))).thenReturn(List.of(5L));
        when(repository.crearCuenta(
                "67890127",
                "MEDICO",
                "ana@example.org",
                "099111222",
                null,
                null
        )).thenReturn(13L);

        service.crear(request("MEDICO", List.of(5L)));

        verify(repository).asociarEspecialidades(13L, List.of(5L));
    }

    @Test
    void rechazaMedicoSinEspecialidad() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("MEDICO", List.of()))
        );

        assertEquals("VALIDACION", error.getCode());
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaEspecialidadesNoExistentes() {
        when(repository.especialidadesExistentes(List.of(5L))).thenReturn(List.of());

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("MEDICO", List.of(5L)))
        );

        assertEquals("VALIDACION", error.getCode());
        verify(repository).especialidadesExistentes(List.of(5L));
    }

    @Test
    void convierteCarreraDeUnicidadEnDuplicadoDeCuenta() {
        when(repository.buscarPersonaParaActualizar("67890127"))
                .thenReturn(Optional.of(persona()));
        when(repository.crearCuenta(
                "67890127",
                "SOCIO",
                "ana@example.org",
                "099111222",
                null,
                null
        )).thenThrow(new DuplicateKeyException("unique"));

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("SOCIO", List.of()))
        );

        assertEquals("SOCIO_DUPLICADO", error.getCode());
    }

    @Test
    void rechazaEspecialidadesEnRolesNoMedicos() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(request("SOCIO", List.of(5L)))
        );

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    private AltaUsuarioRequest request(String rol, List<Long> especialidades) {
        return new AltaUsuarioRequest(
                "67890127",
                "Ana",
                "Perez",
                LocalDate.of(1990, 1, 1),
                "ana@example.org",
                "099111222",
                null,
                null,
                rol,
                especialidades
        );
    }

    private CuentaRepository.PersonaRegistrada persona() {
        return new CuentaRepository.PersonaRegistrada(
                "67890127",
                "Ana",
                "Perez",
                LocalDate.of(1990, 1, 1)
        );
    }
}
