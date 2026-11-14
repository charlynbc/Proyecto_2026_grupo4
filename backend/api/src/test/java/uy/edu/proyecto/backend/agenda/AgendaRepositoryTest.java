package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgendaRepositoryTest {

    private static final OffsetDateTime MINIMO =
            OffsetDateTime.parse("2026-10-20T12:00:00-03:00");
    private static final OffsetDateTime MAXIMO =
            OffsetDateTime.parse("2026-10-30T08:00:00-03:00");

    @Test
    void consultaSoloMedicoNoFiltraEspecialidadYConservaVentana() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(),
                org.mockito.ArgumentMatchers
                        .<org.springframework.jdbc.core.RowMapper<NumeroDisponibleDTO>>any(),
                any(Object[].class))).thenReturn(List.of());
        new AgendaRepository(jdbc).consultarDisponibilidad(
                new FiltroDisponibilidadDTO(null, 17L, null, null, "fecha", "asc"),
                MINIMO, MAXIMO);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(),
                org.mockito.ArgumentMatchers
                        .<org.springframework.jdbc.core.RowMapper<NumeroDisponibleDTO>>any(),
                parametros.capture());
        assertFalse(sql.getValue().contains("ts.id_especialidad = ?"));
        assertTrue(sql.getValue().contains("ts.id_medico = ?"));
        assertTrue(sql.getValue().contains("c.habilitada = TRUE"));
        assertEquals(List.of(MINIMO, MAXIMO, 17L), Arrays.asList(parametros.getValue()));
    }

    @Test
    void aplicaVentanaSuspensionesOcupacionFiltrosYOrdenSinEscrituras()
            throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<org.springframework.jdbc.core.RowMapper<NumeroDisponibleDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AgendaRepository repository = new AgendaRepository(jdbcTemplate);

        repository.consultarDisponibilidad(new FiltroDisponibilidadDTO(
                3L,
                17L,
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 11, 20),
                "apellidoMedico",
                "desc"
        ), MINIMO, MAXIMO);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametrosCaptor =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(
                sqlCaptor.capture(),
                org.mockito.ArgumentMatchers
                        .<org.springframework.jdbc.core.RowMapper<NumeroDisponibleDTO>>any(),
                parametrosCaptor.capture()
        );

        String sql = sqlCaptor.getValue();
        assertTrue(sql.contains("t.estado = 'ACTIVO'"));
        assertTrue(sql.replaceAll("\\s+", " ").contains(
                "((t.fecha + n.hora_inicio) AT TIME ZONE 'America/Montevideo') >= ? "
                + "AND ((t.fecha + n.hora_inicio) AT TIME ZONE 'America/Montevideo') <= ?"));
        assertFalse(sql.contains("INTERVAL"));
        assertFalse(sql.contains("CURRENT_TIMESTAMP"));
        assertTrue(sql.contains("consulta.estado = 'AGENDADA'"));
        assertTrue(sql.contains("p.apellido DESC"));
        assertTrue(sql.contains("t.fecha >= ?"));
        assertTrue(sql.contains("t.fecha <= ?"));
        assertFalse(sql.contains("INSERT INTO"));
        assertFalse(sql.contains("UPDATE "));
        assertEquals(
                List.of(
                        MINIMO,
                        MAXIMO,
                        3L,
                        17L,
                        LocalDate.of(2026, 10, 20),
                        LocalDate.of(2026, 11, 20)
                ),
                Arrays.asList(parametrosCaptor.getValue())
        );
    }
}
