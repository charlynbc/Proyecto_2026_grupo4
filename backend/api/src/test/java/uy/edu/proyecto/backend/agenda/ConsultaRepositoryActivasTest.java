package uy.edu.proyecto.backend.agenda;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class ConsultaRepositoryActivasTest {

    private static void verificarDefinicionDeActiva(String sql) {
        assertTrue(sql.contains("consulta.estado = 'AGENDADA'"));
        assertTrue(sql.contains(
                "turno.fecha >= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Montevideo')::date"));
        assertTrue(sql.contains("consulta.fecha_resultado IS NOT NULL"));
        assertFalse(sql.contains("UPDATE "));
        assertFalse(sql.contains("INSERT INTO"));
    }

    @Test
    void elLimiteTotalNoCuentaLasAgendadasDeDiasTerminadosSinResultado() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);

        new ConsultaRepository(jdbc).contarConsultasAgendadas(7L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(sql.capture(), eq(Long.class), eq(7L));
        verificarDefinicionDeActiva(sql.getValue());
    }

    @Test
    void elLimitePorEspecialidadNoCuentaLasAgendadasDeDiasTerminadosSinResultado() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);

        new ConsultaRepository(jdbc).tieneConsultaAgendadaEnEspecialidad(7L, 3L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(), eq(Boolean.class), eq(7L), eq(3L));
        verificarDefinicionDeActiva(sql.getValue());
        assertTrue(sql.getValue().contains("semanal.id_especialidad = ?"));
    }
}
