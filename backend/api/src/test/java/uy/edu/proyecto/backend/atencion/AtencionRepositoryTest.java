package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

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

class AtencionRepositoryTest {

    @Test
    void buscaConsultaSoloSiPerteneceAlMedico() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                any(RowMapper.class),
                any(Object[].class)
        )).thenReturn(List.of(91L));

        new AtencionRepository(jdbc).buscarSocioId(17L, 9001L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(
                sql.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        assertTrue(sql.getValue().contains("ts.id_medico = ?"));
        assertTrue(sql.getValue().contains("consulta.id_consulta = ?"));
    }

    @Test
    void bloqueaSocioConsultaYVerificaLlegada() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(
                anyString(),
                any(RowMapper.class),
                any(Object[].class)
        )).thenReturn(List.of(91L));
        when(jdbc.queryForObject(
                anyString(),
                eq(Boolean.class),
                any(Object[].class)
        )).thenReturn(true);
        AtencionRepository repository = new AtencionRepository(jdbc);

        repository.bloquearSocio(91L);
        repository.bloquearConsulta(17L, 9001L);
        repository.existeAvisoLlegada(91L, LocalDate.of(2026, 10, 20));

        ArgumentCaptor<String> consultas = ArgumentCaptor.forClass(String.class);
        verify(jdbc, org.mockito.Mockito.times(2)).query(
                consultas.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        assertTrue(consultas.getAllValues().getFirst().contains("FOR UPDATE"));
        assertTrue(consultas.getAllValues().get(1).contains("FOR UPDATE OF consulta"));
        verify(jdbc).queryForObject(
                org.mockito.ArgumentMatchers.contains("aviso_llegada"),
                eq(Boolean.class),
                any(Object[].class)
        );
    }

    @Test
    void validaPaseVigenteYConsultaPendienteExcluyendoConsultaActual() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(
                anyString(),
                eq(Boolean.class),
                any(Object[].class)
        )).thenReturn(false);

        new AtencionRepository(jdbc).tienePaseVigenteOConsultaAgendada(
                91L,
                4L,
                9001L,
                LocalDate.of(2026, 10, 20)
        );

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros =
                ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Boolean.class),
                parametros.capture()
        );
        assertTrue(sql.getValue().contains("pase.vence_el >= ?"));
        assertTrue(sql.getValue().contains("pendiente.id_consulta <> ?"));
        assertTrue(sql.getValue().contains("pendiente.estado = 'AGENDADA'"));
        assertEquals(91L, parametros.getValue()[0]);
        assertEquals(9001L, parametros.getValue()[4]);
    }

    @Test
    void resultadoSoloActualizaConsultasAunAgendadas() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.update(
                anyString(),
                any(Object[].class)
        )).thenReturn(1);

        boolean updated = new AtencionRepository(jdbc).registrarAtendida(
                9001L,
                17L,
                OffsetDateTime.parse("2026-10-20T09:41:00-03:00")
        );

        assertTrue(updated);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).update(sql.capture(), any(Object[].class));
        assertTrue(sql.getValue().contains("estado = 'AGENDADA'"));
        assertTrue(sql.getValue().contains("resultado_registrado_por"));
        assertTrue(sql.getValue().contains("fecha_resultado"));
    }
}
