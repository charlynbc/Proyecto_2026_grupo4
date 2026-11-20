package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.agenda.ConsultaRepository;
import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaRecordatorio;
import uy.edu.proyecto.backend.parametro.ParametroService;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecordatorioConsultaServiceTest {

    /** 03/11/2026 10:00 en Montevideo (UTC-3). */
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-11-03T13:00:00Z"), ZoneId.of("America/Montevideo"));
    private static final OffsetDateTime AHORA = OffsetDateTime.parse("2026-11-03T10:00:00-03:00");

    private static final ConsultaParaRecordatorio CONSULTA = new ConsultaParaRecordatorio(
            9001L, 41L, "Cardiología", "Marta", "Rodríguez",
            LocalDate.of(2026, 11, 4), LocalTime.of(9, 0),
            "Consultorio 3", "Piso 2", OffsetDateTime.parse("2026-11-03T09:00:00-03:00"));

    @Mock
    private ConsultaRepository repository;
    @Mock
    private NotificacionEnvios envios;

    private RecordatorioConsultaService servicio(int antelacionHoras) {
        ParametroService parametros =
                new ParametroService(30, 2, 2, 1, 3, 10, 60, 5, 90, 1, 365, antelacionHoras, 8, 24, 24, 24);
        return new RecordatorioConsultaService(repository, envios, parametros, RELOJ);
    }

    @Test
    void buscaConElAhoraDelRelojYLaAntelacionPorDefectoDe24Horas() {
        when(repository.buscarConsultasParaRecordatorio(AHORA, 24)).thenReturn(List.of(CONSULTA));

        assertEquals(List.of(CONSULTA), servicio(24).consultasPorRecordar());
    }

    @Test
    void conAntelacionDe48HorasBuscaConEsaAntelacion() {
        when(repository.buscarConsultasParaRecordatorio(AHORA, 48)).thenReturn(List.of());

        assertEquals(List.of(), servicio(48).consultasPorRecordar());
        verify(repository).buscarConsultasParaRecordatorio(AHORA, 48);
    }

    @Test
    void conAntelacionDe1HoraBuscaConEsaAntelacion() {
        when(repository.buscarConsultasParaRecordatorio(AHORA, 1)).thenReturn(List.of());

        servicio(1).consultasPorRecordar();

        verify(repository).buscarConsultasParaRecordatorio(AHORA, 1);
    }

    @Test
    void guardaElRecordatorioConSuTextoYPedidosLosEnvios() {
        when(repository.crearNotificacionRecordatorio(
                9001L,
                "Recordatorio de consulta: Cardiología con Marta Rodríguez, "
                        + "el 04/11/2026 a las 09:00, en Consultorio 3 (Piso 2)",
                OffsetDateTime.parse("2026-11-03T09:00:00-03:00")))
                .thenReturn(Optional.of(7001L));

        assertTrue(servicio(24).generar(CONSULTA));

        verify(envios).solicitar(7001L, 41L);
    }

    @Test
    void siYaHabiaRecordatorioNoPideEnvios() {
        when(repository.crearNotificacionRecordatorio(
                9001L,
                "Recordatorio de consulta: Cardiología con Marta Rodríguez, "
                        + "el 04/11/2026 a las 09:00, en Consultorio 3 (Piso 2)",
                OffsetDateTime.parse("2026-11-03T09:00:00-03:00")))
                .thenReturn(Optional.empty());

        assertFalse(servicio(24).generar(CONSULTA));

        verify(envios, never()).solicitar(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyLong());
    }

    @Test
    void dosCorridasSeguidasGeneranUnSoloJuegoDeEnvios() {
        when(repository.crearNotificacionRecordatorio(
                org.mockito.ArgumentMatchers.eq(9001L),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.eq(OffsetDateTime.parse("2026-11-03T09:00:00-03:00"))))
                .thenReturn(Optional.of(7001L), Optional.empty());
        RecordatorioConsultaService servicio = servicio(24);

        assertTrue(servicio.generar(CONSULTA));
        assertFalse(servicio.generar(CONSULTA));

        verify(envios, times(1)).solicitar(7001L, 41L);
    }
}
