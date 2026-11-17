package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CancelacionFuncionarioRepositoryNotificacionTest {

    @Test
    void elAvisoDeCancelacionDelFuncionarioLlevaLaFechaDiaMesAnio() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7003L);

        Long id = new CancelacionFuncionarioRepository(jdbc)
                .crearNotificacion(12L, LocalDate.of(2026, 11, 1));

        assertEquals(7003L, id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Long.class),
                eq(12L),
                eq("Tu consulta del 01/11/2026 fue cancelada a tu solicitud.")
        );
        assertTrue(sql.getValue().contains("'CANCELACION'"));
    }

    @Test
    void elAvisoPorOtroMotivoLlevaLaFechaDiaMesAnioYElMotivo() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7004L);

        Long id = new CancelacionFuncionarioRepository(jdbc)
                .crearNotificacionPorInstitucion(12L, LocalDate.of(2026, 11, 1), "Se rompio el equipo");

        assertEquals(7004L, id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Long.class),
                eq(12L),
                eq("Tu consulta del 01/11/2026 fue cancelada por la institución. "
                        + "Motivo: Se rompio el equipo")
        );
        assertTrue(sql.getValue().contains("'CANCELACION'"));
    }

    @Test
    void elAvisoPorOtroMotivoNoMencionaAlFuncionario() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7005L);

        new CancelacionFuncionarioRepository(jdbc)
                .crearNotificacionPorInstitucion(12L, LocalDate.of(2026, 12, 25), "Feriado");

        verify(jdbc).queryForObject(
                anyString(),
                eq(Long.class),
                eq(12L),
                eq("Tu consulta del 25/12/2026 fue cancelada por la institución. Motivo: Feriado")
        );
    }
}
