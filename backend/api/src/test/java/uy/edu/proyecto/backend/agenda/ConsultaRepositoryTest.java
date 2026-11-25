package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ConsultaRepositoryTest {

    private static final OffsetDateTime MINIMO =
            OffsetDateTime.parse("2026-10-20T12:00:00-03:00");
    private static final OffsetDateTime MAXIMO =
            OffsetDateTime.parse("2026-10-30T08:00:00-03:00");

    @Test
    void bloqueaSocioNumeroYTurnoParaSerializarReservasConcurrentes() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<Long>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.NumeroParaAgendar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);
        repository.bloquearSocioHabilitado(91L);
        repository.bloquearNumero(4501L, MINIMO, MAXIMO);

        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate, org.mockito.Mockito.times(2)).query(
                captor.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );

        String queries = String.join("\n", captor.getAllValues());
        assertTrue(queries.contains("FOR UPDATE"));
        assertTrue(queries.contains("FOR UPDATE OF t, n"));
        assertTrue(queries.contains("id_cuenta = ?"));
        assertTrue(queries.contains("n.id_numero = ?"));
    }

    @Test
    void laVentanaDeAgendarLlegaComoInstantesYNoComoIntervalosFijos() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.NumeroParaAgendar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        new ConsultaRepository(jdbcTemplate).bloquearNumero(4501L, MINIMO, MAXIMO);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(
                sql.capture(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.NumeroParaAgendar>>any(),
                parametros.capture()
        );
        assertTrue(sql.getValue().replaceAll("\\s+", " ").contains(
                "AT TIME ZONE 'America/Montevideo' >= ? AND (t.fecha + n.hora_inicio) "
                + "AT TIME ZONE 'America/Montevideo' <= ? ) AS ventana_valida"));
        assertFalse(sql.getValue().contains("INTERVAL"));
        assertFalse(sql.getValue().contains("CURRENT_TIMESTAMP"));
        assertEquals(List.of(MINIMO, MAXIMO, 4501L),
                java.util.Arrays.asList(parametros.getValue()));
    }

    @Test
    void validaPasePropioVigenteYNoUtilizadoBajoBloqueo() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<ConsultaRepository.PaseParaAgendar>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);

        repository.bloquearPaseDisponible(
                77L,
                91L,
                3L,
                LocalDate.of(2026, 11, 3)
        );

        ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                captor.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        String sql = captor.getValue();
        assertTrue(sql.contains("consulta.id_socio = ?"));
        assertTrue(sql.contains("pase.id_especialidad_destino = ?"));
        assertTrue(sql.contains("pase.vence_el >= ?"));
        assertTrue(sql.contains("NOT EXISTS"));
        assertTrue(sql.contains("FOR UPDATE OF pase"));
    }

    @Test
    void historialFiltraEstadosCalculadosYPaginaEnPostgresConOrdenSeguro() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.queryForObject(
                anyString(),
                eq(Long.class),
                any(Object[].class)
        )).thenReturn(3L);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<ConsultaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        ConsultaRepository repository = new ConsultaRepository(jdbcTemplate);
        ConsultaHistorialFiltro filtro = new ConsultaHistorialFiltro(
                "NO_ATENDIDA",
                LocalDate.of(2026, 10, 1),
                LocalDate.of(2026, 10, 31),
                3L,
                17L,
                "especialidad",
                "asc",
                1,
                10
        );

        ConsultaRepository.PaginaHistorial response = repository.listarHistorial(
                91L,
                filtro,
                LocalDate.of(2026, 10, 22)
        );

        assertEquals(3, response.total());
        ArgumentCaptor<String> countSql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).queryForObject(
                countSql.capture(),
                eq(Long.class),
                any(Object[].class)
        );
        assertTrue(countSql.getValue().contains("consulta.fecha_resultado IS NULL"));
        assertTrue(countSql.getValue().contains("turno.fecha < ?"));
        assertTrue(countSql.getValue().contains("public.aviso_llegada"));
        assertTrue(countSql.getValue().contains("AND estado = ?"));
        assertTrue(countSql.getValue().contains("AND id_especialidad = ?"));
        assertTrue(countSql.getValue().contains("AND id_medico = ?"));
        assertTrue(countSql.getValue().contains("WHERE consulta.id_socio = ?"));

        ArgumentCaptor<String> pageSql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                pageSql.capture(),
                any(RowMapper.class),
                any(Object[].class)
        );
        assertTrue(pageSql.getValue().contains("ORDER BY especialidad_nombre ASC"));
        assertTrue(pageSql.getValue().contains("id_consulta ASC LIMIT ? OFFSET ?"));
        assertTrue(pageSql.getValue().contains("public.consultorio"));
        verify(jdbcTemplate).query(anyString(), any(RowMapper.class), any(Object[].class));
    }

    // La llegada se evalua por socio y dia. Ese criterio vive en un solo fragmento SQL, escrito aca a mano.
    private static final String LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE =
            "EXISTS (SELECT 1 FROM public.aviso_llegada aviso "
                    + "WHERE aviso.id_socio = consulta.id_socio AND aviso.fecha = turno.fecha)";

    private static String compacto(String sql) {
        return sql.replaceAll("\\s+", " ");
    }

    private static int ocurrencias(String texto, String buscado) {
        int cuenta = 0;
        for (int pos = texto.indexOf(buscado); pos >= 0; pos = texto.indexOf(buscado, pos + buscado.length())) {
            cuenta++;
        }
        return cuenta;
    }

    @Test
    void laCteDelListadoTraeLaColumnaDeLlegadaConElMismoFragmentoQueElEstadoCalculado() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.queryForObject(anyString(), eq(Long.class), any(Object[].class))).thenReturn(0L);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<ConsultaRepository.ConsultaConLlegada>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        new ConsultaRepository(jdbcTemplate).listarHistorial(
                91L,
                new ConsultaHistorialFiltro(null, null, null, null, null, "fecha", "desc", 0, 20),
                LocalDate.of(2026, 10, 22));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        String listado = compacto(sql.getValue());
        // Una vez en el CASE de NO_ATENDIDA y otra en la columna nueva.
        assertEquals(2, ocurrencias(listado, LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE));
        assertTrue(listado.contains("WHEN " + LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE + " THEN 'NO_ATENDIDA'"));
        assertTrue(listado.contains(LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE + " AS llegada_registrada"));
    }

    @Test
    void laCteDelDetalleTraeLaMismaColumnaDeLlegada() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<ConsultaRepository.ConsultaConLlegada>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        new ConsultaRepository(jdbcTemplate).obtenerHistorialDelSocio(91L, 44L, LocalDate.of(2026, 10, 22));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).query(sql.capture(), any(RowMapper.class), parametros.capture());
        String detalle = compacto(sql.getValue());
        assertEquals(2, ocurrencias(detalle, LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE));
        assertTrue(detalle.contains(LLEGADA_POR_SOCIO_Y_DIA_EN_LA_CTE + " AS llegada_registrada"));
        assertEquals(List.of(LocalDate.of(2026, 10, 22), 91L, 44L),
                java.util.Arrays.asList(parametros.getValue()));
    }

    @Test
    void existeAvisoLlegadaUsaElMismoCriterioDeSocioYDia() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.queryForObject(anyString(), eq(Boolean.class), any(Object[].class))).thenReturn(true);

        boolean existe = new ConsultaRepository(jdbcTemplate)
                .existeAvisoLlegada(91L, LocalDate.of(2026, 10, 22));

        assertTrue(existe);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbcTemplate).queryForObject(sql.capture(), eq(Boolean.class), parametros.capture());
        assertEquals("SELECT EXISTS (SELECT 1 FROM public.aviso_llegada aviso "
                        + "WHERE aviso.id_socio = ? AND aviso.fecha = ?)",
                compacto(sql.getValue()).trim());
        assertEquals(List.of(91L, LocalDate.of(2026, 10, 22)),
                java.util.Arrays.asList(parametros.getValue()));
    }
}
