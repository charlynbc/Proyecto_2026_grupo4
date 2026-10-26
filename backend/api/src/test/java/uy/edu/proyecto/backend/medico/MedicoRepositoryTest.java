package uy.edu.proyecto.backend.medico;

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

class MedicoRepositoryTest {

    @Test
    void queryLimitaMedicosActivosEIncluyeEspecialidadSinDatosSensibles() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        assertTrue(new MedicoRepository(jdbc).listar(3L).isEmpty());

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        assertTrue(sql.getValue().contains("c.rol = 'MEDICO'"));
        assertTrue(sql.getValue().contains("c.habilitada = TRUE"));
        assertTrue(sql.getValue().contains("medico_especialidad"));
        assertTrue(sql.getValue().contains("filtro.id_especialidad = ?"));
        assertTrue(!sql.getValue().contains("password"));
        assertTrue(!sql.getValue().contains("token"));
        assertTrue(!sql.getValue().contains("correo"));
        assertTrue(java.util.Arrays.equals(new Object[] {3L}, parametros.getValue()));
    }
}
