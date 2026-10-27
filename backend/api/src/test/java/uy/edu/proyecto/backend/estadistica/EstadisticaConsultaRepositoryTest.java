package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowCallbackHandler;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class EstadisticaConsultaRepositoryTest {

    @Test
    void sqlFiltraPorFechaDeLaConsultaDerivaEstadosSinDuplicarYNoExponePacientes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        LocalDate desde = LocalDate.parse("2026-03-01");
        LocalDate hasta = LocalDate.parse("2026-03-31");
        LocalDate hoy = LocalDate.parse("2026-10-26");

        assertTrue(new EstadisticaConsultaRepository(jdbc).contarPorEstado(desde, hasta, hoy).isEmpty());

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowCallbackHandler.class), parametros.capture());

        String consulta = sql.getValue();
        // Periodo sobre la fecha medica, nunca sobre la fecha de agendamiento.
        assertTrue(consulta.contains("t.fecha >= ?"));
        assertTrue(consulta.contains("t.fecha <= ?"));
        assertFalse(consulta.contains("agendada_en"));
        // Estados derivados: dia terminado, sin resultado, con o sin aviso de llegada.
        assertTrue(consulta.contains("c.estado = 'AGENDADA'"));
        assertTrue(consulta.contains("c.fecha_resultado IS NULL"));
        assertTrue(consulta.contains("t.fecha < ?"));
        assertTrue(consulta.contains("'NO_ATENDIDA'"));
        assertTrue(consulta.contains("'NO_ASISTIO'"));
        // Una fila por consulta: aviso por EXISTS y agrupacion por estado efectivo.
        assertTrue(consulta.contains("EXISTS"));
        assertFalse(consulta.contains("LEFT JOIN"));
        assertTrue(consulta.contains("GROUP BY 1"));
        // Sin datos de pacientes.
        assertFalse(consulta.contains("persona"));
        assertFalse(consulta.contains("correo"));
        assertFalse(consulta.contains("afeccion"));
        assertEquals(3, consulta.chars().filter(c -> c == '?').count());
        assertArrayEquals(
                new Object[] {Date.valueOf(hoy), Date.valueOf(desde), Date.valueOf(hasta)},
                parametros.getValue()
        );
    }
}
