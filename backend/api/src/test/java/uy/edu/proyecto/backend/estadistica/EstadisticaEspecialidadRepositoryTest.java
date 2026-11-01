package uy.edu.proyecto.backend.estadistica;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EstadisticaEspecialidadRepositoryTest {

    @Test
    void sqlCuentaPorFechaDeAgendamientoSinFiltrarPorEstadoNiPorFechaMedica() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());
        Instant desde = Instant.parse("2026-03-01T03:00:00Z");
        Instant hasta = Instant.parse("2026-04-01T03:00:00Z");

        assertTrue(new EstadisticaEspecialidadRepository(jdbc)
                .contarAgendadas(desde, hasta).isEmpty());

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        String consulta = sql.getValue();
        assertTrue(consulta.contains("c.agendada_en >= ?"));
        assertTrue(consulta.contains("c.agendada_en < ?"));
        // Las canceladas cuentan: no hay filtro por estado.
        assertFalse(consulta.contains("estado"));
        // La fecha medica no participa del periodo.
        assertFalse(consulta.contains("t.fecha"));
        // Las especialidades sin consultas aparecen con cero.
        assertTrue(consulta.contains("LEFT JOIN ("));
        assertTrue(consulta.contains("COUNT(x.id_consulta)"));
        assertTrue(consulta.contains("GROUP BY e.id_especialidad"));
        // Sin datos de pacientes ni credenciales.
        assertFalse(consulta.contains("id_socio"));
        assertFalse(consulta.contains("persona"));
        assertFalse(consulta.contains("correo"));
        assertFalse(consulta.contains("contrasena"));
        // Solo parametros posicionales, sin concatenar valores.
        assertEquals(2, consulta.chars().filter(c -> c == '?').count());
        assertArrayEquals(
                new Object[] {Timestamp.from(desde), Timestamp.from(hasta)},
                parametros.getValue()
        );
    }
}
