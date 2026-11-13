package uy.edu.proyecto.backend.busqueda;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import uy.edu.proyecto.backend.atencion.AtencionMedicoRepository;
import uy.edu.proyecto.backend.atencion.HistoriaClinicaRepository;
import uy.edu.proyecto.backend.consultorio.ConsultorioRepository;
import uy.edu.proyecto.backend.especialidad.EspecialidadRepository;
import uy.edu.proyecto.backend.usuario.UsuarioPadronRepository;

/**
 * Cada uno de los cinco filtros de texto compara la columna normalizada (sin
 * tildes ni mayusculas) contra el texto normalizado. Los fragmentos esperados
 * estan escritos a mano.
 */
class FiltrosSinTildesRepositoryTest {

    private static final String MAPA =
            "'áéíóúüÁÉÍÓÚÜÑ', 'aeiouuAEIOUUñ'))";

    private static String cond(String columna) {
        return "LOWER(translate(" + columna + ", " + MAPA + " LIKE ? ESCAPE '!'";
    }

    private static boolean contiene(Object[] parametros, String esperado) {
        return Arrays.asList(parametros).contains(esperado);
    }

    @Test
    void usuariosBuscaPorCiYApellidoSinTildes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(anyString(), eq(Long.class), any(Object[].class)))
                .thenReturn(0L);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new UsuarioPadronRepository(jdbc).listar(null, null, "Pérez", 0, 10);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());
        assertTrue(sql.getValue().contains(cond("p.ci")), sql.getValue());
        assertTrue(sql.getValue().contains(cond("p.apellido")), sql.getValue());
        assertTrue(contiene(parametros.getValue(), "%perez%"));
    }

    @Test
    void atencionesDelMedicoBuscaPorCiYApellidoSinTildes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new AtencionMedicoRepository(jdbc).listar(
                7L, LocalDate.parse("2026-01-01"), LocalDate.parse("2026-12-31"),
                "Pérez", null, "fecha", "desc");

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());
        assertTrue(sql.getValue().contains(cond("socio.ci")), sql.getValue());
        assertTrue(sql.getValue().contains(cond("paciente.apellido")), sql.getValue());
        assertTrue(contiene(parametros.getValue(), "%perez%"));
    }

    @Test
    void historiaClinicaBuscaEnElTratamientoSinTildes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new HistoriaClinicaRepository(jdbc).listar(
                91L, null, null, null, null, "Atención", "fecha_atencion", "desc");

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());
        assertTrue(sql.getValue().contains(cond("COALESCE(a.tratamiento, '')")), sql.getValue());
        assertTrue(contiene(parametros.getValue(), "%atencion%"));
    }

    @Test
    void consultoriosBuscaPorNombreYUbicacionSinTildes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new ConsultorioRepository(jdbc).listarFiltrados("Pérez", "Sótano", "nombre");

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());
        assertTrue(sql.getValue().contains(cond("nombre")), sql.getValue());
        assertTrue(sql.getValue().contains(cond("ubicacion")), sql.getValue());
        assertTrue(Arrays.equals(new Object[] {"%perez%", "%sotano%"}, parametros.getValue()));
    }

    @Test
    void especialidadesBuscaPorNombreSinTildes() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(List.of());

        new EspecialidadRepository(jdbc).listarFiltradas("Cardiología", null, "nombre");

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> parametros = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sql.capture(), any(RowMapper.class), parametros.capture());
        assertTrue(sql.getValue().contains(cond("nombre")), sql.getValue());
        assertTrue(Arrays.equals(new Object[] {"%cardiologia%"}, parametros.getValue()));
    }
}
