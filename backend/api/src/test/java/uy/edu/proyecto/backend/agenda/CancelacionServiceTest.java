package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CancelacionServiceTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");
    // 2026-11-03 07:00 en Montevideo (UTC-3).
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-11-03T10:00:00Z"), MONTEVIDEO);
    private static final LocalDate HOY = LocalDate.of(2026, 11, 3);
    private static final OffsetDateTime CANCELADA =
            OffsetDateTime.parse("2026-11-03T07:00:00-03:00");

    @Mock
    private ConsultaRepository repository;

    private CancelacionService service;

    @BeforeEach
    void setUp() {
        service = new CancelacionService(repository, RELOJ);
    }

    private void socioHabilitado() {
        when(repository.bloquearSocioHabilitado(91L)).thenReturn(true);
    }

    private void consulta(String estado, LocalTime hora, LocalDate vencePase, boolean aviso) {
        socioHabilitado();
        when(repository.bloquearConsultaDelSocio(91L, 9001L)).thenReturn(Optional.of(
                new ConsultaParaCancelar(estado, HOY, hora, vencePase)));
        lenient().when(repository.existeAvisoLlegada(91L, HOY)).thenReturn(aviso);
    }

    @Test
    void cancelaConsultaValidaYDevuelvePaseVigente() {
        consulta("AGENDADA", LocalTime.of(10, 0), HOY.plusDays(30), false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));

        CancelacionDTO dto = service.cancelarPorSocio(91L, "9001");

        assertEquals(new CancelacionDTO(9001L, "CANCELADA_SOCIO", CANCELADA, true), dto);
    }

    @Test
    void consultaSinPaseNoInformaDevolucion() {
        consulta("AGENDADA", LocalTime.of(10, 0), null, false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));

        assertFalse(service.cancelarPorSocio(91L, "9001").paseDevuelto());
    }

    @Test
    void paseVencidoNoSeInformaComoDevuelto() {
        consulta("AGENDADA", LocalTime.of(10, 0), HOY.minusDays(1), false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));

        assertFalse(service.cancelarPorSocio(91L, "9001").paseDevuelto());
    }

    @Test
    void paseQueVenceHoyTodaviaSeDevuelve() {
        consulta("AGENDADA", LocalTime.of(10, 0), HOY, false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));

        assertTrue(service.cancelarPorSocio(91L, "9001").paseDevuelto());
    }

    @Test
    void limiteExactoDeDosHorasSePermite() {
        // Ahora 07:00; el número empieza 09:00.
        consulta("AGENDADA", LocalTime.of(9, 0), null, false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));

        assertEquals("CANCELADA_SOCIO", service.cancelarPorSocio(91L, "9001").estado());
    }

    @Test
    void unMinutoAntesDelLimiteSeRechaza() {
        consulta("AGENDADA", LocalTime.of(8, 59), null, false);

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        verify(repository, never()).cancelarPorSocio(9001L, 91L);
    }

    @Test
    void consultaYaIniciadaSeRechazaPorPlazo() {
        consulta("AGENDADA", LocalTime.of(6, 0), null, false);

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
    }

    @Test
    void avisoDeLlegadaImpideCancelar() {
        consulta("AGENDADA", LocalTime.of(15, 0), null, true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("LLEGADA_YA_REGISTRADA", error.getCode());
        verify(repository, never()).cancelarPorSocio(9001L, 91L);
    }

    @Test
    void estadosDistintosDeAgendadaSeRechazan() {
        for (String estado : new String[] {
                "ATENDIDA", "CANCELADA_SOCIO", "CANCELADA_INSTITUCION", "NO_SE_PRESENTO"}) {
            consulta(estado, LocalTime.of(15, 0), null, false);

            ApiException error = assertThrows(ApiException.class,
                    () -> service.cancelarPorSocio(91L, "9001"));

            assertEquals("CONSULTA_NO_AGENDADA", error.getCode());
        }
        verify(repository, never()).cancelarPorSocio(9001L, 91L);
    }

    @Test
    void consultaAjenaOInexistenteDevuelve404() {
        socioHabilitado();
        when(repository.bloquearConsultaDelSocio(91L, 9001L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
    }

    @Test
    void cuentaSocioNoHabilitadaDevuelve404() {
        when(repository.bloquearSocioHabilitado(91L)).thenReturn(false);

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("NO_ENCONTRADO", error.getCode());
        verify(repository, never()).bloquearConsultaDelSocio(91L, 9001L);
    }

    @Test
    void cancelacionConcurrenteYaAplicadaDevuelve409() {
        consulta("AGENDADA", LocalTime.of(15, 0), null, false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarPorSocio(91L, "9001"));

        assertEquals("CONSULTA_NO_AGENDADA", error.getCode());
    }

    @Test
    void identificadoresInvalidosSeRechazanSinConsultarLaBase() {
        for (String id : new String[] {"abc", "0", "-4", "", "9001; DROP TABLE consulta"}) {
            ApiException error = assertThrows(ApiException.class,
                    () -> service.cancelarPorSocio(91L, id));

            assertEquals("VALIDACION", error.getCode());
        }
        verifyNoInteractions(repository);
    }
}
