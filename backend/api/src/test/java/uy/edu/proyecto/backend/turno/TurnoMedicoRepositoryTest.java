package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TurnoMedicoRepositoryTest {

    @Test
    void filtraListaPorMedicoPropioYFecha() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                any(RowMapper.class),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoMedicoRepository repository =
                new TurnoMedicoRepository(jdbcTemplate);

        repository.listar(17L, LocalDate.of(2026, 10, 20));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(
                sql.capture(),
                any(RowMapper.class),
                parametros.capture()
        );
        assertTrue(sql.getValue().contains("WHERE ts.id_medico = ? AND t.fecha = ?"));
        assertTrue(sql.getValue().contains("cantidad_reservados"));
        assertEquals(17L, parametros.getValue()[0]);
        assertEquals(LocalDate.of(2026, 10, 20), parametros.getValue()[1]);
    }

    @Test
    void filtraLlegadaYOrdenDeFormaSeguraYCalculaDisponibilidad() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                any(RowMapper.class),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoMedicoRepository repository =
                new TurnoMedicoRepository(jdbcTemplate);

        repository.obtenerNumeros(
                17L,
                301L,
                true,
                "horaLlegada",
                "desc",
                OffsetDateTime.parse("2026-10-20T10:00:00-03:00"),
                OffsetDateTime.parse("2026-11-19T08:00:00-03:00")
        );

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(
                sql.capture(),
                any(RowMapper.class),
                parametros.capture()
        );
        assertTrue(sql.getValue().contains("ts.id_medico = ? AND t.id_turno = ?"));
        assertTrue(sql.getValue().contains("aviso.id_aviso_llegada IS NOT NULL"));
        assertTrue(sql.getValue().contains("ORDER BY aviso.registrada_en DESC NULLS LAST"));
        assertTrue(sql.getValue().contains("AT TIME ZONE 'America/Montevideo'"));
        assertTrue(sql.getValue().contains("paciente.id_cuenta AS paciente_id"));
        assertTrue(sql.getValue().replaceAll("\\s+", " ").contains(
                "AND ((t.fecha + n.hora_inicio) AT TIME ZONE 'America/Montevideo') >= ? "
                + "AND ((t.fecha + n.hora_inicio) AT TIME ZONE 'America/Montevideo') <= ? "
                + ") AS disponible"));
        assertFalse(sql.getValue().contains("t.fecha BETWEEN"));
        assertEquals(
                List.of(
                        OffsetDateTime.parse("2026-10-20T10:00:00-03:00"),
                        OffsetDateTime.parse("2026-11-19T08:00:00-03:00"),
                        17L,
                        301L
                ),
                java.util.Arrays.asList(parametros.getValue()));
    }
}
