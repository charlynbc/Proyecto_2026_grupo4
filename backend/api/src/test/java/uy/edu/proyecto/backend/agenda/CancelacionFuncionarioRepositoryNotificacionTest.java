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

class CancelacionFuncionarioRepositoryNotificacionTest {

    @Test
    void elAvisoDeCancelacionGuardaElTextoTalCualComoCancelacion() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7003L);

        Long id = new CancelacionFuncionarioRepository(jdbc)
                .crearNotificacion(12L, "Texto del aviso de cancelación.");

        assertEquals(7003L, id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Long.class),
                eq(12L),
                eq("Texto del aviso de cancelación.")
        );
        assertTrue(sql.getValue().contains("'CANCELACION'"));
    }
}
