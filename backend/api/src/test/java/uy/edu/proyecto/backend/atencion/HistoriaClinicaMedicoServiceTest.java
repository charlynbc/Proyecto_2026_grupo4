package uy.edu.proyecto.backend.atencion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

class HistoriaClinicaMedicoServiceTest {

    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-30T12:00:00Z"), ZoneId.of("America/Montevideo"));

    private HistoriaClinicaMedicoRepository repository;
    private HistoriaClinicaRepository historiaClinica;
    private HistoriaClinicaMedicoService service;

    @BeforeEach
    void setUp() {
        repository = mock(HistoriaClinicaMedicoRepository.class);
        historiaClinica = mock(HistoriaClinicaRepository.class);
        service = new HistoriaClinicaMedicoService(repository, historiaClinica, RELOJ);
        when(repository.ciMedico(5L)).thenReturn(Optional.of("10000044"));
        when(repository.ciPaciente(7L)).thenReturn(Optional.of("20000012"));
    }

    @Test
    void conConsultaHabilitanteDevuelveLaHistoriaCompleta() {
        when(repository.tieneConsultaHabilitante(5L, 7L, LocalDate.of(2026, 10, 30)))
                .thenReturn(true);
        List<HistoriaClinicaDTO> esperada = List.of(new HistoriaClinicaDTO(
                1L, LocalDate.of(2026, 10, 1), 5L, "Mario", "Medina",
                new Especialidad(9L, "Medicina General", false),
                "Afeccion", null, null, List.of()));
        when(historiaClinica.listar(7L, null, null, null, null, null,
                "fecha_atencion", "desc")).thenReturn(esperada);

        List<HistoriaClinicaDTO> resultado = service.listar(5L, 7L);

        assertEquals(1, resultado.size());
        verify(historiaClinica).listar(7L, null, null, null, null, null,
                "fecha_atencion", "desc");
    }

    @Test
    void sinConsultaHabilitanteDevuelve404SinConsultarLaHistoria() {
        when(repository.tieneConsultaHabilitante(anyLong(), anyLong(), any()))
                .thenReturn(false);

        ApiException error = assertThrows(ApiException.class, () -> service.listar(5L, 7L));

        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
        verify(historiaClinica, never()).listar(anyLong(), isNull(), isNull(), isNull(),
                isNull(), isNull(), any(), any());
    }

    @Test
    void pacienteInexistenteDevuelve404() {
        when(repository.ciPaciente(7L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () -> service.listar(5L, 7L));

        assertEquals("NO_ENCONTRADO", error.getCode());
    }

    @Test
    void propiaHistoriaClinicaDevuelve403ConflictoDeInteres() {
        when(repository.ciPaciente(7L)).thenReturn(Optional.of("10000044"));

        ApiException error = assertThrows(ApiException.class, () -> service.listar(5L, 7L));

        assertEquals("CONFLICTO_DE_INTERES", error.getCode());
        assertEquals(403, error.getStatus().value());
    }

    @Test
    void identificadorDePacienteInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class, () -> service.listar(5L, 0L));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void medicoNoHabilitadoDevuelve403() {
        when(repository.ciMedico(5L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () -> service.listar(5L, 7L));

        assertEquals("ACCESO_DENEGADO", error.getCode());
    }
}
