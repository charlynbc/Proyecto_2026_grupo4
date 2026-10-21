package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
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
}
