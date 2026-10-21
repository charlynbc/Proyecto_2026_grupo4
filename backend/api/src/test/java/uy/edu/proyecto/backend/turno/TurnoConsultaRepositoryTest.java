package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TurnoConsultaRepositoryTest {

    @Test
    void aplicaFiltrosOrdenPaginacionEnSqlYParametros() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.queryForObject(
                anyString(),
                eq(Long.class),
                any(Object[].class)
        )).thenReturn(31L);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<TurnoFechaResponse>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        TurnoConsultaRepository repository =
                new TurnoConsultaRepository(jdbcTemplate);
        TurnosPageResponse page = repository.listar(new FiltroTurnosDTO(
                17L,
                3L,
                2,
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 12, 20),
                "ACTIVO",
                "medico",
                "desc",
                2,
                15
        ));

        ArgumentCaptor<String> queryCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> paramsCaptor =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).queryForObject(
                queryCaptor.capture(),
                eq(Long.class),
                paramsCaptor.capture()
        );
        String countSql = queryCaptor.getValue();
        assertTrue(countSql.contains("ts.id_medico = ?"));
        assertTrue(countSql.contains("ts.id_especialidad = ?"));
        assertTrue(countSql.contains("EXTRACT(ISODOW FROM t.fecha)"));
        assertTrue(countSql.contains("t.fecha >= ?"));
        assertTrue(countSql.contains("t.fecha <= ?"));
        assertTrue(countSql.contains("t.estado = ?"));
        assertEquals(6, paramsCaptor.getValue().length);

        ArgumentCaptor<String> pageSqlCaptor =
                ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> pageParamsCaptor =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(
                pageSqlCaptor.capture(),
                any(RowMapper.class),
                pageParamsCaptor.capture()
        );
        String pageSql = pageSqlCaptor.getValue();
        assertTrue(pageSql.contains("ORDER BY persona.apellido DESC"));
        assertTrue(pageSql.contains("LIMIT ? OFFSET ?"));
        Object[] pageParams = pageParamsCaptor.getValue();
        assertEquals(8, pageParams.length);
        assertEquals(15, pageParams[6]);
        assertEquals(30L, pageParams[7]);
        assertEquals(31L, page.total());
        assertEquals(2, page.page());
        assertEquals(15, page.size());
    }
}
