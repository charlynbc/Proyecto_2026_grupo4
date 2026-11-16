package uy.edu.proyecto.backend.atencion;

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

class AtencionRepositoryNotificacionTest {

    @Test
    void elAvisoDeHistoriaGuardaSuIdYNoLlevaDatosClinicos() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(7002L);

        Long id = new AtencionRepository(jdbc).crearNotificacionHistoriaActualizada(9001L);

        assertEquals(7002L, id);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(
                sql.capture(),
                eq(Long.class),
                eq(9001L),
                eq("Tu historia clínica fue actualizada.")
        );
        assertTrue(sql.getValue().contains("'HISTORIA_ACTUALIZADA'"));
        assertTrue(sql.getValue().contains("RETURNING id_notificacion"));
    }
}
