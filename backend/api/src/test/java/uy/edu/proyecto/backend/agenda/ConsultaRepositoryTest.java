package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ConsultaRepositoryTest {

    @Test
    void bloqueaSocioNumeroYTurnoParaSerializarReservasConcurrentes() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.NumeroParaAgendar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);
        repository.bloquearSocioHabilitado(91L);
        repository.bloquearNumero(4501L);

        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate, org.mockito.Mockito.times(2)).query(
                captor.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );

        String queries = String.join("\n", captor.getAllValues());
        assertTrue(queries.contains("FOR UPDATE"));
        assertTrue(queries.contains("FOR UPDATE OF t, n"));
        assertTrue(queries.contains("id_cuenta = ?"));
        assertTrue(queries.contains("n.id_numero = ?"));
    }

    @Test
    void validaPasePropioVigenteYNoUtilizadoBajoBloqueo() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.PaseParaAgendar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);

        repository.bloquearPaseDisponible(
                77L,
                91L,
                3L,
                LocalDate.of(2026, 11, 3)
        );

        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                captor.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        String sql = captor.getValue();
        assertTrue(sql.contains("consulta.id_socio = ?"));
        assertTrue(sql.contains("pase.id_especialidad_destino = ?"));
        assertTrue(sql.contains("pase.vence_el >= ?"));
        assertTrue(sql.contains("NOT EXISTS"));
        assertTrue(sql.contains("FOR UPDATE OF pase"));
    }

    @Test
    void historialFiltraEstadosCalculadosYPaginaEnPostgresConOrdenSeguro() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.queryForObject(
                anyString(),
                eq(Long.class),
                any(Object[].class)
        )).thenReturn(3L);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<ConsultaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);
        ConsultaHistorialFiltro filtro = new ConsultaHistorialFiltro(
                "NO_ATENDIDA",
                LocalDate.of(2026, 10, 1),
                LocalDate.of(2026, 10, 31),
                3L,
                17L,
                "especialidad",
                "asc",
                1,
                10
        );

        ConsultaHistorialPageResponse response = repository.listarHistorial(
                91L,
                filtro,
                LocalDate.of(2026, 10, 22)
        );

        assertEquals(3, response.total());
        ArgumentCaptor<String> countSql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).queryForObject(
                countSql.capture(),
                eq(Long.class),
                any(Object[].class)
        );
        assertTrue(countSql.getValue().contains("consulta.fecha_resultado IS NULL"));
        assertTrue(countSql.getValue().contains("turno.fecha < ?"));
        assertTrue(countSql.getValue().contains("public.aviso_llegada"));
        assertTrue(countSql.getValue().contains("AND estado = ?"));
        assertTrue(countSql.getValue().contains("AND id_especialidad = ?"));
        assertTrue(countSql.getValue().contains("AND id_medico = ?"));
        assertTrue(countSql.getValue().contains("WHERE consulta.id_socio = ?"));

        ArgumentCaptor<String> pageSql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                pageSql.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        assertTrue(pageSql.getValue().contains("ORDER BY especialidad_nombre ASC"));
        assertTrue(pageSql.getValue().contains("id_consulta ASC LIMIT ? OFFSET ?"));
        assertTrue(pageSql.getValue().contains("public.consultorio"));
        verify(jdbcTemplate).query(anyString(), any(RowMapper.class), any(Object[].class));
    }
}
