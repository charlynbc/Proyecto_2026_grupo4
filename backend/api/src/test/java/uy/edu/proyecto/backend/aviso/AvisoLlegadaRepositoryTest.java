package uy.edu.proyecto.backend.aviso;

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

class AvisoLlegadaRepositoryTest {

    @Test
    void serializaAvisosPorSocioYUsaUnicidadFechaParaCarreras() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<AvisoLlegadaRepository.Socio>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<AvisoLlegadaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AvisoLlegadaRepository repository =
                new AvisoLlegadaRepository(jdbcTemplate);
        AvisoLlegadaRepository.Socio socio = new AvisoLlegadaRepository.Socio(
                91L, "67890127", "Lucía", "Fernández"
        );
        AvisoLlegadaRepository.Funcionario funcionario =
                new AvisoLlegadaRepository.Funcionario(
                        31L, "12345678", "Pablo", "Gómez"
                );

        repository.bloquearSocioHabilitado(socio.ci());
        repository.crearSiNoExiste(socio, funcionario, LocalDate.of(2026, 10, 21));

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate, org.mockito.Mockito.times(2)).query(
                sqlCaptor.capture(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<?>>any(),
                any(Object[].class)
        );
        String sql = String.join("\n", sqlCaptor.getAllValues());
        assertTrue(sql.contains("FOR UPDATE OF c"));
        assertTrue(sql.contains("ON CONFLICT (id_socio, fecha) DO NOTHING"));
        assertTrue(sql.contains("RETURNING id_aviso_llegada"));
    }

    @Test
    void consultaSoloAgendadasDelDiaPorCiYNoRecibeFechaDelCliente() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<uy.edu.proyecto.backend.agenda.ConsultaDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());
        AvisoLlegadaRepository repository =
                new AvisoLlegadaRepository(jdbcTemplate);

        repository.listarConsultasAgendadas(
                "67890127",
                LocalDate.of(2026, 10, 21)
        );

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                sqlCaptor.capture(),
                org.mockito.ArgumentMatchers
                        .<RowMapper<uy.edu.proyecto.backend.agenda.ConsultaDTO>>any(),
                any(Object[].class)
        );
        String sql = sqlCaptor.getValue();
        assertTrue(sql.contains("socio.ci = ?"));
        assertTrue(sql.contains("consulta.estado = 'AGENDADA'"));
        assertTrue(sql.contains("turno.fecha = ?"));
    }
}
