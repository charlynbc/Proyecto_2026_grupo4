package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/** Con la antelacion configurada en 48 horas la ventana del recordatorio cambia. */
@TestPropertySource(properties = "app.parametros.recordatorio-antelacion-horas=48")
class RecordatorioAntelacion48IT extends RecordatorioITBase {

    @Test
    void unaConsultaQueEmpiezaEn47HorasYSeAgendoHaceCincoDiasGeneraElRecordatorio() {
        reloj.fijar(diaDelTurno().minusDays(2).atTime(11, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(5).atTime(11, 0));

        proceso.generarRecordatorios();

        assertEquals(1, recordatorios());
    }

    @Test
    void unaConsultaQueEmpiezaEn49HorasTodaviaNoGeneraRecordatorio() {
        reloj.fijar(diaDelTurno().minusDays(2).atTime(9, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(5).atTime(9, 0));

        proceso.generarRecordatorios();

        assertEquals(0, recordatorios());
    }
}
