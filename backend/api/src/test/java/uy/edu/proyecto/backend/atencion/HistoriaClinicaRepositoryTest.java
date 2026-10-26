package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class HistoriaClinicaRepositoryTest {

    @Test
    void listaCombinaFiltrosYRestringeAlSocioConOrdenPermitido() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        HistoriaClinicaRepository repository = new HistoriaClinicaRepository(jdbc);
        assertTrue(repository.listar(
                91L,
                LocalDate.parse("2026-01-01"),
                LocalDate.parse("2026-12-31"),
                3L,
                17L,
                "control",
                "especialidad",
                "asc"
        ).isEmpty());

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        assertTrue(sql.getValue().contains("WHERE consulta.id_socio = ?"));
        assertTrue(sql.getValue().contains("a.registrada_en::date >= ?"));
        assertTrue(sql.getValue().contains("a.registrada_en::date <= ?"));
        assertTrue(sql.getValue().contains("especialidad.id_especialidad = ?"));
        assertTrue(sql.getValue().contains("medico.id_cuenta = ?"));
        assertTrue(sql.getValue().contains("LOWER(COALESCE(a.tratamiento, '')) LIKE LOWER(?)"));
        assertTrue(sql.getValue().contains("ORDER BY especialidad.nombre asc, a.id_atencion asc"));
        assertTrue(java.util.Arrays.equals(
                new Object[] {
                        91L,
                        LocalDate.parse("2026-01-01"),
                        LocalDate.parse("2026-12-31"),
                        3L,
                        17L,
                        "%control%"
                },
                parametros.getValue()
        ));
    }

    @Test
    void detalleVuelveAComprobarPropiedadYNoConsultaPasesDeAtencionAjena() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        assertTrue(new HistoriaClinicaRepository(jdbc).obtenerDetalle(91L, 5530L) == null);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        assertTrue(sql.getValue().contains("WHERE consulta.id_socio = ?"));
        assertTrue(sql.getValue().contains("AND a.id_atencion = ?"));
        assertTrue(java.util.Arrays.equals(new Object[] {91L, 5530L}, parametros.getValue()));
    }
}
