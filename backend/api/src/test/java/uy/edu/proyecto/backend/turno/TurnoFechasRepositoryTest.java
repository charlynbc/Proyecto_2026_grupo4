package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TurnoFechasRepositoryTest {

    @Test
    void bloqueaYSeleccionaSolamenteConsultasAgendadas() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<TurnoFechasRepository.ConsultaParaCancelar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.bloquearConsultasAgendadas(List.of(301L, 308L));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("consulta.estado = 'AGENDADA'"));
        assertTrue(sql.getValue().contains("FOR UPDATE OF consulta"));
    }

    @Test
    void cancelarConsultaConservaElPaseYExigeEstadoAgendada() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.cancelarConsulta(900L, 41L, null, null, 7001L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).update(sql.capture(), any(Object[].class));
        assertTrue(sql.getValue().contains("estado = 'CANCELADA_INSTITUCION'"));
        assertTrue(sql.getValue().contains("estado = 'AGENDADA'"));
        assertFalse(sql.getValue().contains("id_pase"));
    }

    @Test
    void rehabilitacionBuscaConflictosPorMedicoOConsultorio() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<TurnoFechasRepository.NumeroExistente>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.buscarNumerosActivosEnFechas(
                List.of(301L),
                List.of(17L),
                List.of(5L),
                LocalDate.of(2026, 10, 21),
                LocalDate.of(2026, 10, 21)
        );

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("t.estado = 'ACTIVO'"));
        assertTrue(sql.getValue().contains("ts.id_medico IN"));
        assertTrue(sql.getValue().contains("OR t.id_consultorio IN"));
        assertTrue(sql.getValue().contains("t.id_turno NOT IN"));
    }

    @Test
    void dispatcherBloqueaPendientesDeSuspensionSinDuplicarProcesamiento() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any()
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.bloquearSiguienteEnvioPendiente();

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class));
        assertTrue(sql.getValue().contains("envio.estado = 'PENDIENTE'"));
        assertTrue(sql.getValue().contains("notificacion.tipo = 'SUSPENSION'"));
        assertTrue(sql.getValue().contains("FOR UPDATE OF envio SKIP LOCKED"));
    }
}
