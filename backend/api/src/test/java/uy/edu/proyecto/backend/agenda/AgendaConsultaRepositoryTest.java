package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgendaConsultaRepositoryTest {

    private static final LocalDate HOY = LocalDate.of(2026, 10, 23);

    @Test
    void paginaEnPostgresYDevuelveTotalIndependienteDeLosItems() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(
                anyString(),
                eq(Long.class),
                any(Object[].class)
        )).thenReturn(43L);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<AgendaOperativaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AgendaConsultaRepository repository = new AgendaConsultaRepository(jdbc);

        AgendaOperativaPageResponse page = repository.listar(
                new FiltroAgendaDTO(null, null, null, null, null, null,
                        "fechaHora", "asc", 2, 10),
                HOY
        );

        assertEquals(43, page.total());
        assertEquals(2, page.page());
        assertEquals(10, page.size());
        assertTrue(page.items().isEmpty());
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> params = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(
                sql.capture(),
                any(RowMapper.class),
                params.capture()
        );
        assertTrue(sql.getValue().contains("ORDER BY fecha ASC, hora_inicio ASC"));
        assertTrue(sql.getValue().contains("id_consulta ASC"));
        assertTrue(sql.getValue().contains("LIMIT ? OFFSET ?"));
        assertEquals(10, params.getValue()[1]);
        assertEquals(20L, params.getValue()[2]);
    }

    @Test
    void aplicaFiltrosPorLlegadaIncluyeTodasLasConsultasYNoDuplicaAvisos() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(
                anyString(),
                eq(Long.class),
                any(Object[].class)
        )).thenReturn(2L);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<AgendaOperativaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AgendaConsultaRepository repository = new AgendaConsultaRepository(jdbc);
        FiltroAgendaDTO filtro = new FiltroAgendaDTO(
                "67890127", 9001L, HOY, 17L, "CANCELADA_INSTITUCION", true,
                "horaLlegada", "desc", 0, 20
        );

        repository.listar(filtro, HOY);

        ArgumentCaptor<String> countSql =
                ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> countParams =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).queryForObject(
                countSql.capture(),
                eq(Long.class),
                countParams.capture()
        );
        String sql = countSql.getValue();
        assertTrue(sql.contains("LEFT JOIN public.aviso_llegada aviso"));
        assertTrue(sql.contains("aviso.id_socio = consulta.id_socio"));
        assertTrue(sql.contains("aviso.fecha = turno.fecha"));
        assertTrue(sql.contains("llegada_en IS NOT NULL"));
        assertTrue(sql.contains("socio_ci = ?"));
        assertTrue(sql.contains("id_consulta = ?"));
        assertTrue(sql.contains("fecha = ?"));
        assertTrue(sql.contains("id_medico = ?"));
        assertTrue(sql.contains("estado = ?"));
        assertTrue(sql.contains("CASE"));
        assertTrue(sql.contains("'NO_ATENDIDA'"));
        assertTrue(sql.contains("'NO_ASISTIO'"));
        assertFalse(sql.contains("afeccion"));
        assertFalse(sql.contains("tratamiento"));
        assertFalse(sql.contains("observaciones"));
        assertEquals(HOY, countParams.getValue()[0]);
        assertEquals("67890127", countParams.getValue()[1]);
        assertEquals(9001L, countParams.getValue()[2]);
        assertEquals(HOY, countParams.getValue()[3]);
        assertEquals(17L, countParams.getValue()[4]);
        assertEquals("CANCELADA_INSTITUCION", countParams.getValue()[5]);
    }

    @Test
    void llegadaFalsaOrdenaHoraDeLlegadaConNulosAlFinal() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(
                anyString(), eq(Long.class), any(Object[].class)
        )).thenReturn(0L);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<AgendaOperativaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AgendaConsultaRepository repository = new AgendaConsultaRepository(jdbc);

        repository.listar(
                new FiltroAgendaDTO(null, null, null, null, null, false,
                        "horaLlegada", "desc", 0, 20),
                HOY
        );

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("llegada_en IS NULL"));
        assertTrue(sql.getValue().contains(
                "ORDER BY llegada_en DESC NULLS LAST, fecha DESC, hora_inicio DESC"
        ));
        assertTrue(sql.getValue().contains("id_consulta ASC"));
    }

    @Test
    void filtrosVaciosNoGeneranUnWhereInvalido() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(
                anyString(), eq(Long.class), any(Object[].class)
        )).thenReturn(0L);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<AgendaOperativaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AgendaConsultaRepository repository = new AgendaConsultaRepository(jdbc);

        repository.listar(
                new FiltroAgendaDTO(null, null, null, null, null, null,
                        "fechaHora", "asc", 0, 20),
                HOY
        );

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(sql.capture(), eq(Long.class), any(Object[].class));
        assertFalse(sql.getValue().contains("WHERE"));
    }
}
