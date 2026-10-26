package uy.edu.proyecto.backend.usuario;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UsuarioRepositoryTest {

    @Test
    void queryEntregaUnaFilaPorCuentaYAplicaFiltrosPaginacionYOrden() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(0L);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        UsuarioCuentaPageResponse response = new UsuarioPadronRepository(jdbc).listar(
                "SOCIO", "INACTIVA", "45678911", 2, 10
        );

        assertTrue(response.items().isEmpty());
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());

        assertTrue(sql.getValue().contains("FROM public.cuenta c"));
        assertTrue(sql.getValue().contains("JOIN public.persona p ON p.ci = c.ci"));
        assertTrue(sql.getValue().contains("c.rol = ?"));
        assertTrue(sql.getValue().contains("c.habilitada = ?"));
        assertTrue(sql.getValue().contains("LOWER(p.ci) LIKE LOWER(?)"));
        assertTrue(sql.getValue().contains("LOWER(p.apellido) LIKE LOWER(?)"));
        assertTrue(sql.getValue().contains("ORDER BY p.apellido ASC, c.fecha_alta DESC"));
        assertTrue(!sql.getValue().contains("password"));
        assertTrue(!sql.getValue().contains("token"));
        assertTrue(java.util.Arrays.equals(
                new Object[] {"SOCIO", false, "%45678911%", "%45678911%", 10, 20L},
                parametros.getValue()
        ));
    }
}
