package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;
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

class EstadisticaTurnoRepositoryTest {

    @Test
    void sqlCuentaNumerosUnaSolaVezYSoloEnFechasActivas() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());
        LocalDate desde = LocalDate.parse("2026-03-01");
        LocalDate hasta = LocalDate.parse("2026-03-31");

        assertTrue(new EstadisticaTurnoRepository(jdbc).contarUtilizacion(desde, hasta).isEmpty());

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        String consulta = sql.getValue();
        // Solo fechas activas del periodo, por fecha del turno.
        assertTrue(consulta.contains("t.estado = 'ACTIVO'"));
        assertTrue(consulta.contains("t.fecha >= ?"));
        assertTrue(consulta.contains("t.fecha <= ?"));
        // Ocupado: existe una consulta NO cancelada; el EXISTS impide contar dos veces un numero.
        assertTrue(consulta.contains("EXISTS"));
        assertTrue(consulta.contains("c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')"));
        // Los estados derivados no se persisten: no deben usarse como filtro.
        assertFalse(consulta.contains("NO_ASISTIO"));
        assertFalse(consulta.contains("NO_ATENDIDA"));
        // Sin datos de pacientes.
        assertFalse(consulta.contains("id_socio"));
        assertFalse(consulta.contains("correo"));
        assertFalse(consulta.contains("contrasena"));
        assertEquals(4, consulta.chars().filter(c -> c == '?').count());
        assertArrayEquals(
                new Object[] {Date.valueOf(desde), Date.valueOf(hasta), Date.valueOf(hasta), Date.valueOf(desde)},
                parametros.getValue()
        );
    }
}
