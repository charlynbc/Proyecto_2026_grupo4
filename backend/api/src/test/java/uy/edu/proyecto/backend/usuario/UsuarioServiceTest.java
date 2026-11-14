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

    private static final long ADMIN = 1L;
    private static final java.time.Clock RELOJ = java.time.Clock.fixed(
            java.time.Instant.parse("2026-11-04T12:00:00Z"),
            java.time.ZoneId.of("America/Montevideo"));

    @Mock
    private UsuarioPadronRepository repository;

    @Mock
    private CuentaRepository cuentaRepository;

    private static UsuarioCuentaDTO fila(long id, String rol, String estado) {
        return new UsuarioCuentaDTO(
                id, "4567891" + id, "Nombre", "Apellido", rol, "u" + id + "@example.org",
                estado, true, java.time.OffsetDateTime.parse("2026-09-01T09:00:00-03:00"),
                false);
    }

    private UsuarioCuentaPageResponse paginaConTodosLosCasos() {
        return new UsuarioCuentaPageResponse(List.of(
                fila(1, "ADMINISTRADOR", "ACTIVA"),
                fila(2, "FUNCIONARIO", "ACTIVA"),
                fila(3, "FUNCIONARIO", "INACTIVA"),
                fila(4, "SOCIO", "ACTIVA"),
                fila(5, "MEDICO", "ACTIVA"),
                fila(6, "MEDICO", "ACTIVA"),
                fila(7, "MEDICO", "ACTIVA"),
                fila(8, "ADMINISTRADOR", "ACTIVA"),
                fila(9, "MEDICO", "INACTIVA")
        ), 0, 20, 9);
    }

    private List<Boolean> banderas(UsuarioCuentaPageResponse pagina) {
        return pagina.items().stream().map(UsuarioCuentaDTO::puedeInactivar).toList();
    }

    @Test
    void cadaFilaTraePuedeInactivarSegunLaRegla() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        when(repository.listar(null, null, null, "apellido", "asc", 0, 20))
                .thenReturn(paginaConTodosLosCasos());
        java.time.LocalDate hoy = java.time.LocalDate.of(2026, 11, 4);
        when(cuentaRepository.medicosConFechasActivasDesde(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq(hoy)))
                .thenReturn(java.util.Set.of(5L));
        when(cuentaRepository.medicosConConsultasAgendadasDesde(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq(hoy)))
                .thenReturn(java.util.Set.of(6L));

        UsuarioCuentaPageResponse pagina = service.listar(ADMIN, null, null, null, 0, 20);

        // 1 propia, 2 funcionario libre, 3 inactiva, 4 socio, 5 turnos, 6 consultas,
        // 7 medico libre, 8 otro administrador, 9 medico inactivo.
        assertEquals(
                List.of(false, true, false, false, false, false, true, true, false),
                banderas(pagina));
    }

    @Test
    void laAgendaSePideEnLoteUnaVezConLosMedicosDeLaPagina() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        when(repository.listar(null, null, null, "apellido", "asc", 0, 20))
                .thenReturn(paginaConTodosLosCasos());
        when(cuentaRepository.medicosConFechasActivasDesde(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(java.util.Set.of());
        when(cuentaRepository.medicosConConsultasAgendadasDesde(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenReturn(java.util.Set.of());

        service.listar(ADMIN, null, null, null, 0, 20);

        org.mockito.ArgumentCaptor<java.util.Collection<Long>> ids =
                org.mockito.ArgumentCaptor.forClass(java.util.Collection.class);
        verify(cuentaRepository, org.mockito.Mockito.times(1))
                .medicosConFechasActivasDesde(ids.capture(), org.mockito.ArgumentMatchers.any());
        assertEquals(java.util.Set.of(5L, 6L, 7L, 9L), new java.util.HashSet<>(ids.getValue()));
        verify(cuentaRepository, org.mockito.Mockito.times(1))
                .medicosConConsultasAgendadasDesde(
                        org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
        verify(cuentaRepository, org.mockito.Mockito.never())
                .medicoTieneFechasActivasDesde(
                        org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any());
        verify(cuentaRepository, org.mockito.Mockito.never())
                .medicoTieneConsultasAgendadasDesde(
                        org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void sinMedicosEnLaPaginaNoSeConsultaLaAgenda() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        when(repository.listar(null, null, null, "apellido", "asc", 0, 20))
                .thenReturn(new UsuarioCuentaPageResponse(List.of(
                        fila(1, "ADMINISTRADOR", "ACTIVA"),
                        fila(2, "FUNCIONARIO", "ACTIVA")), 0, 20, 2));

        UsuarioCuentaPageResponse pagina = service.listar(ADMIN, null, null, null, 0, 20);

        assertEquals(List.of(false, true), banderas(pagina));
        verifyNoInteractions(cuentaRepository);
    }

    @Test
    void normalizaFiltrosYDelegaLaPaginacion() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(
                List.of(), 1, 10, 0
        );
        when(repository.listar("ADMINISTRADOR", "INACTIVA", "  45678911 ", "apellido", "asc", 1, 10))
                .thenReturn(expected);

        assertEquals(
                expected,
                service.listar(ADMIN, " administrador ", " inactiva ", "  45678911 ", 1, 10)
        );

        verify(repository).listar("ADMINISTRADOR", "INACTIVA", "  45678911 ", "apellido", "asc", 1, 10);
    }

    @Test
    void permiteListadoVacioSinFiltros() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(
                List.of(), 0, 20, 0
        );
        when(repository.listar(null, null, null, "apellido", "asc", 0, 20)).thenReturn(expected);

        assertEquals(expected, service.listar(ADMIN, null, null, null, 0, 20));
    }

    @Test
    void rechazaOrdenYSentidoInvalidos() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);

        assertThrows(ApiException.class,
                () -> service.listar(ADMIN, null, null, null, "contrasena", "asc", 0, 20));
        assertThrows(ApiException.class,
                () -> service.listar(ADMIN, null, null, null, "apellido", "arriba", 0, 20));

        verifyNoInteractions(repository);
    }

    @Test
    void ordenYSentidoPorDefectoSeConservanEnLaFirmaHistorica() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);
        UsuarioCuentaPageResponse expected = new UsuarioCuentaPageResponse(List.of(), 0, 20, 0);
        when(repository.listar(null, null, null, "fechaAlta", "desc", 0, 20)).thenReturn(expected);

        assertEquals(expected, service.listar(ADMIN, null, null, null, "fechaAlta", " DESC ", 0, 20));
    }

    @Test
    void rechazaFiltrosYPaginacionInvalidosAntesDeConsultar() {
        UsuarioService service = new UsuarioService(repository, cuentaRepository, RELOJ);

        assertThrows(ApiException.class, () -> service.listar(ADMIN, "ROOT", null, null, 0, 20));
        assertThrows(ApiException.class, () -> service.listar(ADMIN, null, "BORRADA", null, 0, 20));
        assertThrows(ApiException.class, () -> service.listar(ADMIN, null, null, null, -1, 20));
        assertThrows(ApiException.class, () -> service.listar(ADMIN, null, null, null, 0, 101));

        verifyNoInteractions(repository);
    }
}
