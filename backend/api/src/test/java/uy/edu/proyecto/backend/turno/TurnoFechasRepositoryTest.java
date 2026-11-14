package uy.edu.proyecto.backend.turno;

import java.sql.ResultSet;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
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
    void dispatcherBloqueaPendientesDeCualquierTipoSinDuplicarProcesamiento() {
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
        assertFalse(sql.getValue().contains("SUSPENSION"));
        assertFalse(sql.getValue().contains("notificacion.tipo"));
        assertTrue(sql.getValue().contains("FOR UPDATE OF envio SKIP LOCKED"));
    }

    @Test
    void buscarEnvioNoFiltraPorTipoYTraeElTipoDelAviso() throws Exception {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<TurnoFechasRepository.EnvioNotificacion>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.buscarEnvio(601L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<RowMapper<TurnoFechasRepository.EnvioNotificacion>> mapper =
                ArgumentCaptor.forClass(RowMapper.class);
        verify(jdbc).query(sql.capture(), mapper.capture(), any(Object[].class));
        assertFalse(sql.getValue().contains("SUSPENSION"));
        assertTrue(sql.getValue().contains("notificacion.tipo"));
        assertTrue(sql.getValue().contains("envio.estado = 'PENDIENTE'"));
        assertTrue(sql.getValue().contains("FOR UPDATE OF envio"));

        ResultSet rs = mock(ResultSet.class);
        when(rs.getLong("id_envio")).thenReturn(601L);
        when(rs.getLong("id_notificacion")).thenReturn(701L);
        when(rs.getString("tipo")).thenReturn("AGENDA");
        when(rs.getString("canal")).thenReturn("CORREO");
        when(rs.getString("correo_destino")).thenReturn("socio@example.com");
        when(rs.getString("contenido")).thenReturn("Contenido de prueba");
        when(rs.getObject("fecha", LocalDate.class)).thenReturn(LocalDate.of(2026, 10, 21));
        when(rs.getObject("hora_inicio", LocalTime.class)).thenReturn(LocalTime.of(9, 0));
        when(rs.getObject("hora_fin", LocalTime.class)).thenReturn(LocalTime.of(9, 20));
        when(rs.getString("especialidad_nombre")).thenReturn("Cardiología");
        when(rs.getString("socio_nombre")).thenReturn("Socio");

        TurnoFechasRepository.EnvioNotificacion envio = mapper.getValue().mapRow(rs, 0);

        assertEquals("AGENDA", envio.tipo());
        assertEquals("CORREO", envio.canal());
        assertEquals("Contenido de prueba", envio.contenido());
    }

    @Test
    void registrarEnviosCreaUnaFilaDeCorreoYUnaPorDispositivoHabilitado() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any(),
                any(Object[].class)
        )).thenReturn(List.of(11L, 12L));
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(801L, 802L, 803L);
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        List<Long> envios = repository.registrarEnviosNotificacion(
                701L, 91L, "socio@example.com");

        assertEquals(List.of(801L, 802L, 803L), envios);
        ArgumentCaptor<String> inserts = ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(3))
                .queryForObject(inserts.capture(), eq(Long.class), any(Object[].class));
        assertTrue(inserts.getAllValues().get(0).contains("'CORREO'"));
        assertTrue(inserts.getAllValues().get(1).contains("'PUSH'"));
        assertTrue(inserts.getAllValues().get(2).contains("'PUSH'"));
    }

    @Test
    void registrarEnviosSoloBuscaDispositivosHabilitadosDelSocio() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        repository.registrarEnviosNotificacion(701L, 91L, null);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("WHERE id_socio = ? AND habilitado"));
    }

    @Test
    void sinCorreoYSinDispositivosNoSeCreaNingunaFila() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        TurnoFechasRepository repository = new TurnoFechasRepository(jdbc);

        assertEquals(List.of(), repository.registrarEnviosNotificacion(701L, 91L, null));
        assertEquals(List.of(), repository.registrarEnviosNotificacion(701L, 91L, "   "));

        verify(jdbc, never())
                .queryForObject(anyString(), eq(Long.class), any(Object[].class));
    }
}
