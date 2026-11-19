package uy.edu.proyecto.backend.notificacion;

import java.time.OffsetDateTime;
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

/** El SQL de la lista de avisos: solo los del socio, sin recordatorios futuros, del mas nuevo al mas viejo. */
class NotificacionRepositoryTest {
    private static final OffsetDateTime AHORA = OffsetDateTime.parse("2026-11-17T12:00:00-03:00");

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final NotificacionRepository repository = new NotificacionRepository(jdbc);

    private static String limpio(String sql) {
        return sql.replaceAll("\\s+", " ").trim();
    }

    @Test
    void listaSoloLosAvisosDeLasConsultasDelSocioConElJoin() {
        repository.listar(7L, AHORA, 2, 20);

        var sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        String consulta = limpio(sql.getValue());
        assertTrue(consulta.contains("FROM public.notificacion n JOIN public.consulta c ON c.id_consulta = n.id_consulta"),
                consulta);
        assertTrue(consulta.contains("WHERE c.id_socio = ?"), consulta);
    }

    @Test
    void ordenaPorCreadaEnYPorIdDescendentes() {
        repository.listar(7L, AHORA, 0, 20);

        var sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(limpio(sql.getValue()).contains("ORDER BY n.creada_en DESC, n.id_notificacion DESC"),
                limpio(sql.getValue()));
    }

    @Test
    void noListaLosRecordatoriosConLaHoraTodaviaPorVenir() {
        repository.listar(7L, AHORA, 0, 20);

        var sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(limpio(sql.getValue()).contains("AND (n.programada_para IS NULL OR n.programada_para <= ?)"),
                limpio(sql.getValue()));
    }

    @Test
    void pasaElSocioElAhoraElTamanoYElDesplazamientoEnEseOrden() {
        repository.listar(7L, AHORA, 2, 20);

        // 2 paginas de 20 son 40 filas salteadas.
        verify(jdbc).query(anyString(), any(RowMapper.class), eq(7L), eq(AHORA), eq(20), eq(40L));
    }

    @Test
    void elDesplazamientoNoDesbordaConPaginasGrandes() {
        repository.listar(7L, AHORA, Integer.MAX_VALUE, 100);

        verify(jdbc).query(anyString(), any(RowMapper.class), eq(7L), eq(AHORA), eq(100),
                eq(2147483647L * 100L));
    }

    @Test
    void elTotalCuentaConElMismoFiltroDeSocioYDeRecordatorios() {
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class))).thenReturn(3L);

        long total = repository.total(7L, AHORA);

        assertEquals(3L, total);
        var sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForObject(sql.capture(), eq(Long.class), eq(7L), eq(AHORA));
        String consulta = limpio(sql.getValue());
        assertTrue(consulta.contains("SELECT count(*) FROM public.notificacion n JOIN public.consulta c ON c.id_consulta = n.id_consulta"),
                consulta);
        assertTrue(consulta.contains("WHERE c.id_socio = ?"), consulta);
        assertTrue(consulta.contains("AND (n.programada_para IS NULL OR n.programada_para <= ?)"), consulta);
    }
}
