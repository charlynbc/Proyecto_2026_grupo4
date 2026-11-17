package uy.edu.proyecto.backend.agenda;

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

class ConsultaRepositoryNotificacionTest {

    @Test
    void elAvisoDeAgendaGuardaSuCuerpoYDevuelveElIdParaCrearSusEnvios() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7001L);

        Long id = new ConsultaRepository(jdbc).crearNotificacionAgenda(
                9001L, "Tu consulta de Cardiología quedó agendada.");

        assertEquals(7001L, id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Long.class),
                eq(9001L),
                eq("Tu consulta de Cardiología quedó agendada.")
        );
        assertTrue(sql.getValue().contains("'AGENDA'"));
        assertTrue(sql.getValue().contains("RETURNING id_notificacion"));
    }
}
