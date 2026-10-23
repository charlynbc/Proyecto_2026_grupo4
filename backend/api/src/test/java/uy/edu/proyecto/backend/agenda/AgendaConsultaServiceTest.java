package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
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
class AgendaConsultaServiceTest {

    private static final LocalDate HOY = LocalDate.of(2026, 10, 23);
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-23T15:00:00Z"),
            ZoneId.of("America/Montevideo")
    );

    @Mock
    private AgendaConsultaRepository repository;

    private AgendaConsultaService service;

    @BeforeEach
    void setUp() {
        service = new AgendaConsultaService(repository, RELOJ);
    }

    @Test
    void listaSinFiltrosConOrdenYPaginacionPredeterminados() {
        AgendaOperativaPageResponse esperada =
                new AgendaOperativaPageResponse(List.of(), 0, 20, 0);
        when(repository.listar(
                new FiltroAgendaDTO(
                        null, null, null, null, null, null,
                        "fechaHora", "asc", 0, 20
                ),
                HOY
        )).thenReturn(esperada);

        AgendaOperativaPageResponse respuesta = consultar(null, null, null,
                null, null, null, null, null, null, null);

        assertEquals(esperada, respuesta);
        verify(repository).listar(
                new FiltroAgendaDTO(
                        null, null, null, null, null, null,
                        "fechaHora", "asc", 0, 20
                ),
                HOY
        );
    }

    @Test
    void convierteTodosLosFiltrosOpcionalesYParametrosDePagina() {
        FiltroAgendaDTO filtro = new FiltroAgendaDTO(
                "67890127",
                9001L,
                HOY,
                17L,
                "CANCELADA_INSTITUCION",
                true,
                "horaLlegada",
                "desc",
                2,
                35
        );
        when(repository.listar(filtro, HOY))
                .thenReturn(new AgendaOperativaPageResponse(List.of(), 2, 35, 81));

        AgendaOperativaPageResponse respuesta = consultar(
                "67.890.127",
                "9001",
                "2026-10-23",
                "17",
                "CANCELADA_INSTITUCION",
                "true",
                "horaLlegada",
                "desc",
                "2",
                "35"
        );

        assertEquals(81, respuesta.total());
        verify(repository).listar(filtro, HOY);
    }

    @Test
    void convierteLlegadaFalsaYAdmiteFiltrosDeFechaYEstado() {
        FiltroAgendaDTO filtro = new FiltroAgendaDTO(
                null, null, HOY, 17L, "AGENDADA", false,
                "fechaHora", "asc", 0, 20
        );
        when(repository.listar(filtro, HOY))
                .thenReturn(new AgendaOperativaPageResponse(List.of(), 0, 20, 0));

        AgendaOperativaPageResponse respuesta = consultar(
                null, null, "2026-10-23", "17", "AGENDADA",
                "false", null, null, null, null
        );

        assertEquals(0, respuesta.total());
        verify(repository).listar(filtro, HOY);
    }

    @Test
    void rechazaIdsFechasBooleanosYOpcionesInvalidasSinConsultarRepositorio() {
        assertValidacion(() -> consultar(null, "0", null, null, null,
                null, null, null, null, null));
        assertValidacion(() -> consultar(null, "abc", null, null, null,
                null, null, null, null, null));
        assertValidacion(() -> consultar(null, null, "23/10/2026", null, null,
                null, null, null, null, null));
        assertValidacion(() -> consultar(null, null, null, "-2", null,
                null, null, null, null, null));
        assertValidacion(() -> consultar(null, null, null, null, null,
                "yes", null, null, null, null));
        assertValidacion(() -> consultar(null, null, null, null, "INVALIDO",
                null, null, null, null, null));
        assertValidacion(() -> consultar(null, null, null, null, null,
                null, "medico", null, null, null));
        assertValidacion(() -> consultar(null, null, null, null, null,
                null, null, "up", null, null));
        assertValidacion(() -> consultar(null, null, null, null, null,
                null, null, null, "-1", null));
        assertValidacion(() -> consultar(null, null, null, null, null,
                null, null, null, null, "101"));
        assertValidacion(() -> consultar(null, null, null, null, null,
                null, null, null, null, "0"));
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaCedulaConDigitoVerificadorInvalido() {
        assertValidacion(() -> consultar("45678910", null, null, null, null,
                null, null, null, null, null));
        verifyNoInteractions(repository);
    }

    private AgendaOperativaPageResponse consultar(
            String ci,
            String consultaId,
            String fecha,
            String medicoId,
            String estado,
            String llegada,
            String orden,
            String sentido,
            String page,
            String size
    ) {
        return service.consultar(
                ci, consultaId, fecha, medicoId, estado, llegada,
                orden, sentido, page, size
        );
    }

    private void assertValidacion(Runnable operation) {
        ApiException exception = assertThrows(ApiException.class, operation::run);
        assertEquals("VALIDACION", exception.getCode());
    }
}
