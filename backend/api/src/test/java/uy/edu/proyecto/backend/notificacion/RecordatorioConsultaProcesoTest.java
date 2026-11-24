package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaRecordatorio;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecordatorioConsultaProcesoTest {

    @Mock
    private RecordatorioConsultaService servicio;

    private static ConsultaParaRecordatorio consulta(long id) {
        return new ConsultaParaRecordatorio(
                id, 41L, "Cardiología", "Marta", "Rodríguez",
                LocalDate.of(2026, 11, 4), LocalTime.of(9, 0),
                "Consultorio 3", null, OffsetDateTime.parse("2026-11-03T09:00:00-03:00"));
    }

    @Test
    void generaElRecordatorioDeCadaConsultaEncontrada() {
        when(servicio.consultasPorRecordar()).thenReturn(List.of(consulta(1L), consulta(2L)));

        new RecordatorioConsultaProceso(servicio).generarRecordatorios();

        verify(servicio).generar(consulta(1L));
        verify(servicio).generar(consulta(2L));
    }

    @Test
    void siUnaConsultaFallaLasDemasSiguen() {
        when(servicio.consultasPorRecordar())
                .thenReturn(List.of(consulta(1L), consulta(2L), consulta(3L)));
        lenient().when(servicio.generar(consulta(2L)))
                .thenThrow(new IllegalStateException("base caida"));
        RecordatorioConsultaProceso proceso = new RecordatorioConsultaProceso(servicio);

        assertDoesNotThrow(proceso::generarRecordatorios);

        verify(servicio).generar(consulta(1L));
        verify(servicio).generar(consulta(3L));
    }

    @Test
    void siFallaLaBusquedaNoSaleComoExcepcionYNoGeneraNada() {
        when(servicio.consultasPorRecordar()).thenThrow(new IllegalStateException("base caida"));

        assertDoesNotThrow(() -> new RecordatorioConsultaProceso(servicio).generarRecordatorios());

        verify(servicio, never()).generar(consulta(1L));
    }
}
