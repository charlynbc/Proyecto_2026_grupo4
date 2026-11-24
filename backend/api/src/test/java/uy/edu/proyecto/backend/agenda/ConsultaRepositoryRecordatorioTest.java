package uy.edu.proyecto.backend.agenda;

import java.sql.ResultSet;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Sin base de datos: se revisa el SQL y los parametros que se mandan. El
 * comportamiento contra PostgreSQL lo cubre RecordatorioConsultaIT.
 */
class ConsultaRepositoryRecordatorioTest {

    private static final OffsetDateTime AHORA =
            OffsetDateTime.parse("2026-11-03T10:00:00-03:00");

    @Test
    @SuppressWarnings("unchecked")
    void elBarridoFiltraPorEstadoVentanaAnticipacionYRecordatorioExistente() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new ConsultaRepository(jdbc).buscarConsultasParaRecordatorio(AHORA, 24);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), eq(24), eq(AHORA), eq(AHORA));
        String texto = sql.getValue();
        assertTrue(texto.contains("consulta.estado = 'AGENDADA'"));
        assertTrue(texto.contains("horario.inicio > ?"));
        assertTrue(texto.contains("horario.programada_para <= ?"));
        assertTrue(texto.contains("consulta.agendada_en <= horario.programada_para"));
        assertTrue(texto.contains("NOT EXISTS"));
        assertTrue(texto.contains("notificacion.tipo = 'RECORDATORIO'"));
        assertTrue(texto.contains("AT TIME ZONE 'America/Montevideo'"));
        assertTrue(texto.contains("make_interval(hours => ?)"));
        assertTrue(!texto.contains("CURRENT_TIMESTAMP"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void laAntelacionConfiguradaSeMandaComoPrimerParametro() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new ConsultaRepository(jdbc).buscarConsultasParaRecordatorio(AHORA, 48);

        verify(jdbc).query(anyString(), any(RowMapper.class), org.mockito.ArgumentMatchers.eq(48),
                org.mockito.ArgumentMatchers.eq(AHORA), org.mockito.ArgumentMatchers.eq(AHORA));
    }

    @Test
    @SuppressWarnings("unchecked")
    void cadaFilaTraeLosDatosParaArmarElTexto() throws Exception {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());
        new ConsultaRepository(jdbc).buscarConsultasParaRecordatorio(AHORA, 24);
        ArgumentCaptor<RowMapper<ConsultaRepository.ConsultaParaRecordatorio>> mapper =
                ArgumentCaptor.forClass(RowMapper.class);
        verify(jdbc).query(anyString(), mapper.capture(), any(Object[].class));
        ResultSet rs = mock(ResultSet.class);
        when(rs.getLong("id_consulta")).thenReturn(9001L);
        when(rs.getLong("id_socio")).thenReturn(41L);
        when(rs.getString("especialidad_nombre")).thenReturn("Cardiología");
        when(rs.getString("medico_nombre")).thenReturn("Marta");
        when(rs.getString("medico_apellido")).thenReturn("Rodríguez");
        when(rs.getObject("fecha", LocalDate.class)).thenReturn(LocalDate.of(2026, 11, 4));
        when(rs.getObject("hora_inicio", LocalTime.class)).thenReturn(LocalTime.of(9, 0));
        when(rs.getString("consultorio_nombre")).thenReturn("Consultorio 3");
        when(rs.getString("consultorio_ubicacion")).thenReturn(null);
        OffsetDateTime programada = OffsetDateTime.parse("2026-11-03T09:00:00-03:00");
        when(rs.getObject("programada_para", OffsetDateTime.class)).thenReturn(programada);

        ConsultaRepository.ConsultaParaRecordatorio fila = mapper.getValue().mapRow(rs, 0);

        assertEquals(new ConsultaRepository.ConsultaParaRecordatorio(
                9001L, 41L, "Cardiología", "Marta", "Rodríguez",
                LocalDate.of(2026, 11, 4), LocalTime.of(9, 0),
                "Consultorio 3", null, programada), fila);
    }

    @Test
    @SuppressWarnings("unchecked")
    void elRecordatorioSeInsertaSinDuplicarYDevuelveElIdSiInserto() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of(7001L));
        OffsetDateTime programada = OffsetDateTime.parse("2026-11-03T09:00:00-03:00");

        Optional<Long> id = new ConsultaRepository(jdbc)
                .crearNotificacionRecordatorio(9001L, "Recordatorio de consulta: x", programada);

        assertEquals(Optional.of(7001L), id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class),
                org.mockito.ArgumentMatchers.eq(9001L),
                org.mockito.ArgumentMatchers.eq("Recordatorio de consulta: x"),
                org.mockito.ArgumentMatchers.eq(programada));
        assertTrue(sql.getValue().contains("'RECORDATORIO'"));
        assertTrue(sql.getValue().contains(
                "ON CONFLICT (id_consulta) WHERE tipo = 'RECORDATORIO' DO NOTHING"));
        assertTrue(sql.getValue().contains("RETURNING id_notificacion"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void siElRecordatorioYaExistiaNoDevuelveId() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        Optional<Long> id = new ConsultaRepository(jdbc).crearNotificacionRecordatorio(
                9001L, "texto", OffsetDateTime.parse("2026-11-03T09:00:00-03:00"));

        assertEquals(Optional.empty(), id);
    }
}
